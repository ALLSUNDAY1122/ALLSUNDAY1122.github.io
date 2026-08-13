#if canImport(Vision)
import Foundation
import Vision
import CoreImage
import TedoriLogCore

/// 端末内のApple Visionで日本語テキストを読み取る（第二経路）。
/// 画像は端末外へ出さない。ネットワークは一切使わない。
public enum VisionTextRecognizer {

    public struct Reading {
        public var tokens: [TextToken]
        public var meanConfidence: Double
        public var lineCount: Int
    }

    public enum RecognizerError: Error {
        case requestFailed(String)
    }

    /// 日本語＋英数字。iOS16 / macOS13 以降で日本語が使える。
    public static let languages = ["ja-JP", "en-US"]

    public static func recognize(cgImage: CGImage, pageOffsetY: Double = 0, page: Int = 1) throws -> Reading {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // 金額の桁を言語モデルで書き換えられると困る
        request.recognitionLanguages = languages
        request.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw RecognizerError.requestFailed(String(describing: error))
        }
        let observations = request.results ?? []

        let width = Double(cgImage.width)
        let height = Double(cgImage.height)
        // 表示・解析はポイント基準に揃える（72dpi相当へ正規化）
        let scale = width > 0 ? 595.0 / width : 1.0

        var tokens: [TextToken] = []
        var confidenceSum = 0.0
        var confidenceCount = 0

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            confidenceSum += Double(candidate.confidence)
            confidenceCount += 1
            let line = candidate.string

            // 行を空白区切りの語に割り、語ごとの矩形をVisionから取り直す
            var searchStart = line.startIndex
            while searchStart < line.endIndex {
                guard let runStart = line[searchStart...].firstIndex(where: { !$0.isWhitespace }) else { break }
                let runEnd = line[runStart...].firstIndex(where: { $0.isWhitespace }) ?? line.endIndex
                let word = String(line[runStart..<runEnd])
                let box: CGRect
                if let observed = try? candidate.boundingBox(for: runStart..<runEnd)?.boundingBox {
                    box = observed
                } else {
                    box = observation.boundingBox
                }
                tokens.append(TextToken(
                    text: word,
                    x: Double(box.minX) * width * scale,
                    // Visionは左下原点の正規化座標。左上原点のポイントへ変換する
                    y: (1 - Double(box.maxY)) * height * scale + pageOffsetY,
                    w: Double(box.width) * width * scale,
                    h: Double(box.height) * height * scale,
                    conf: Double(candidate.confidence),
                    page: page))
                searchStart = runEnd
            }
        }

        return Reading(tokens: tokens,
                       meanConfidence: confidenceCount > 0 ? confidenceSum / Double(confidenceCount) : 0,
                       lineCount: observations.count)
    }
}
#endif
