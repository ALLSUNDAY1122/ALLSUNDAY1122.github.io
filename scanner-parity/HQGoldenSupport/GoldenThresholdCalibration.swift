import Foundation

public struct ReferenceDistanceDistribution: Codable, Sendable, Equatable {
    public let count: Int
    public let minimum: Float
    public let p05: Float
    public let p10: Float
    public let p25: Float
    public let median: Float
    public let p75: Float
    public let p90: Float
    public let p95: Float
    public let maximum: Float
}

public struct ReferenceDistanceGap: Codable, Sendable, Equatable {
    public let lowerDistance: Float
    public let upperDistance: Float
    public let gap: Float
    public let midpoint: Float
    public let acceptedOutputCountBelowGap: Int
}

public struct ReferenceThresholdSweepPoint: Codable, Sendable, Equatable {
    public let threshold: Float
    public let acceptedOutputCount: Int
    public let metrics: ReferenceAlignmentMetrics
}

public struct GoldenThresholdCalibrationEvidence: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let executionReportSHA256: String
    public let bookID: String
    public let observedVideoSHA256: String
    public let observedPDFSHA256: String
    public let referencePageCount: Int
    public let outputPageCount: Int
    public let nearestDistanceDistribution: ReferenceDistanceDistribution
    public let secondBestDistanceDistribution: ReferenceDistanceDistribution?
    public let nearestVsSecondBestMarginDistribution: ReferenceDistanceDistribution?
    public let largestNearestDistanceGaps: [ReferenceDistanceGap]
    public let thresholdSweep: [ReferenceThresholdSweepPoint]
    public let recommendedThreshold: Float?
    public let verdict: String
}

public struct GoldenThresholdDecision: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let executionReportSHA256: String
    public let calibrationEvidenceSHA256: String
    public let bookID: String
    public let observedVideoSHA256: String
    public let observedPDFSHA256: String
    public let threshold: Float?
    public let rationale: String
    public let reviewer: String
    public let decidedAt: String
}

public struct GoldenThresholdDecisionAssessment: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let executionReportSHA256: String
    public let calibrationEvidenceSHA256: String
    public let threshold: Float?
    public let selectedMetrics: ReferenceAlignmentMetrics?
    public let blockingReasons: [String]
    public let verdict: String
}

public enum GoldenThresholdCalibration {
    public static let evidenceVerdict = "CALIBRATION_EVIDENCE_READY_OPERATOR_DECISION_REQUIRED"
    public static let decisionValid = "THRESHOLD_DECISION_VALID_FOR_RERUN"
    public static let decisionInvalid = "THRESHOLD_DECISION_INVALID"

    public static func analyze(
        executionReportSHA256: String,
        bookID: String,
        observedVideoSHA256: String,
        observedPDFSHA256: String,
        referencePageCount: Int,
        nearestMatches: [ReferenceNearestMatch],
        maximumGapCount: Int = 20
    ) throws -> GoldenThresholdCalibrationEvidence {
        guard isSHA256(executionReportSHA256) else {
            throw calibrationError("execution report SHA-256 must be 64 hexadecimal characters")
        }
        guard !nearestMatches.isEmpty else {
            throw calibrationError("reference match set is empty")
        }
        guard nearestMatches.allSatisfy({ $0.distance.isFinite && $0.distance >= 0 }) else {
            throw calibrationError("nearest distances must be finite and non-negative")
        }

        let nearestValues = nearestMatches.map(\.distance)
        guard let nearestDistribution = distribution(nearestValues) else {
            throw calibrationError("nearest distance distribution is empty")
        }
        let secondBestValues = nearestMatches.compactMap(\.secondBestDistance).filter { $0.isFinite && $0 >= 0 }
        let marginValues = nearestMatches.compactMap { match -> Float? in
            guard let second = match.secondBestDistance, second.isFinite else { return nil }
            return max(0, second - match.distance)
        }

        let uniqueDistances = Array(Set(nearestValues)).sorted()
        let gaps = zip(uniqueDistances, uniqueDistances.dropFirst()).map { lower, upper in
            let gap = upper - lower
            let metricsAtLower = ReferenceAlignment.evaluate(
                referencePageCount: referencePageCount,
                nearestMatches: nearestMatches,
                threshold: lower
            )
            return ReferenceDistanceGap(
                lowerDistance: lower,
                upperDistance: upper,
                gap: gap,
                midpoint: lower + gap / 2,
                acceptedOutputCountBelowGap: max(0, metricsAtLower.outputPageCount - metricsAtLower.unmatchedOutputCount)
            )
        }
        .sorted {
            if $0.gap == $1.gap { return $0.lowerDistance < $1.lowerDistance }
            return $0.gap > $1.gap
        }
        .prefix(max(0, maximumGapCount))

        var sweepThresholds = [Float(0)]
        sweepThresholds.append(contentsOf: uniqueDistances)
        sweepThresholds = Array(Set(sweepThresholds)).sorted()
        let sweep = sweepThresholds.map { threshold in
            let metrics = ReferenceAlignment.evaluate(
                referencePageCount: referencePageCount,
                nearestMatches: nearestMatches,
                threshold: threshold
            )
            return ReferenceThresholdSweepPoint(
                threshold: threshold,
                acceptedOutputCount: max(0, metrics.outputPageCount - metrics.unmatchedOutputCount),
                metrics: metrics
            )
        }

        return GoldenThresholdCalibrationEvidence(
            schemaVersion: 1,
            executionReportSHA256: executionReportSHA256.lowercased(),
            bookID: bookID,
            observedVideoSHA256: observedVideoSHA256.lowercased(),
            observedPDFSHA256: observedPDFSHA256.lowercased(),
            referencePageCount: max(0, referencePageCount),
            outputPageCount: nearestMatches.count,
            nearestDistanceDistribution: nearestDistribution,
            secondBestDistanceDistribution: distribution(secondBestValues),
            nearestVsSecondBestMarginDistribution: distribution(marginValues),
            largestNearestDistanceGaps: Array(gaps),
            thresholdSweep: sweep,
            recommendedThreshold: nil,
            verdict: evidenceVerdict
        )
    }

