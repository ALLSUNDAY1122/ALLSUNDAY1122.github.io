import Foundation

public enum PipelineOCRBridgeError: Error, LocalizedError, Equatable {
    case duplicateLineagePageID(String)
    case duplicateOCRPageID(String)
    case missingLineage(String)
    case missingOCRPage(String)
    case missingImageReference(String)
    case unsupportedImageReference(pageID: String, reference: String)

    public var errorDescription: String? {
        switch self {
        case .duplicateLineagePageID(let pageID):
            return "Duplicate lineage page_id: \(pageID)"
        case .duplicateOCRPageID(let pageID):
            return "Duplicate OCR page_id: \(pageID)"
        case .missingLineage(let pageID):
            return "Missing lineage for audited page: \(pageID)"
        case .missingOCRPage(let pageID):
            return "Missing OCRPage for audited page: \(pageID)"
        case .missingImageReference(let pageID):
            return "Missing corrected image reference for audited page: \(pageID)"
        case .unsupportedImageReference(let pageID, let reference):
            return "Unsupported non-local image reference for \(pageID): \(reference)"
        }
    }
}

public struct PipelineOCRBridgeResult: Sendable {
    public let artifacts: [OCRPageArtifact]
    public let package: BookPackageResult

    public init(artifacts: [OCRPageArtifact], package: BookPackageResult) {
        self.artifacts = artifacts
        self.package = package
    }
}

/// Thin adapter from the audited pipeline output into OCRExport/BookPackage.
/// It does not redefine Shared Contract models. PageAuditResult owns final order,
/// PipelinePageLineage owns source image/time lineage, and OCRPage owns OCR content.
public struct PipelineOCRBridge: Sendable {
    private let packageWriter: BookPackageWriter

    public init(packageWriter: BookPackageWriter = .init()) {
        self.packageWriter = packageWriter
    }

    public func write(
        bookID: String,
        auditResult: PageAuditResult,
        lineage: [PipelinePageLineage],
        ocrPages: [OCRPage],
        destination: URL
    ) throws -> PipelineOCRBridgeResult {
        let lineageByPageID = try Self.uniqueLineage(lineage)
        let ocrByPageID = try Self.uniqueOCRPages(ocrPages)
        let auditReviewIDs = Set(auditResult.reviewRequired.flatMap(\.pageIDs))

        var artifacts: [OCRPageArtifact] = []
        artifacts.reserveCapacity(auditResult.orderedPageIDs.count)

        for (offset, pageID) in auditResult.orderedPageIDs.enumerated() {
            guard let pageLineage = lineageByPageID[pageID] else {
                throw PipelineOCRBridgeError.missingLineage(pageID)
            }
            guard let originalOCR = ocrByPageID[pageID] else {
                throw PipelineOCRBridgeError.missingOCRPage(pageID)
            }
            guard let imageReference = pageLineage.correctedImageRef, !imageReference.isEmpty else {
                throw PipelineOCRBridgeError.missingImageReference(pageID)
            }

            let imageURL = try Self.localImageURL(pageID: pageID, reference: imageReference)
            let mustReview = originalOCR.needsReview
                || auditReviewIDs.contains(pageID)
                || pageLineage.stageFailure != nil
            let bridgedOCR = OCRPage(
                pageID: originalOCR.pageID,
                language: originalOCR.language,
                layout: originalOCR.layout,
                text: originalOCR.text,
                blocks: originalOCR.blocks,
                ocrConfidence: originalOCR.ocrConfidence,
                engine: originalOCR.engine,
                engineVersion: originalOCR.engineVersion,
                needsReview: mustReview,
                rotationDegrees: originalOCR.rotationDegrees,
                sourceTimeMS: pageLineage.sourceTimeMS
            )

            artifacts.append(OCRPageArtifact(
                sequence: offset + 1,
                imageURL: imageURL,
                ocrPage: bridgedOCR
            ))
        }

        let package = try packageWriter.write(
            bookID: bookID,
            pages: artifacts,
            destination: destination
        )
        return PipelineOCRBridgeResult(artifacts: artifacts, package: package)
    }

    private static func uniqueLineage(_ lineage: [PipelinePageLineage]) throws -> [String: PipelinePageLineage] {
        var result: [String: PipelinePageLineage] = [:]
        for item in lineage {
            if result.updateValue(item, forKey: item.pageID) != nil {
                throw PipelineOCRBridgeError.duplicateLineagePageID(item.pageID)
            }
        }
        return result
    }

    private static func uniqueOCRPages(_ pages: [OCRPage]) throws -> [String: OCRPage] {
        var result: [String: OCRPage] = [:]
        for page in pages {
            if result.updateValue(page, forKey: page.pageID) != nil {
                throw PipelineOCRBridgeError.duplicateOCRPageID(page.pageID)
            }
        }
        return result
    }

    private static func localImageURL(pageID: String, reference: String) throws -> URL {
        if reference.hasPrefix("file://"), let url = URL(string: reference), url.isFileURL {
            return url
        }
        if reference.contains("://") {
            throw PipelineOCRBridgeError.unsupportedImageReference(pageID: pageID, reference: reference)
        }
        return URL(fileURLWithPath: reference)
    }
}
