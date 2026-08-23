import Foundation
import ProductFlow
import ScannerRuntime

#if canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers) && canImport(Vision)
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

private struct GoldenHardenedCorrectedPage: Codable, Sendable {
    let pageID: String
    let candidate: PageCandidate
    let metadata: CorrectedPageMetadata?
    let readingImagePath: String
    let ocrImagePath: String
    let stageFailure: String?
}

/// Golden-driven product composition. It keeps the already validated production
/// bindings for extraction/audit/OCR/package, but hardens the correction boundary
/// so a stable frame is not automatically equivalent to a book page and an open
/// spread may emit two independent pages.
public enum GoldenHardenedScannerRuntime {
    public static func makeDriver() -> any ProductPipelineDriving {
        let bindings = ProductionScannerRuntime.makeBindings().map { binding in
            binding.stage == .imageCorrection ? imageCorrectionBinding() : binding
        }
        return BoundProductPipelineDriver(bindings: bindings)
    }

    public static func imageCorrectionBinding() -> ProductPipelineStageBinding {
        ProductPipelineStageBinding(stage: .imageCorrection) { request, artifacts, progress in
            guard let input = artifacts.first(where: { $0.stage == .frameExtraction }) else {
                throw ProductionScannerRuntimeError.missingArtifact(.frameExtraction)
            }
            let candidates: [PageCandidate] = try readJSON(from: input.outputURL.appendingPathComponent("candidates.json"))
            let stageURL = request.workspaceURL.appendingPathComponent("02-image-correction", isDirectory: true)
            try resetDirectory(stageURL)
            let readingDir = stageURL.appendingPathComponent("reading", isDirectory: true)
            let ocrDir = stageURL.appendingPathComponent("ocr", isDirectory: true)
            try FileManager.default.createDirectory(at: readingDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: ocrDir, withIntermediateDirectories: true)

            let segmentation = BookPageSegmentationEngine()
            let correction = PageCorrectionEngine()
            let context = CIContext(options: nil)
            var corrected: [GoldenHardenedCorrectedPage] = []
            var reviews: [ProductReviewItem] = []
            let total = max(1, candidates.count)

            for (candidateIndex, candidate) in candidates.enumerated() {
                try Task.checkCancellation()
                let sourceURL = localURL(candidate.imageRef)
                let sourceImage = try loadCGImage(sourceURL)
                let segments: [BookPageSegment]
                do {
                    segments = try segmentation.segment(cgImage: sourceImage)
                } catch {
                    reviews.append(.init(
                        id: "segmentation|error|\(candidate.candidateID)",
                        pageIDs: [],
                        reason: "page_segmentation_failed",
                        detail: "Candidate \(candidate.candidateID) could not be segmented: \(error.localizedDescription)"
                    ))
                    await progress(.init(stage: .imageCorrection, fraction: Double(candidateIndex + 1) / Double(total), completedUnits: corrected.count, totalUnits: nil))
                    continue
                }

                guard !segments.isEmpty else {
                    reviews.append(.init(
                        id: "segmentation|rejected|\(candidate.candidateID)",
                        pageIDs: [],
                        reason: "non_page_or_unresolved_frame",
                        detail: "Stable frame was rejected because no plausible book page/spread geometry was found."
                    ))
                    await progress(.init(stage: .imageCorrection, fraction: Double(candidateIndex + 1) / Double(total), completedUnits: corrected.count, totalUnits: nil))
                    continue
                }

                for segment in segments {
                    try Task.checkCancellation()
                    let pageNumber = corrected.count + 1
                    let pageID = String(format: "%@-page-%04d", request.bookID, pageNumber)
                    let readingURL = readingDir.appendingPathComponent(String(format: "%04d.jpg", pageNumber))
                    let ocrURL = ocrDir.appendingPathComponent(String(format: "%04d.jpg", pageNumber))
                    var metadata: CorrectedPageMetadata?
                    var stageFailure: String?

                    do {
                        let assets = try correction.correct(cgImage: segment.image, candidateID: candidate.candidateID, pageID: pageID)
                        guard let readingImage = assets.images[.reading], let ocrImage = assets.images[.ocr] else {
                            throw ProductionScannerRuntimeError.unreadableImage(sourceURL)
                        }
                        try writeJPEG(readingImage, context: context, to: readingURL)
                        try writeJPEG(ocrImage, context: context, to: ocrURL)
                        metadata = assets.metadata[.reading]
                    } catch {
                        try writeJPEG(CIImage(cgImage: segment.image), context: context, to: readingURL)
                        try writeJPEG(CIImage(cgImage: segment.image), context: context, to: ocrURL)
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
                    if let stageFailure {
                        reviews.append(.init(
                            id: "correction|\(pageID)",
                            pageIDs: [pageID],
                            reason: "image_correction_failed",
                            detail: stageFailure
                        ))
                    }
                    if segment.role != .single {
                        reviews.append(.init(
                            id: "spread|\(pageID)",
                            pageIDs: [pageID],
                            reason: "spread_page_segmented",
                            detail: "Open-book candidate was segmented as \(segment.role.rawValue) page with confidence \(String(format: "%.3f", segment.confidence))."
                        ))
                    }
                }

                await progress(.init(stage: .imageCorrection, fraction: Double(candidateIndex + 1) / Double(total), completedUnits: corrected.count, totalUnits: nil))
            }

            guard !corrected.isEmpty else {
                throw ProductPipelineDriverError.stageFailed(stage: .imageCorrection, detail: "No plausible book pages were detected in the selected input.")
            }
            try writeJSON(corrected, to: stageURL.appendingPathComponent("corrected-pages.json"))
            return ProductStageArtifact(stage: .imageCorrection, outputURL: stageURL, pageCount: corrected.count, reviewItems: reviews)
        }
    }

    private static func localURL(_ ref: String) -> URL {
        if let url = URL(string: ref), url.isFileURL { return url }
        return URL(fileURLWithPath: ref)
    }

    private static func loadCGImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ProductionScannerRuntimeError.unreadableImage(url)
        }
        return image
    }

    private static func writeJPEG(_ image: CIImage, context: CIContext, to url: URL) throws {
        guard let cgImage = context.createCGImage(image, from: image.extent.integral),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ProductionScannerRuntimeError.imageWriteFailed(url)
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ProductionScannerRuntimeError.imageWriteFailed(url)
        }
    }

    private static func resetDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func readJSON<T: Decodable>(from url: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
#endif
