import CryptoKit
import Foundation
import HQGoldenSupport
import PDFKit
import ProductFlow
import RuntimeComposition
import ScannerRuntime

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

struct CorrectionPageEvidence: Decodable {
    let pageID: String
    let stageFailure: String?
}

struct OCRSnapshotEvidence: Decodable {
    let pages: [OCRPage]
    let failures: [String: String]
}

struct CorrectionSummary: Codable {
    let pageCount: Int
    let failureCount: Int
    let failedPageIDs: [String]
}

struct PageAuditSummary: Codable {
    let orderedPageCount: Int
    let duplicateGroupCount: Int
    let missingPageSuspicionCount: Int
    let reversalEventCount: Int
    let autoFixCount: Int
    let reviewCount: Int
}

struct OCRSummary: Codable {
    let pageCount: Int
    let failureCount: Int
    let failedPageIDs: [String]
    let needsReviewCount: Int
    let emptyTextPageCount: Int
    let meanConfidence: Double
    let minimumConfidence: Double?
    let layoutCounts: [String: Int]
}

struct SearchablePDFTextSummary: Codable {
    let pageCount: Int
    let pagesWithExtractableText: Int
    let pagesWithoutExtractableText: Int
    let extractableCharacterCount: Int
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
    let correctionSummary: CorrectionSummary
    let pageAuditSummary: PageAuditSummary
    let ocrSummary: OCRSummary
    let searchablePDFTextSummary: SearchablePDFTextSummary
    let packageIntegrity: PackageIntegrityReport
    let referenceMatches: [ReferenceNearestMatch]
    let referenceMetrics: ReferenceAlignmentMetrics?
    let machineGateAssessment: FormalGoldenMachineAssessment
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

        let requiredFiles = ["pages", "text", "book_searchable.pdf", "book.md", "book.txt", "manifest.json", "integrity-report.json"]
        let packageComplete = requiredFiles.allSatisfy {
            FileManager.default.fileExists(atPath: completion.bookPackageURL.appendingPathComponent($0).path)
        }

        let corrected: [CorrectionPageEvidence] = try readJSON(
            options.workspaceURL.appendingPathComponent("02-image-correction/corrected-pages.json")
        )
        let correctionFailures = corrected.filter { $0.stageFailure != nil }
        let correctionSummary = CorrectionSummary(
            pageCount: corrected.count,
            failureCount: correctionFailures.count,
            failedPageIDs: correctionFailures.map(\.pageID).sorted()
        )

        let audit: PageAuditResult = try readJSON(
            options.workspaceURL.appendingPathComponent("03-page-audit/page-audit-result.json")
        )
        let pageAuditSummary = PageAuditSummary(
            orderedPageCount: audit.orderedPageIDs.count,
            duplicateGroupCount: audit.duplicateGroups.count,
            missingPageSuspicionCount: audit.missingPageSuspicions.count,
            reversalEventCount: audit.reversalEvents.count,
            autoFixCount: audit.autoFixes.count,
            reviewCount: audit.reviewRequired.count
        )

