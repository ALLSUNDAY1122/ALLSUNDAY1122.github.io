import CryptoKit
import Foundation
import HQGoldenSupport
import PDFKit
import ProductFlow
import RuntimeComposition

struct CLIOptions {
    let videoURL: URL
    let referencePDFURL: URL
    let workspaceURL: URL
    let bookID: String
    let expectedVideoSHA256: String?
    let expectedPDFSHA256: String?
    let matchThreshold: Float?
}

struct StageEvidence: Codable {
    let stage: String
    let outputRelativePath: String
    let pageCount: Int
    let reviewCount: Int
}

struct HQGoldenExecutionReport: Codable {
    let schemaVersion: Int
    let bookID: String
    let generatedAt: String
    let videoFileName: String
    let referencePDFFileName: String
    let observedVideoSHA256: String
    let observedPDFSHA256: String
    let expectedVideoSHA256: String?
    let expectedPDFSHA256: String?
    let videoSHAMatchesExpected: Bool?
    let pdfSHAMatchesExpected: Bool?
    let referencePDFPageCount: Int
    let outputPageCount: Int
    let reviewCount: Int
    let bookPackageRelativePath: String
    let requiredBookPackageFilesPresent: Bool
    let stageEvidence: [StageEvidence]
    let referenceMatches: [ReferenceNearestMatch]
    let referenceMetrics: ReferenceAlignmentMetrics?
    let formalGoldenVerdict: String
}

actor CheckpointBox {
    private var checkpoint: ProductPipelineCheckpoint?
    var value: ProductPipelineCheckpoint? { checkpoint }
    func set(_ newValue: ProductPipelineCheckpoint) { checkpoint = newValue }
}

