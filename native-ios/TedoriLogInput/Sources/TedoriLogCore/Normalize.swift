import Foundation

/// 文字列・金額の正規化。PDF直接抽出でもOCRでも同じ関数を通す。
public enum Normalize {

    /// 全角英数字・記号を半角へ寄せる。
    public static func toHalfWidth(_ input: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in input.unicodeScalars {
            switch scalar {
            case "\u{FF01}"..."\u{FF5E}":
                out.append(UnicodeScalar(scalar.value - 0xFEE0)!)
            case "\u{3000}":
                out.append(" ")
            case "\u{FF0C}", "\u{FF64}":
                out.append(",")
            case "\u{FF0E}", "\u{FF61}":
                out.append(".")
            default:
                out.append(scalar)
            }
        }
        return String(out)
    }

    private static let labelStrip = CharacterSet(charactersIn: "【】[]()（）:：|｜<>＜＞*＊#・、。,. \t\n")

    /// ラベル比較用の正規化。空白・装飾記号を落とす。
    public static func normalizeLabel(_ input: String) -> String {
        let half = toHalfWidth(input)
        var scalars = String.UnicodeScalarView()
        for scalar in half.unicodeScalars where !labelStrip.contains(scalar) {
            scalars.append(scalar)
        }
        return String(scalars)
    }

    // 金額として扱ってはいけない文脈（日付・時刻・時間数・率）
    private static let nonAmountPatterns: [NSRegularExpression] = [
        #"\d{4}\s*[-/年]\s*\d{1,2}"#,
        #"\d{1,2}\s*[-/]\s*\d{1,2}\s*[-/]"#,
        #"\d{1,2}\s*月"#,
        #"\d{1,2}\s*日(?!当)"#,
        #"\d{1,2}\s*:\s*\d{2}"#,
        #"\d\s*[%％]"#,
        #"\d\s*(時間|Ｈ|h|hr|回|名|人|才|歳)"#,
    ].map { try! NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

    private static let amountCharacters = CharacterSet(charactersIn: "-+−▲△Δ¥￥円()（）0123456789,. ")

    public struct Amount: Equatable {
        public let value: Int
        public let negative: Bool
        public let confidence: Double
        public let raw: String
    }

    /// 金額文字列を数値へ正規化する。
    /// 対応: 1,234 / ¥1,234 / 1 234 / -1,234 / △1,234 / (1,234) / 1234円 / 全角数字 /
    ///       OCRのゆれ（カンマを点と誤読、△をAと誤読、余分な空白）
    public static func parseAmount(_ raw: String?) -> Amount? {
        guard let original = raw else { return nil }
        var text = toHalfWidth(original).trimmingCharacters(in: .whitespaces)
        // 全角数字を半角へ
        text = String(text.unicodeScalars.map { scalar -> Character in
            if scalar.value >= 0xFF10 && scalar.value <= 0xFF19 {
                return Character(UnicodeScalar(scalar.value - 0xFF10 + 48)!)
            }
            return Character(scalar)
        })
        guard !text.isEmpty, text.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }
        for pattern in nonAmountPatterns where matches(pattern, text) { return nil }

        var confidence = 1.0
        var negative = false

        let compact = text.replacingOccurrences(of: " ", with: "")
        if compact.hasPrefix("("), compact.hasSuffix(")") {
            negative = true
            text = text.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let first = trimmed.first, "▲△Δ-−".contains(first) {
            negative = true
            text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if let first = trimmed.first, first == "A" || first == "a",
                  let second = trimmed.dropFirst().first, second.isNumber || second == "¥" || second == "￥" {
            // OCRが△をAと読むことがある
            negative = true
            confidence -= 0.1
            text = String(trimmed.dropFirst())
        }
        text = text.replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "円", with: "")
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty,
              cleaned.unicodeScalars.allSatisfy({ amountCharacters.contains($0) }),
              cleaned.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }

        var body = cleaned
        // 末尾の小数部（.00 など）は円未満として切り捨て
        if let range = body.range(of: #"^(.*)\.(\d{1,2})$"#, options: .regularExpression) {
            let head = String(body[range]).components(separatedBy: ".").dropLast().joined(separator: ".")
            if head.rangeOfCharacter(from: .decimalDigits) != nil {
                body = head
                confidence -= 0.05
            }
        }
        let separators = body.filter { $0 == "," || $0 == "." }.count
        body = body.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
        guard !body.isEmpty, body.allSatisfy({ $0.isNumber }) else { return nil }

        if separators > 0 {
            let groups = cleaned.replacingOccurrences(of: " ", with: "")
                .components(separatedBy: CharacterSet(charactersIn: ",."))
            let wellFormed = groups.dropFirst().allSatisfy { $0.count == 3 }
            if !wellFormed { confidence -= 0.2 }
        } else if body.count > 4 {
            confidence -= 0.05
        }
        guard body.count <= 9, let value = Int(body) else { return nil }
        if original.replacingOccurrences(of: " ", with: "").count > 18 { confidence -= 0.1 }

        return Amount(value: negative ? -value : value,
                      negative: negative,
                      confidence: max(0.1, confidence),
                      raw: original)
    }

    /// 給与明細の金額としての妥当さ。
    public static func amountPlausibility(_ value: Int) -> Double {
        let v = abs(value)
        if v == 0 { return 0.5 }
        if v < 100 { return 0.35 }
        if v < 1000 { return 0.8 }
        if v <= 9_999_999 { return 1 }
        return 0.3
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }

    /// 文字列全体が数文字違いなら部分点（OCRの文字化け対策）。部分文字列のあいまい一致は許さない。
    public static func fuzzyContains(_ text: String, _ variant: String) -> Double {
        guard !variant.isEmpty else { return 0 }
        if text.contains(variant) { return 1 }
        guard variant.count >= 4 else { return 0 }
        let maxDistance = variant.count >= 7 ? 2 : 1
        guard abs(text.count - variant.count) <= maxDistance else { return 0 }
        let d = levenshtein(text, variant)
        if d > maxDistance { return 0 }
        return d == 1 ? 0.78 : 0.6
    }

    static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func firstMatchText(_ regex: NSRegularExpression, _ text: String) -> String? {
        guard let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(m.range, in: text) else { return nil }
        return String(text[range])
    }
}
