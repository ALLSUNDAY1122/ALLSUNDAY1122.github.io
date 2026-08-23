import CryptoKit
import Foundation
import HQGoldenSupport

private struct CalibrationExecutionSnapshot: Decodable {
    let schemaVersion: Int
    let bookID: String
    let observedVideoSHA256: String
    let observedPDFSHA256: String
    let referencePDFPageCount: Int
    let outputPageCount: Int
    let referenceMatches: [ReferenceNearestMatch]
    let referenceMetrics: ReferenceAlignmentMetrics?
    let formalGoldenVerdict: String
}

private struct Options {
    let executionReportURL: URL
    let analyzeOutputURL: URL?
    let calibrationEvidenceURL: URL?
    let decisionTemplateOutputURL: URL?
    let decisionURL: URL?
    let validationOutputURL: URL?
    let emitThreshold: Bool
}

@main
enum HQGoldenCalibrator {
    static func main() throws {
        let options = try parse(CommandLine.arguments)
        let executionData = try Data(contentsOf: options.executionReportURL)
        let executionSHA = sha256(executionData)
        let execution = try JSONDecoder().decode(CalibrationExecutionSnapshot.self, from: executionData)
        try validateThresholdlessExecution(execution, executionSHA: executionSHA)

        if let outputURL = options.analyzeOutputURL {
            let evidence = try GoldenThresholdCalibration.analyze(
                executionReportSHA256: executionSHA,
                bookID: execution.bookID,
                observedVideoSHA256: execution.observedVideoSHA256,
                observedPDFSHA256: execution.observedPDFSHA256,
                referencePageCount: execution.referencePDFPageCount,
                nearestMatches: execution.referenceMatches
            )
            try writeJSON(evidence, to: outputURL)
            FileHandle.standardOutput.write(Data("CALIBRATION_EVIDENCE_READY_OPERATOR_DECISION_REQUIRED\n".utf8))
            return
        }

        guard let evidenceURL = options.calibrationEvidenceURL else {
            throw cliError("--calibration-evidence is required for decision operations")
        }
        let evidenceData = try Data(contentsOf: evidenceURL)
        let evidenceSHA = sha256(evidenceData)
        let evidence = try JSONDecoder().decode(GoldenThresholdCalibrationEvidence.self, from: evidenceData)
        try validateEvidenceBinding(evidence, execution: execution, executionSHA: executionSHA)

        if let outputURL = options.decisionTemplateOutputURL {
            let template = try GoldenThresholdCalibration.makeDecisionTemplate(
                evidence: evidence,
                calibrationEvidenceSHA256: evidenceSHA
            )
            try writeJSON(template, to: outputURL)
            FileHandle.standardOutput.write(Data("THRESHOLD_DECISION_TEMPLATE_READY\n".utf8))
            return
        }

        guard let decisionURL = options.decisionURL else {
            throw cliError("--decision is required for validation or --emit-threshold")
        }
        let decision = try JSONDecoder().decode(GoldenThresholdDecision.self, from: Data(contentsOf: decisionURL))
        let assessment = GoldenThresholdCalibration.validateDecision(
            evidence: evidence,
            calibrationEvidenceSHA256: evidenceSHA,
            decision: decision,
            nearestMatches: execution.referenceMatches
        )

        if let outputURL = options.validationOutputURL {
            try writeJSON(assessment, to: outputURL)
        }
        guard assessment.verdict == GoldenThresholdCalibration.decisionValid,
              let threshold = assessment.threshold else {
            if options.validationOutputURL == nil {
                let data = try encoded(assessment)
                FileHandle.standardError.write(data)
                FileHandle.standardError.write(Data("\n".utf8))
            }
            throw cliError("threshold decision is invalid")
        }

        if options.emitThreshold {
            FileHandle.standardOutput.write(Data("\(threshold)\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data("THRESHOLD_DECISION_VALID_FOR_RERUN\n".utf8))
        }
    }

    private static func validateThresholdlessExecution(_ execution: CalibrationExecutionSnapshot, executionSHA: String) throws {
        guard execution.schemaVersion >= 4 else {
            throw cliError("execution report schemaVersion must be >= 4")
        }
        guard execution.formalGoldenVerdict == "PENDING_REFERENCE_THRESHOLD_CALIBRATION" else {
            throw cliError("execution report must be the thresholdless PENDING_REFERENCE_THRESHOLD_CALIBRATION run")
        }
        guard execution.referenceMetrics == nil else {
            throw cliError("thresholdless execution must not already contain referenceMetrics")
        }
        guard execution.outputPageCount == execution.referenceMatches.count else {
            throw cliError("execution outputPageCount does not match referenceMatches count")
        }
        guard !execution.referenceMatches.isEmpty else {
            throw cliError("execution report contains no reference matches")
        }
        guard executionSHA.count == 64 else {
            throw cliError("execution report SHA-256 is invalid")
        }
    }

    private static func validateEvidenceBinding(
        _ evidence: GoldenThresholdCalibrationEvidence,
        execution: CalibrationExecutionSnapshot,
        executionSHA: String
    ) throws {
        var blockers: [String] = []
        if evidence.schemaVersion != 1 { blockers.append("evidence schemaVersion must equal 1") }
        if evidence.verdict != GoldenThresholdCalibration.evidenceVerdict { blockers.append("unexpected evidence verdict") }
        if evidence.recommendedThreshold != nil { blockers.append("evidence must not contain an automatic threshold recommendation") }
        if evidence.executionReportSHA256.caseInsensitiveCompare(executionSHA) != .orderedSame { blockers.append("execution-report SHA mismatch") }
        if evidence.bookID != execution.bookID { blockers.append("bookID mismatch") }
        if evidence.observedVideoSHA256.caseInsensitiveCompare(execution.observedVideoSHA256) != .orderedSame { blockers.append("video SHA mismatch") }
        if evidence.observedPDFSHA256.caseInsensitiveCompare(execution.observedPDFSHA256) != .orderedSame { blockers.append("PDF SHA mismatch") }
        if evidence.referencePageCount != execution.referencePDFPageCount { blockers.append("reference page-count mismatch") }
        if evidence.outputPageCount != execution.outputPageCount { blockers.append("output page-count mismatch") }
        if blockers.isEmpty { return }
        throw cliError("calibration evidence binding failed: \(blockers.joined(separator: "; "))")
    }

    private static func parse(_ arguments: [String]) throws -> Options {
        var values: [String: String] = [:]
        var flags = Set<String>()
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--") else { throw cliError(usage) }
            if key == "--emit-threshold" {
                flags.insert(key)
                index += 1
                continue
            }
            guard index + 1 < arguments.count else { throw cliError("missing value for \(key)") }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard let executionPath = values["--execution-report"] else { throw cliError(usage) }

        let analyze = values["--analyze"]
        let template = values["--create-decision-template"]
        let validate = values["--validate-decision"]
        let emit = flags.contains("--emit-threshold")
        let modeCount = [analyze != nil, template != nil, validate != nil, emit].filter { $0 }.count
        guard modeCount == 1 else { throw cliError("select exactly one mode: --analyze, --create-decision-template, --validate-decision, or --emit-threshold") }

        return Options(
            executionReportURL: URL(fileURLWithPath: executionPath),
            analyzeOutputURL: analyze.map { URL(fileURLWithPath: $0) },
            calibrationEvidenceURL: values["--calibration-evidence"].map { URL(fileURLWithPath: $0) },
            decisionTemplateOutputURL: template.map { URL(fileURLWithPath: $0) },
            decisionURL: values["--decision"].map { URL(fileURLWithPath: $0) },
            validationOutputURL: validate.map { URL(fileURLWithPath: $0) },
            emitThreshold: emit
        )
    }

    private static var usage: String {
        "Usage: scanner-hq-golden-calibrator --execution-report <thresholdless hq-golden-execution.json> [--analyze <evidence.json> | --calibration-evidence <evidence.json> --create-decision-template <decision.json> | --calibration-evidence <evidence.json> --decision <decision.json> --validate-decision <assessment.json> | --calibration-evidence <evidence.json> --decision <decision.json> --emit-threshold]"
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoded(value).write(to: url, options: .atomic)
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func cliError(_ message: String) -> NSError {
        NSError(domain: "HQGoldenCalibrator", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
