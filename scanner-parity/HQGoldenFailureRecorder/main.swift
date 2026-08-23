import CryptoKit
import Foundation
import HQGoldenSupport

struct FailureRecorderOptions {
    let videoURL: URL
    let referencePDFURL: URL
    let workspaceURL: URL
    let bookID: String
    let expectedVideoSHA256: String?
    let expectedPDFSHA256: String?
    let stderrLogURL: URL
    let runnerExitCode: Int
}

struct GoldenPipelineFailureEvidence: Codable {
    let errorType: String
    let message: String
}

struct GoldenPipelineFailureReport: Codable {
    let schemaVersion: Int
    let reportKind: String
    let generatedAt: String
    let bookID: String
    let videoFileName: String
    let referencePDFFileName: String
    let observedVideoSHA256: String?
    let observedPDFSHA256: String?
    let expectedVideoSHA256: String?
    let expectedPDFSHA256: String?
    let videoSHAMatchesExpected: Bool?
    let pdfSHAMatchesExpected: Bool?
    let runnerExitCode: Int
    let completedStageMarkers: [String]
    let integrityReportRelativePaths: [String]
    let executionFailure: GoldenPipelineFailureEvidence
    let formalGoldenVerdict: String
}

@main
enum HQGoldenFailureRecorder {
    static func main() throws {
        let options = try parseArguments(CommandLine.arguments)
        try FileManager.default.createDirectory(at: options.workspaceURL, withIntermediateDirectories: true)

        let observedVideoSHA = try? sha256(options.videoURL)
        let observedPDFSHA = try? sha256(options.referencePDFURL)
        let rawError = (try? String(contentsOf: options.stderrLogURL, encoding: .utf8)) ?? "scanner-hq-golden-runner exited with code \(options.runnerExitCode)"
        let sanitized = GoldenExecutionFailureSanitizer.sanitize(
            message: rawError,
            redactedPaths: [
                options.videoURL.path,
                options.referencePDFURL.path,
                options.workspaceURL.path,
                options.stderrLogURL.path
            ]
        )

        let report = GoldenPipelineFailureReport(
            schemaVersion: 1,
            reportKind: "pipeline_failure",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            bookID: options.bookID,
            videoFileName: options.videoURL.lastPathComponent,
            referencePDFFileName: options.referencePDFURL.lastPathComponent,
            observedVideoSHA256: observedVideoSHA,
            observedPDFSHA256: observedPDFSHA,
            expectedVideoSHA256: options.expectedVideoSHA256,
            expectedPDFSHA256: options.expectedPDFSHA256,
            videoSHAMatchesExpected: match(expected: options.expectedVideoSHA256, observed: observedVideoSHA),
            pdfSHAMatchesExpected: match(expected: options.expectedPDFSHA256, observed: observedPDFSHA),
            runnerExitCode: options.runnerExitCode,
            completedStageMarkers: completedStageMarkers(in: options.workspaceURL),
            integrityReportRelativePaths: findRelativeFiles(named: "integrity-report.json", under: options.workspaceURL),
            executionFailure: .init(errorType: "runner_nonzero_exit", message: sanitized),
            formalGoldenVerdict: "FORMAL_GOLDEN_FAIL_PIPELINE_EXECUTION"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let reportURL = options.workspaceURL.appendingPathComponent("hq-golden-execution-failure.json")
        try data.write(to: reportURL, options: .atomic)
        FileHandle.standardError.write(Data("[HQGolden] failure report written: hq-golden-execution-failure.json\n".utf8))
    }

    static func parseArguments(_ arguments: [String]) throws -> FailureRecorderOptions {
        var values: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else { throw usageError() }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard
            let video = values["--video"],
            let pdf = values["--pdf"],
            let workspace = values["--workspace"],
            let stderrLog = values["--stderr-log"],
            let exitRaw = values["--runner-exit-code"],
            let exitCode = Int(exitRaw)
        else { throw usageError() }

        return .init(
            videoURL: URL(fileURLWithPath: video),
            referencePDFURL: URL(fileURLWithPath: pdf),
            workspaceURL: URL(fileURLWithPath: workspace, isDirectory: true),
            bookID: values["--book-id"] ?? "golden-v2-current-project-20260823",
            expectedVideoSHA256: values["--expected-video-sha"],
            expectedPDFSHA256: values["--expected-pdf-sha"],
            stderrLogURL: URL(fileURLWithPath: stderrLog),
            runnerExitCode: exitCode
        )
    }

    static func usageError() -> NSError {
        NSError(
            domain: "HQGoldenFailureRecorder",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Usage: scanner-hq-golden-failure-recorder --video <mp4> --pdf <reference.pdf> --workspace <dir> --stderr-log <file> --runner-exit-code <code> [--book-id <id>] [--expected-video-sha <sha256>] [--expected-pdf-sha <sha256>]"]
        )
    }

    static func completedStageMarkers(in workspace: URL) -> [String] {
        let markers = [
            "01-frame-extraction/candidates.json",
            "02-image-correction/corrected-pages.json",
            "03-page-audit/page-audit-result.json",
            "04-ocr/ocr.json"
        ]
        return markers.filter { FileManager.default.fileExists(atPath: workspace.appendingPathComponent($0).path) }
    }

    static func findRelativeFiles(named name: String, under root: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var results: [String] = []
        for case let url as URL in enumerator where url.lastPathComponent == name {
            results.append(relativePath(url, under: root))
        }
        return results.sorted()
    }

    static func relativePath(_ url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if path.hasPrefix(prefix) { return String(path.dropFirst(prefix.count)) }
        return url.lastPathComponent
    }

    static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 4 * 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func match(expected: String?, observed: String?) -> Bool? {
        guard let expected, let observed else { return nil }
        return expected.caseInsensitiveCompare(observed) == .orderedSame
    }
}
