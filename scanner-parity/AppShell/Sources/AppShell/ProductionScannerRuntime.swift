import Foundation
import ProductFlow
import ScannerRuntime

#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers) && canImport(Vision)
import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

public enum ProductionScannerRuntimeError: LocalizedError {
    case missingArtifact(ProductProcessingStage)
    case unreadableImage(URL)
    case imageWriteFailed(URL)
    case missingOCRImage(String)
    case packageIntegrityFailed(Int)

    public var errorDescription: String? {
        switch self {
        case .missingArtifact(let stage): return "Required stage artifact is missing: \(stage.rawValue)"
        case .unreadableImage(let url): return "Cannot read page image: \(url.lastPathComponent)"
        case .imageWriteFailed(let url): return "Cannot write corrected page image: \(url.lastPathComponent)"
        case .missingOCRImage(let pageID): return "OCR image reference is missing for page \(pageID)"
        case .packageIntegrityFailed(let count): return "BookPackage integrity validation failed with \(count) error(s)."
        }
    }
}

private struct RuntimeCorrectedPage: Codable, Sendable {
    let pageID: String
    let candidate: PageCandidate
    let metadata: CorrectedPageMetadata?
    let readingImagePath: String
    let ocrImagePath: String
    let stageFailure: String?
}

private struct RuntimeAuditedBook: Codable, Sendable {
    let auditResult: PageAuditResult
    let lineage: [PipelinePageLineage]
    let ocrImageByPageID: [String: String]
}

private struct RuntimeOCRSnapshot: Codable, Sendable {
    let pages: [OCRPage]
    let failures: [String: String]
}

/// Final HQ composition of the already validated scanner engines. The UI uses
/// this factory by default, so a production build no longer starts with an
/// empty binding list.
public enum ProductionScannerRuntime {
    public static func makeDriver() -> any ProductPipelineDriving {
        BoundProductPipelineDriver(bindings: makeBindings())
    }

    public static func makeBindings() -> [ProductPipelineStageBinding] {
        [
            frameExtractionBinding(),
            imageCorrectionBinding(),
            pageAuditBinding(),
            ocrBinding(),
            packageBinding()
        ]
    }

    private static func frameExtractionBinding() -> ProductPipelineStageBinding {
        ProductPipelineStageBinding(stage: .frameExtraction) { request, _, progress in
            try Task.checkCancellation()
            let stageURL = request.workspaceURL.appendingPathComponent("01-frame-extraction", isDirectory: true)
            try resetDirectory(stageURL)

            var output: [PageCandidate] = []
            var timelineBase: Int64 = 0
            let totalAssets = max(1, request.inputs.count)
            let extractor = AVFoundationStableFrameExtractor()

            for (assetIndex, asset) in request.inputs.enumerated() {
                try Task.checkCancellation()
                switch asset.kind {
                case .video:
                    let assetDirectory = stageURL.appendingPathComponent(String(format: "video-%03d", assetIndex + 1), isDirectory: true)
                    let extracted = try await extractor.extract(videoURL: asset.localURL, outputDirectory: assetDirectory, bookID: request.bookID)
                    for candidate in extracted {
                        let globalIndex = output.count + 1
                        output.append(PageCandidate(
                            candidateID: String(format: "%@-candidate-%04d", request.bookID, globalIndex),
                            bookID: request.bookID,
                            sourceTimeMS: timelineBase + candidate.sourceTimeMS,
                            sourceRangeMS: .init(start: timelineBase + candidate.sourceRangeMS.start, end: timelineBase + candidate.sourceRangeMS.end),
                            imageRef: candidate.imageRef,
                            stabilityScore: candidate.stabilityScore,
                            sharpnessScore: candidate.sharpnessScore,
                            motionScore: candidate.motionScore,
                            duplicateGroupID: candidate.duplicateGroupID,
                            flags: candidate.flags
                        ))
                    }
                    let maxEnd = extracted.map(\.sourceRangeMS.end).max() ?? 0
                    timelineBase += maxEnd + 1_000
                case .image:
                    let globalIndex = output.count + 1
                    output.append(PageCandidate(
                        candidateID: String(format: "%@-candidate-%04d", request.bookID, globalIndex),
                        bookID: request.bookID,
                        sourceTimeMS: timelineBase,
                        sourceRangeMS: .init(start: timelineBase, end: timelineBase),
                        imageRef: asset.localURL.path,
                        stabilityScore: 1,
                        sharpnessScore: 1,
                        motionScore: 0,
                        duplicateGroupID: nil,
                        flags: ["direct-image-input"]
                    ))
                    timelineBase += 1_000
                }
                await progress(.init(stage: .frameExtraction, fraction: Double(assetIndex + 1) / Double(totalAssets), completedUnits: output.count, totalUnits: nil))
            }

            try writeJSON(output, to: stageURL.appendingPathComponent("candidates.json"))
            return ProductStageArtifact(stage: .frameExtraction, outputURL: stageURL, pageCount: output.count)
        }
    }

