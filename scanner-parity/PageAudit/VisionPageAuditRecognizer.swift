#if canImport(Vision) && canImport(ImageIO)
import Foundation
import ImageIO
import Vision

public struct VisionPageAuditRecognition: Sendable {
    public var pageNumber: PageNumberObservation?
    public var bodyText: String
    public var rotationDegrees: Int
    public var qualityScore: Double

    public init(pageNumber: PageNumberObservation?, bodyText: String, rotationDegrees: Int, qualityScore: Double) {
        self.pageNumber = pageNumber
        self.bodyText = bodyText
        self.rotationDegrees = rotationDegrees
        self.qualityScore = qualityScore
    }
}

public enum VisionPageAuditRecognizer {
    public static func recognizePage(
        at url: URL,
        pageID: String,
        requestedRotation: Int? = nil
    ) throws -> VisionPageAuditRecognition {
        let rotations = requestedRotation.map { [normalizedRotation($0)] } ?? [0, 90, 180, 270]
        var best: RotationRecognition?

        for rotation in rotations {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.minimumTextHeight = 0.004

            let handler = VNImageRequestHandler(
                url: url,
                orientation: imageOrientation(for: rotation),
                options: [:]
            )
            try handler.perform([request])

            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> RecognizedLine? in
                guard let top = observation.topCandidates(1).first else { return nil }
                let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return RecognizedLine(
                    text: text,
                    confidence: Double(top.confidence),
                    box: NormalizedRect(
                        x: observation.boundingBox.origin.x,
                        y: observation.boundingBox.origin.y,
                        width: observation.boundingBox.size.width,
                        height: observation.boundingBox.size.height
                    )
                )
            }

            let sortedLines = lines.sorted { lhs, rhs in
                let verticalDifference = abs(lhs.box.midY - rhs.box.midY)
                if verticalDifference > 0.018 { return lhs.box.midY > rhs.box.midY }
                return lhs.box.x < rhs.box.x
            }
            let bodyText = sortedLines.map(\.text).joined(separator: "\n")
            let score = genericRecognitionScore(text: bodyText, lines: sortedLines.map(\.text))
            let recognition = RotationRecognition(rotation: rotation, lines: sortedLines, bodyText: bodyText, score: score)

            if best == nil || recognition.score > best!.score {
                best = recognition
            }
        }

        guard let best else {
            return VisionPageAuditRecognition(pageNumber: nil, bodyText: "", rotationDegrees: 0, qualityScore: 0)
        }

        let candidates = best.lines.map { line in
            OCRPageNumberCandidate(
                text: line.text,
                confidence: line.confidence,
                boundingBox: line.box,
                rotationDegrees: best.rotation
            )
        }
        let pageNumber = PageNumberScorer.bestObservation(pageID: pageID, candidates: candidates)

        return VisionPageAuditRecognition(
            pageNumber: pageNumber,
            bodyText: best.bodyText,
            rotationDegrees: best.rotation,
            qualityScore: best.score
        )
    }

    private struct RecognizedLine {
        var text: String
        var confidence: Double
        var box: NormalizedRect
    }

    private struct RotationRecognition {
        var rotation: Int
        var lines: [RecognizedLine]
        var bodyText: String
        var score: Double
    }

    private static func genericRecognitionScore(text: String, lines: [String]) -> Double {
        var japanese = 0
        var digits = 0
        var latin = 0
        var noise = 0

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30ff, 0x3400...0x9fff:
                japanese += 1
            case 0x30...0x39:
                digits += 1
            case 0x41...0x5a, 0x61...0x7a:
                latin += 1
            case 0x7c, 0x5f, 0x3c, 0x3e, 0x5c:
                noise += 1
            default:
                break
            }
        }

        let meaningfulLines = lines.filter { line in
            line.unicodeScalars.filter { scalar in
                switch scalar.value {
                case 0x3040...0x30ff, 0x3400...0x9fff, 0x30...0x39:
                    return true
                default:
                    return false
                }
            }.count >= 3
        }.count

        return Double(japanese * 5 + digits + meaningfulLines * 18)
            - Double(latin) * 0.2
            - Double(noise) * 1.5
    }

    private static func normalizedRotation(_ value: Int) -> Int {
        let normalized = ((value % 360) + 360) % 360
        switch normalized {
        case 90, 180, 270: return normalized
        default: return 0
        }
    }

    private static func imageOrientation(for rotation: Int) -> CGImagePropertyOrientation {
        switch normalizedRotation(rotation) {
        case 90: return .right
        case 180: return .down
        case 270: return .left
        default: return .up
        }
    }
}
#endif