        let ocr: OCRSnapshotEvidence = try readJSON(
            options.workspaceURL.appendingPathComponent("04-ocr/ocr.json")
        )
        let nonWhitespaceTexts = ocr.pages.map {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let confidenceTotal = ocr.pages.reduce(0.0) { $0 + $1.ocrConfidence }
        var layoutCounts: [String: Int] = [:]
        ocr.pages.forEach { layoutCounts[$0.layout.rawValue, default: 0] += 1 }
        let ocrSummary = OCRSummary(
            pageCount: ocr.pages.count,
            failureCount: ocr.failures.count,
            failedPageIDs: ocr.failures.keys.sorted(),
            needsReviewCount: ocr.pages.filter(\.needsReview).count,
            emptyTextPageCount: nonWhitespaceTexts.filter(\.isEmpty).count,
            meanConfidence: ocr.pages.isEmpty ? 0 : confidenceTotal / Double(ocr.pages.count),
            minimumConfidence: ocr.pages.map(\.ocrConfidence).min(),
            layoutCounts: layoutCounts
        )

        let integrity: PackageIntegrityReport = try readJSON(
            completion.bookPackageURL.appendingPathComponent("integrity-report.json")
        )
        let searchablePDFText = try searchablePDFTextSummary(
            completion.bookPackageURL.appendingPathComponent("book_searchable.pdf")
        )

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

        let videoSHAMatch = match(expected: options.expectedVideoSHA256, observed: videoSHA)
        let pdfSHAMatch = match(expected: options.expectedPDFSHA256, observed: pdfSHA)
        let machineAssessment = FormalGoldenMachineGate.evaluate(.init(
            videoSHAMatchesExpected: videoSHAMatch,
            pdfSHAMatchesExpected: pdfSHAMatch,
            referenceMetrics: referenceMetrics,
            correctionFailureCount: correctionSummary.failureCount,
            ocrFailureCount: ocrSummary.failureCount,
            packageIntegrityValid: integrity.valid && packageComplete,
            auditMissingSuspicionCount: pageAuditSummary.missingPageSuspicionCount,
            auditReversalCount: pageAuditSummary.reversalEventCount,
            auditDuplicateGroupCount: pageAuditSummary.duplicateGroupCount,
            auditReviewCount: pageAuditSummary.reviewCount,
            ocrNeedsReviewCount: ocrSummary.needsReviewCount,
            ocrEmptyTextPageCount: ocrSummary.emptyTextPageCount,
            searchablePDFTextlessPageCount: searchablePDFText.pagesWithoutExtractableText
        ))

        let formalVerdict: String
        switch machineAssessment.verdict {
        case FormalGoldenMachineGate.pendingIdentity:
            formalVerdict = "PENDING_GOLDEN_IDENTITY_EXPECTATIONS"
        case FormalGoldenMachineGate.pendingReferenceThreshold:
            formalVerdict = "PENDING_REFERENCE_THRESHOLD_CALIBRATION"
        case FormalGoldenMachineGate.machineFail:
            formalVerdict = "FORMAL_GOLDEN_FAIL_MACHINE_GATE"
        default:
            formalVerdict = "PENDING_HUMAN_VISUAL_OCR_REVIEW"
        }

        let report = HQGoldenExecutionReport(
            schemaVersion: 3,
            bookID: options.bookID,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            videoFileName: options.videoURL.lastPathComponent,
            referencePDFFileName: options.referencePDFURL.lastPathComponent,
            observedVideoSHA256: videoSHA,
            observedPDFSHA256: pdfSHA,
            expectedVideoSHA256: options.expectedVideoSHA256,
            expectedPDFSHA256: options.expectedPDFSHA256,
            videoSHAMatchesExpected: videoSHAMatch,
            pdfSHAMatchesExpected: pdfSHAMatch,
            referencePDFPageCount: referencePageCount,
            outputPageCount: completion.pageCount,
            reviewCount: completion.reviewItems.count,
            bookPackageRelativePath: relativePath(completion.bookPackageURL, under: options.workspaceURL),
            requiredBookPackageFilesPresent: packageComplete,
            stageEvidence: stageEvidence,
            correctionSummary: correctionSummary,
            pageAuditSummary: pageAuditSummary,
            ocrSummary: ocrSummary,
            searchablePDFTextSummary: searchablePDFText,
            packageIntegrity: integrity,
            referenceMatches: referenceMatches,
            referenceMetrics: referenceMetrics,
            machineGateAssessment: machineAssessment,
            formalGoldenVerdict: formalVerdict
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

    static func searchablePDFTextSummary(_ url: URL) throws -> SearchablePDFTextSummary {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw NSError(domain: "HQGoldenRunner", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unreadable or empty searchable PDF: \(url.lastPathComponent)"])
        }
        var withText = 0
        var characters = 0
        for index in 0..<document.pageCount {
            let text = document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { withText += 1 }
            characters += text.count
        }
        return .init(
            pageCount: document.pageCount,
            pagesWithExtractableText: withText,
            pagesWithoutExtractableText: document.pageCount - withText,
            extractableCharacterCount: characters
        )
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

    static func readJSON<T: Decodable>(_ url: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
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
