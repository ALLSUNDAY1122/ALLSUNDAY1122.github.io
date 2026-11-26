import Foundation
import Vision
import UIKit

enum ExtractionError: LocalizedError {
    case unreadableImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "画像を読み込めませんでした。別の画像を選択してください。"
        case .noTextFound: return "文字を読み取れませんでした。明るい場所で撮影し直してください。"
        }
    }
}

/// 初期段階のローカルOCR・候補抽出。
/// AI API接続前の検証用であり、意味解析の完成版ではない。
struct ExtractionService {
    func extract(from image: UIImage) async throws -> (text: String, candidates: [ExtractionCandidate]) {
        guard let cgImage = image.cgImage else { throw ExtractionError.unreadableImage }
        let lines = try await recognize(cgImage: cgImage)
        let text = lines.joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.noTextFound
        }
        return (text, parseCandidates(from: lines))
    }

    private func recognize(cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ja-JP", "en-US"]
                request.usesLanguageCorrection = true

                do {
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                    let lines = (request.results ?? []).compactMap {
                        $0.topCandidates(1).first?.string
                    }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func parseCandidates(from lines: [String]) -> [ExtractionCandidate] {
        let rules: [(TaskCategory, [String])] = [
            (.submission, ["提出", "提出期限", "提出日", "提出してください"]),
            (.event, ["遠足", "運動会", "参観", "発表会", "保育参観", "行事", "開催"]),
            (.item, ["持ち物", "持参", "持ってきて", "水筒", "着替え", "上履き"]),
            (.purchase, ["購入", "用意してください", "準備してください", "注文"]),
            (.response, ["申込", "申し込み", "回答", "出欠", "アンケート"])
        ]

        var seen = Set<String>()
        return lines.compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            guard let match = rules.first(where: { _, words in words.contains(where: line.contains) }) else {
                return nil
            }
            let key = "\(match.0.rawValue)|\(line)"
            guard seen.insert(key).inserted else { return nil }
            let rawDate = firstDateExpression(in: line)
            return ExtractionCandidate(
                title: line,
                category: match.0,
                dueDate: rawDate.flatMap(parseExplicitYearDate),
                rawDateText: rawDate,
                sourceExcerpt: line,
                confidence: 0.65
            )
        }
    }

    private func firstDateExpression(in text: String) -> String? {
        let pattern = #"(?:(?:20\d{2})年)?\s*\d{1,2}月\s*\d{1,2}日(?:\s*[（(][月火水木金土日][）)])?"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private func parseExplicitYearDate(_ text: String) -> Date? {
        let pattern = #"(20\d{2})年\s*(\d{1,2})月\s*(\d{1,2})日"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let yearRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let dayRange = Range(match.range(at: 3), in: text),
              let year = Int(text[yearRange]),
              let month = Int(text[monthRange]),
              let day = Int(text[dayRange]) else { return nil }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        return components.date
    }
}