    private static func imageCorrectionBinding() -> ProductPipelineStageBinding {
        ProductPipelineStageBinding(stage: .imageCorrection) { request, artifacts, progress in
            let input = try artifact(.frameExtraction, in: artifacts)
            let candidates: [PageCandidate] = try readJSON(from: input.outputURL.appendingPathComponent("candidates.json"))
            let stageURL = request.workspaceURL.appendingPathComponent("02-image-correction", isDirectory: true)
            try resetDirectory(stageURL)
            let readingDir = stageURL.appendingPathComponent("reading", isDirectory: true)
            let ocrDir = stageURL.appendingPathComponent("ocr", isDirectory: true)
            try FileManager.default.createDirectory(at: readingDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: ocrDir, withIntermediateDirectories: true)

            let engine = PageCorrectionEngine()
            let context = CIContext(options: nil)
            var corrected: [RuntimeCorrectedPage] = []
            let total = max(1, candidates.count)

            for (index, candidate) in candidates.enumerated() {
                try Task.checkCancellation()
                let pageID = String(format: "%@-page-%04d", request.bookID, index + 1)
                let sourceURL = localURL(candidate.imageRef)
                let readingURL = readingDir.appendingPathComponent(String(format: "%04d.jpg", index + 1))
                let ocrURL = ocrDir.appendingPathComponent(String(format: "%04d.jpg", index + 1))
                var metadata: CorrectedPageMetadata?
                var stageFailure: String?

                do {
                    let sourceImage = try loadCGImage(sourceURL)
                    let assets = try engine.correct(cgImage: sourceImage, candidateID: candidate.candidateID, pageID: pageID)
                    guard let readingImage = assets.images[.reading], let ocrImage = assets.images[.ocr] else {
                        throw ProductionScannerRuntimeError.unreadableImage(sourceURL)
                    }
                    try writeJPEG(readingImage, context: context, to: readingURL)
                    try writeJPEG(ocrImage, context: context, to: ocrURL)
                    metadata = assets.metadata[.reading]
                } catch {
                    // Fail closed at page level: retain the source image and route the
                    // page to review instead of aborting the entire book.
                    let sourceImage = try loadCGImage(sourceURL)
                    try writeJPEG(CIImage(cgImage: sourceImage), context: context, to: readingURL)
                    try writeJPEG(CIImage(cgImage: sourceImage), context: context, to: ocrURL)
                    stageFailure = "image_correction: \(error.localizedDescription)"
                }

                corrected.append(.init(
                    pageID: pageID,
                    candidate: candidate,
                    metadata: metadata,
                    readingImagePath: readingURL.path,
                    ocrImagePath: ocrURL.path,
                    stageFailure: stageFailure
                ))
                await progress(.init(stage: .imageCorrection, fraction: Double(index + 1) / Double(total), completedUnits: index + 1, totalUnits: candidates.count))
            }

            try writeJSON(corrected, to: stageURL.appendingPathComponent("corrected-pages.json"))
            let reviews = corrected.compactMap { page -> ProductReviewItem? in
                guard let failure = page.stageFailure else { return nil }
                return .init(id: "correction|\(page.pageID)", pageIDs: [page.pageID], reason: "image_correction_failed", detail: failure)
            }
            return ProductStageArtifact(stage: .imageCorrection, outputURL: stageURL, pageCount: corrected.count, reviewItems: reviews)
        }
    }

