#if canImport(Vision) && canImport(CoreGraphics) && canImport(ImageIO)
import Foundation

public enum PageAuditInputFactory {
    public static func make(
        pageID: String,
        sourceTimeMs: Int64,
        correctedImageURL: URL,
        requestedRotation: Int? = nil
    ) throws -> PageAuditInput {
        let recognition = try VisionPageAuditRecognizer.recognizePage(
            at: correctedImageURL,
            pageID: pageID,
            requestedRotation: requestedRotation
        )
        let perceptualHash = PagePerceptualHasher.dHash64(imageAt: correctedImageURL)

        return PageAuditInput(
            pageID: pageID,
            sourceTimeMs: sourceTimeMs,
            pageNumber: recognition.pageNumber,
            perceptualHash: perceptualHash,
            text: recognition.bodyText
        )
    }
}
#endif
