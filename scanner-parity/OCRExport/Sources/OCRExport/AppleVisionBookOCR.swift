import Foundation

public enum OCRRecognitionError: Error, LocalizedError {
    case unsupportedPlatform
    case noTextRecognized

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Apple Vision OCR is unavailable on this platform."
        case .noTextRecognized:
            return "No usable text was recognized."
        }
    }
}

#if canImport(Vision) && canImport(ImageIO)
import ImageIO
import Vision

public final class AppleVisionBookOCR: @unchecked Sendable {
    public init() {}

    public func recognizePage(url: URL, pageID: String, sourceTimeMS: Int64? = nil) throws -> OCRPage {
        let candidates: [(Int, CGImagePropertyOrientation)] = [
            (0, .up), (90, .right), (180, .down), (270, .left)
        ]

        var best: OCRPage?
        var bestScore = -Double.infinity

        for (rotation, orientation) in candidates {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.minimumTextHeight = 0.006

            let handler = VNImageRequestHandler(url: url, orientation: orientation, options: [:])
            try handler.perform([request])

            let raw = (request.results ?? []).enumerated().compactMap { index, observation -> OCRBlock? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                let box = observation.boundingBox
                return OCRBlock(
                    text: text,
                    confidence: Double(candidate.confidence),
                    boundingBox: OCRRect(
                        x: Double(box.origin.x),
                        y: Double(box.origin.y),
                        width: Double(box.width),
                        height: Double(box.height)
                    ),
                    sourceIndex: index
                )
            }

            guard !raw.isEmpty else { continue }
            let layout = OCRQualityScorer.inferLayout(from: raw)
            let ordered = OCRReadingOrder.ordered(raw, layout: layout)
            let text = ordered.map(\.text).joined(separator: "\n")
            let quality = OCRQualityScorer.evaluate(text: text, blocks: ordered, layout: layout)
            let orientationPenalty = rotation == 0 ? 0.002 : 0.0
            let score = quality.score + orientationPenalty

            if score > bestScore {
                bestScore = score
                best = OCRPage(
                    pageID: pageID,
                    layout: layout,
                    text: text,
                    blocks: ordered,
                    ocrConfidence: quality.score,
                    engine: "apple-vision",
                    engineVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                    needsReview: quality.needsReview,
                    rotationDegrees: rotation,
                    sourceTimeMS: sourceTimeMS
                )
            }
        }

        guard let best, !best.text.isEmpty else { throw OCRRecognitionError.noTextRecognized }
        return best
    }
}
#else
public final class AppleVisionBookOCR: @unchecked Sendable {
    public init() {}

    public func recognizePage(url: URL, pageID: String, sourceTimeMS: Int64? = nil) throws -> OCRPage {
        throw OCRRecognitionError.unsupportedPlatform
    }
}
#endif