    private static func pageAuditBinding() -> ProductPipelineStageBinding {
        ProductPipelineStageBinding(stage: .pageAudit) { request, artifacts, progress in
            let input = try artifact(.imageCorrection, in: artifacts)
            let corrected: [RuntimeCorrectedPage] = try readJSON(from: input.outputURL.appendingPathComponent("corrected-pages.json"))
            let stageURL = request.workspaceURL.appendingPathComponent("03-page-audit", isDirectory: true)
            try resetDirectory(stageURL)
            var records: [PipelinePageRecord] = []
            var ocrImageByPageID: [String: String] = [:]
            let total = max(1, corrected.count)

            for (index, page) in corrected.enumerated() {
                try Task.checkCancellation()
                let imageURL = URL(fileURLWithPath: page.readingImagePath)
                var signals = PipelineAuditSignals()
                var failure = page.stageFailure
                do {
                    let recognition = try VisionPageAuditRecognizer.recognizePage(at: imageURL, pageID: page.pageID)
                    signals.pageNumber = recognition.pageNumber
                    signals.text = recognition.bodyText
                } catch {
                    failure = [failure, "page_audit_recognition: \(error.localizedDescription)"].compactMap { $0 }.joined(separator: " | ")
                }
                signals.perceptualHash = PagePerceptualHasher.dHash64(imageAt: imageURL)
                records.append(.init(
                    pageID: page.pageID,
                    candidate: page.candidate,
                    correction: page.metadata,
                    correctedImageRef: page.readingImagePath,
                    auditSignals: signals,
                    stageFailure: failure
                ))
                ocrImageByPageID[page.pageID] = page.ocrImagePath
                await progress(.init(stage: .pageAudit, fraction: Double(index + 1) / Double(total), completedUnits: index + 1, totalUnits: corrected.count))
            }

            let bridged = PipelineAuditBridge().audit(records)
            let snapshot = RuntimeAuditedBook(auditResult: bridged.auditResult, lineage: bridged.lineage, ocrImageByPageID: ocrImageByPageID)
            try writeJSON(snapshot, to: stageURL.appendingPathComponent("audit.json"))
            try writeJSON(bridged.auditResult, to: stageURL.appendingPathComponent("page-audit-result.json"))

            let reviews = bridged.auditResult.reviewRequired.enumerated().map { index, item in
                ProductReviewItem(
                    id: "audit|\(index)|\(item.reason.rawValue)|\(item.pageIDs.joined(separator: ","))",
                    pageIDs: item.pageIDs,
                    reason: item.reason.rawValue,
                    detail: item.detail
                )
            }
            return ProductStageArtifact(stage: .pageAudit, outputURL: stageURL, pageCount: bridged.auditResult.orderedPageIDs.count, reviewItems: reviews)
        }
    }

    private static func ocrBinding() -> ProductPipelineStageBinding {
        ProductPipelineStageBinding(stage: .ocr) { request, artifacts, progress in
            let input = try artifact(.pageAudit, in: artifacts)
            let audited: RuntimeAuditedBook = try readJSON(from: input.outputURL.appendingPathComponent("audit.json"))
            let stageURL = request.workspaceURL.appendingPathComponent("04-ocr", isDirectory: true)
            try resetDirectory(stageURL)
            let engine = AppleVisionBookOCR()
            let lineageByID = Dictionary(uniqueKeysWithValues: audited.lineage.map { ($0.pageID, $0) })
            var pages: [OCRPage] = []
            var failures: [String: String] = [:]
            let total = max(1, audited.auditResult.orderedPageIDs.count)

            for (index, pageID) in audited.auditResult.orderedPageIDs.enumerated() {
                try Task.checkCancellation()
                guard let imagePath = audited.ocrImageByPageID[pageID] else {
                    throw ProductionScannerRuntimeError.missingOCRImage(pageID)
                }
                do {
                    pages.append(try engine.recognizePage(
                        url: URL(fileURLWithPath: imagePath),
                        pageID: pageID,
                        sourceTimeMS: lineageByID[pageID]?.sourceTimeMS
                    ))
                } catch {
                    failures[pageID] = error.localizedDescription
                    pages.append(OCRPage(
                        pageID: pageID,
                        layout: .unknown,
                        text: "",
                        blocks: [],
                        ocrConfidence: 0,
                        engine: "apple-vision",
                        engineVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                        needsReview: true,
                        sourceTimeMS: lineageByID[pageID]?.sourceTimeMS
                    ))
                }
                await progress(.init(stage: .ocr, fraction: Double(index + 1) / Double(total), completedUnits: index + 1, totalUnits: audited.auditResult.orderedPageIDs.count))
            }

            try writeJSON(RuntimeOCRSnapshot(pages: pages, failures: failures), to: stageURL.appendingPathComponent("ocr.json"))
            let reviews = pages.filter(\.needsReview).map { page in
                ProductReviewItem(
                    id: "ocr|\(page.pageID)",
                    pageIDs: [page.pageID],
                    reason: failures[page.pageID] == nil ? "ocr_low_confidence" : "ocr_failed",
                    detail: failures[page.pageID] ?? "OCR confidence/layout requires review."
                )
            }
            return ProductStageArtifact(stage: .ocr, outputURL: stageURL, pageCount: pages.count, reviewItems: reviews)
        }
    }