@main
enum HQGoldenRunner {
    static func main() async throws {
        let options = try parseArguments(CommandLine.arguments)
        try validateInput(options.videoURL, label: "video")
        try validateInput(options.referencePDFURL, label: "reference PDF")

        let videoSHA = try sha256(options.videoURL)
        let pdfSHA = try sha256(options.referencePDFURL)
        let referencePageCount = try pdfPageCount(options.referencePDFURL)

        try resetDirectory(options.workspaceURL)
        let request = ProductPipelineRequest(
            bookID: options.bookID,
            inputs: [
                ProductInputAsset(
                    id: "hq-golden-video",
                    kind: .video,
                    localURL: options.videoURL,
                    displayName: options.videoURL.lastPathComponent
                )
            ],
            workspaceURL: options.workspaceURL
        )

        let driver = GoldenHardenedScannerRuntime.makeDriver()
        let checkpointBox = CheckpointBox()
        let completion = try await driver.run(
            request: request,
            resume: nil,
            progress: { progress in
                let line = "[HQGolden] \(progress.stage.rawValue) \(Int(progress.fraction * 100))%\n"
                FileHandle.standardError.write(Data(line.utf8))
            },
            checkpoint: { checkpoint in
                await checkpointBox.set(checkpoint)
            }
        )

        let latestCheckpoint = await checkpointBox.value
        let stageEvidence = (latestCheckpoint?.completedArtifacts ?? []).map {
            StageEvidence(
                stage: $0.stage.rawValue,
                outputRelativePath: relativePath($0.outputURL, under: options.workspaceURL),
                pageCount: $0.pageCount,
                reviewCount: $0.reviewItems.count
            )
        }

        let requiredFiles = ["pages", "text", "book_searchable.pdf", "book.md", "book.txt", "manifest.json"]
        let packageComplete = requiredFiles.allSatisfy {
            FileManager.default.fileExists(atPath: completion.bookPackageURL.appendingPathComponent($0).path)
        }
        let pagesURL = completion.bookPackageURL.appendingPathComponent("pages", isDirectory: true)
        let outputImageURLs = try FileManager.default.contentsOfDirectory(at: pagesURL, includingPropertiesForKeys: nil)
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let referenceMatches = try ReferenceFeatureMatcher.compare(
            referencePDFURL: options.referencePDFURL,
            outputImageURLs: outputImageURLs
        )
        let referenceMetrics = options.matchThreshold.map {
            ReferenceAlignment.evaluate(
                referencePageCount: referencePageCount,
                nearestMatches: referenceMatches,
                threshold: $0
            )
        }

        let verdict: String
        if let metrics = referenceMetrics {
            let referencePass = metrics.pageRecall >= 0.99
                && metrics.unmatchedOutputCount == 0
                && metrics.duplicateRate <= 0.005
                && metrics.orderingAccuracy >= 1.0
                && packageComplete
            verdict = referencePass
                ? "REFERENCE_METRICS_PASS_OTHER_GOLDEN_GATES_PENDING"
                : "REFERENCE_METRICS_FAIL"
        } else {
            verdict = "PENDING_REFERENCE_THRESHOLD_CALIBRATION"
        }

        let report = HQGoldenExecutionReport(
            schemaVersion: 2,
            bookID: options.bookID,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            videoFileName: options.videoURL.lastPathComponent,
            referencePDFFileName: options.referencePDFURL.lastPathComponent,
            observedVideoSHA256: videoSHA,
            observedPDFSHA256: pdfSHA,
            expectedVideoSHA256: options.expectedVideoSHA256,
            expectedPDFSHA256: options.expectedPDFSHA256,
            videoSHAMatchesExpected: match(expected: options.expectedVideoSHA256, observed: videoSHA),
            pdfSHAMatchesExpected: match(expected: options.expectedPDFSHA256, observed: pdfSHA),
            referencePDFPageCount: referencePageCount,
            outputPageCount: completion.pageCount,
            reviewCount: completion.reviewItems.count,
            bookPackageRelativePath: relativePath(completion.bookPackageURL, under: options.workspaceURL),
            requiredBookPackageFilesPresent: packageComplete,
            stageEvidence: stageEvidence,
            referenceMatches: referenceMatches,
            referenceMetrics: referenceMetrics,
            formalGoldenVerdict: verdict
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: options.workspaceURL.appendingPathComponent("hq-golden-execution.json"), options: .atomic)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    static func parseArguments(_ arguments: [String]) throws -> CLIOptions {
        var values: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else {
                throw NSError(domain: "HQGoldenRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: usage])
            }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard let video = values["--video"], let pdf = values["--pdf"] else {
            throw NSError(domain: "HQGoldenRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: usage])
        }
        let workspace = values["--workspace"] ?? FileManager.default.temporaryDirectory.appendingPathComponent("scanner-parity-hq-golden").path
        let threshold: Float?
        if let rawThreshold = values["--match-threshold"] {
            guard let parsed = Float(rawThreshold), parsed >= 0 else {
                throw NSError(domain: "HQGoldenRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid --match-threshold: \(rawThreshold)"])
            }
            threshold = parsed
        } else {
            threshold = nil
        }
        return CLIOptions(
            videoURL: URL(fileURLWithPath: video),
            referencePDFURL: URL(fileURLWithPath: pdf),
            workspaceURL: URL(fileURLWithPath: workspace, isDirectory: true),
            bookID: values["--book-id"] ?? "golden-v2-current-project-20260823",
            expectedVideoSHA256: values["--expected-video-sha"],
            expectedPDFSHA256: values["--expected-pdf-sha"],
            matchThreshold: threshold
        )
    }

    static var usage: String {
        "Usage: scanner-hq-golden-runner --video <mp4> --pdf <reference.pdf> [--workspace <dir>] [--book-id <id>] [--expected-video-sha <sha256>] [--expected-pdf-sha <sha256>] [--match-threshold <distance>]"
    }

    static func validateInput(_ url: URL, label: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw NSError(domain: "HQGoldenRunner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing \(label): \(url.lastPathComponent)"])
        }
    }

    static func pdfPageCount(_ url: URL) throws -> Int {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw NSError(domain: "HQGoldenRunner", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unreadable or empty reference PDF: \(url.lastPathComponent)"])
        }
        return document.pageCount
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

    static func match(expected: String?, observed: String) -> Bool? {
        expected.map { $0.caseInsensitiveCompare(observed) == .orderedSame }
    }

    static func relativePath(_ url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if path.hasPrefix(prefix) { return String(path.dropFirst(prefix.count)) }
        return url.lastPathComponent
    }

    static func resetDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