    public static func makeDecisionTemplate(
        evidence: GoldenThresholdCalibrationEvidence,
        calibrationEvidenceSHA256: String
    ) throws -> GoldenThresholdDecision {
        guard isSHA256(calibrationEvidenceSHA256) else {
            throw calibrationError("calibration evidence SHA-256 must be 64 hexadecimal characters")
        }
        return GoldenThresholdDecision(
            schemaVersion: 1,
            executionReportSHA256: evidence.executionReportSHA256,
            calibrationEvidenceSHA256: calibrationEvidenceSHA256.lowercased(),
            bookID: evidence.bookID,
            observedVideoSHA256: evidence.observedVideoSHA256,
            observedPDFSHA256: evidence.observedPDFSHA256,
            threshold: nil,
            rationale: "",
            reviewer: "",
            decidedAt: ""
        )
    }

    public static func validateDecision(
        evidence: GoldenThresholdCalibrationEvidence,
        calibrationEvidenceSHA256: String,
        decision: GoldenThresholdDecision,
        nearestMatches: [ReferenceNearestMatch]
    ) -> GoldenThresholdDecisionAssessment {
        var blockers: [String] = []
        let normalizedEvidenceSHA = calibrationEvidenceSHA256.lowercased()
        if decision.schemaVersion != 1 { blockers.append("decision schemaVersion must equal 1") }
        if evidence.schemaVersion != 1 { blockers.append("calibration evidence schemaVersion must equal 1") }
        if evidence.verdict != evidenceVerdict { blockers.append("calibration evidence verdict is not operator-decision pending") }
        if evidence.recommendedThreshold != nil { blockers.append("calibration evidence must not contain an automatic threshold recommendation") }
        if !isSHA256(normalizedEvidenceSHA) { blockers.append("calibration evidence SHA-256 is invalid") }
        if decision.executionReportSHA256.caseInsensitiveCompare(evidence.executionReportSHA256) != .orderedSame {
            blockers.append("decision execution-report SHA does not match calibration evidence")
        }
        if decision.calibrationEvidenceSHA256.caseInsensitiveCompare(normalizedEvidenceSHA) != .orderedSame {
            blockers.append("decision calibration-evidence SHA does not match the supplied evidence file")
        }
        if decision.bookID != evidence.bookID { blockers.append("decision bookID does not match calibration evidence") }
        if decision.observedVideoSHA256.caseInsensitiveCompare(evidence.observedVideoSHA256) != .orderedSame {
            blockers.append("decision video SHA does not match calibration evidence")
        }
        if decision.observedPDFSHA256.caseInsensitiveCompare(evidence.observedPDFSHA256) != .orderedSame {
            blockers.append("decision PDF SHA does not match calibration evidence")
        }
        if decision.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append("decision rationale is required")
        }
        if decision.reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append("decision reviewer is required")
        }
        if ISO8601DateFormatter().date(from: decision.decidedAt) == nil {
            blockers.append("decision decidedAt must be valid ISO-8601")
        }
        if nearestMatches.count != evidence.outputPageCount {
            blockers.append("reference match count no longer matches calibration evidence")
        }

        var selectedMetrics: ReferenceAlignmentMetrics?
        if let threshold = decision.threshold {
            if !threshold.isFinite || threshold < 0 {
                blockers.append("threshold must be finite and non-negative")
            } else {
                selectedMetrics = ReferenceAlignment.evaluate(
                    referencePageCount: evidence.referencePageCount,
                    nearestMatches: nearestMatches,
                    threshold: threshold
                )
            }
        } else {
            blockers.append("threshold is required")
        }

        return GoldenThresholdDecisionAssessment(
            schemaVersion: 1,
            executionReportSHA256: evidence.executionReportSHA256,
            calibrationEvidenceSHA256: normalizedEvidenceSHA,
            threshold: decision.threshold,
            selectedMetrics: selectedMetrics,
            blockingReasons: blockers,
            verdict: blockers.isEmpty ? decisionValid : decisionInvalid
        )
    }

    private static func distribution(_ values: [Float]) -> ReferenceDistanceDistribution? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        func percentile(_ p: Double) -> Float {
            guard sorted.count > 1 else { return sorted[0] }
            let position = p * Double(sorted.count - 1)
            let lower = Int(floor(position))
            let upper = Int(ceil(position))
            if lower == upper { return sorted[lower] }
            let weight = Float(position - Double(lower))
            return sorted[lower] + (sorted[upper] - sorted[lower]) * weight
        }
        return .init(
            count: sorted.count,
            minimum: sorted.first!,
            p05: percentile(0.05),
            p10: percentile(0.10),
            p25: percentile(0.25),
            median: percentile(0.50),
            p75: percentile(0.75),
            p90: percentile(0.90),
            p95: percentile(0.95),
            maximum: sorted.last!
        )
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit }
    }

    private static func calibrationError(_ message: String) -> NSError {
        NSError(domain: "GoldenThresholdCalibration", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