    private static func packageBinding() -> ProductPipelineStageBinding {
        ProductPipelineStageBinding(stage: .packageWrite) { request, artifacts, progress in
            let auditArtifact = try artifact(.pageAudit, in: artifacts)
            let ocrArtifact = try artifact(.ocr, in: artifacts)
            let audited: RuntimeAuditedBook = try readJSON(from: auditArtifact.outputURL.appendingPathComponent("audit.json"))
            let ocr: RuntimeOCRSnapshot = try readJSON(from: ocrArtifact.outputURL.appendingPathComponent("ocr.json"))
            let packageParent = request.workspaceURL.appendingPathComponent("05-book-package", isDirectory: true)
            try resetDirectory(packageParent)
            await progress(.init(stage: .packageWrite, fraction: 0.25, completedUnits: 0, totalUnits: audited.auditResult.orderedPageIDs.count))

            let result = try PipelineOCRBridge().write(
                bookID: request.bookID,
                auditResult: audited.auditResult,
                lineage: audited.lineage,
                ocrPages: ocr.pages,
                destination: packageParent
            )
            await progress(.init(stage: .packageWrite, fraction: 0.75, completedUnits: result.artifacts.count, totalUnits: result.artifacts.count))

            let integrity = PackageIntegrityVerifier().verify(rootURL: result.package.rootURL)
            try PackageIntegrityVerifier.jsonData(integrity).write(to: result.package.rootURL.appendingPathComponent("integrity-report.json"), options: .atomic)
            try PackageIntegrityVerifier.markdown(integrity).write(to: result.package.rootURL.appendingPathComponent("integrity-report.md"), atomically: true, encoding: .utf8)
            guard integrity.valid else {
                throw ProductionScannerRuntimeError.packageIntegrityFailed(integrity.summary.errorCount)
            }

            var reviews = result.package.reviewRequiredPageIDs.map { pageID in
                ProductReviewItem(id: "package|review|\(pageID)", pageIDs: [pageID], reason: "package_page_requires_review", detail: "BookPackage manifest marks this page as needs_review.")
            }
            reviews.append(contentsOf: integrity.issues.filter { $0.severity == .warning }.map { issue in
                ProductReviewItem(
                    id: "package|warning|\(issue.code.rawValue)|\(issue.pageID ?? "book")",
                    pageIDs: issue.pageID.map { [$0] } ?? [],
                    reason: issue.code.rawValue,
                    detail: issue.detail
                )
            })
            await progress(.init(stage: .packageWrite, fraction: 1, completedUnits: result.artifacts.count, totalUnits: result.artifacts.count))
            return ProductStageArtifact(stage: .packageWrite, outputURL: result.package.rootURL, pageCount: result.artifacts.count, reviewItems: reviews)
        }
    }

    private static func artifact(_ stage: ProductProcessingStage, in artifacts: [ProductStageArtifact]) throws -> ProductStageArtifact {
        guard let value = artifacts.last(where: { $0.stage == stage }) else { throw ProductionScannerRuntimeError.missingArtifact(stage) }
        return value
    }

    private static func resetDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func readJSON<T: Decodable>(from url: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private static func localURL(_ reference: String) -> URL {
        if reference.hasPrefix("file://"), let url = URL(string: reference), url.isFileURL { return url }
        return URL(fileURLWithPath: reference)
    }

    private static func loadCGImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ProductionScannerRuntimeError.unreadableImage(url)
        }
        return image
    }

    private static func writeJPEG(_ image: CIImage, context: CIContext, to url: URL) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ProductionScannerRuntimeError.imageWriteFailed(url)
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.94] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ProductionScannerRuntimeError.imageWriteFailed(url) }
    }
}
#else
public enum ProductionScannerRuntime {
    public static func makeDriver() -> any ProductPipelineDriving {
        BoundProductPipelineDriver(bindings: [])
    }
    public static func makeBindings() -> [ProductPipelineStageBinding] { [] }
}
#endif
