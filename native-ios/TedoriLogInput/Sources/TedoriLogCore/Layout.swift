import Foundation

/// 位置つきテキスト（PDF直接抽出でもVisionでも同じ形にする）。
/// 座標は左上原点・ポイント単位。
public struct TextToken: Codable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public var conf: Double
    public var page: Int

    public init(text: String, x: Double, y: Double, w: Double, h: Double, conf: Double = 1, page: Int = 1) {
        self.text = text
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.conf = conf
        self.page = page
    }

    public var right: Double { x + w }
    public var centerX: Double { x + w / 2 }
    public var centerY: Double { y + h / 2 }

    enum CodingKeys: String, CodingKey { case text, x, y, w, h, conf, page }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        w = try c.decodeIfPresent(Double.self, forKey: .w) ?? 0
        h = try c.decodeIfPresent(Double.self, forKey: .h) ?? 0
        conf = try c.decodeIfPresent(Double.self, forKey: .conf) ?? 1
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
    }
}

struct LayoutRow {
    var index: Int
    var tokens: [TextToken]
    var key: Double
}

struct Layout {
    var rows: [LayoutRow]
    var tokens: [TextToken]
    var slope: Double
    var medianHeight: Double
}

enum LayoutBuilder {

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func rowKey(_ token: TextToken, slope: Double) -> Double {
        token.centerY - slope * token.centerX
    }

    private static func clusterRows(_ tokens: [TextToken], slope: Double, tolerance: Double) -> [[TextToken]] {
        let sorted = tokens.sorted { rowKey($0, slope: slope) < rowKey($1, slope: slope) }
        var rows: [[TextToken]] = []
        var current: [TextToken] = []
        var anchor: Double?
        for token in sorted {
            let key = rowKey(token, slope: slope)
            if anchor == nil || abs(key - anchor!) <= tolerance {
                if anchor == nil { anchor = key }
                current.append(token)
                anchor = (anchor! * Double(current.count - 1) + key) / Double(current.count)
            } else {
                rows.append(current)
                current = [token]
                anchor = key
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    /// 紙を斜めに撮った写真の傾きを推定する。
    static func estimateSkew(_ tokens: [TextToken], medianHeight: Double) -> Double {
        guard tokens.count >= 6 else { return 0 }
        let tolerance = max(2, medianHeight * 0.5)
        var best = (slope: 0.0, cost: Double.infinity)
        var slope = -0.08
        while slope <= 0.0801 {
            let rows = clusterRows(tokens, slope: slope, tolerance: tolerance)
            var spread = 0.0
            for row in rows {
                let keys = row.map { rowKey($0, slope: slope) }
                spread += (keys.max() ?? 0) - (keys.min() ?? 0)
            }
            let cost = Double(rows.count) * tolerance + spread
            if cost < best.cost - 1e-9 { best = (slope, cost) }
            slope += 0.0025
        }
        return abs(best.slope) < 0.0026 ? 0 : best.slope
    }

    private static func isCJK(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x3000...0x30FF, 0x4E00...0x9FFF, 0xFF00...0xFFEF: return true
        default: return false
        }
    }

    private static func isNumericTail(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return last.isNumber || last == "," || last == "."
    }

    private static func isNumericHead(_ text: String) -> Bool {
        guard let first = text.first else { return false }
        return first.isNumber || first == "," || first == "."
    }

    /// 同一行内で近接するトークンを連結する（OCRの単語分割を戻す）。
    private static func mergeRowTokens(_ row: [TextToken], medianHeight: Double) -> [TextToken] {
        let sorted = row.sorted { $0.x < $1.x }
        var out: [TextToken] = []
        for token in sorted {
            guard var prev = out.last else { out.append(token); continue }
            let gap = token.x - prev.right
            let numericJoin = isNumericTail(prev.text) && isNumericHead(token.text)
            let cjkJoin = isCJK(prev.text.last ?? " ") && isCJK(token.text.first ?? " ")
            let limit = numericJoin ? medianHeight * 0.9 : medianHeight * 0.8
            if gap >= -medianHeight * 0.3, gap <= limit, numericJoin || cjkJoin {
                prev.text += token.text
                prev.w = token.right - prev.x
                prev.h = max(prev.h, token.h)
                prev.conf = min(prev.conf, token.conf)
                out[out.count - 1] = prev
            } else {
                out.append(token)
            }
        }
        return out
    }

    private static let labelAmount = try! NSRegularExpression(
        pattern: #"^([^\d０-９]*[^\d０-９\s])[\s]*([-+−▲△¥￥(（]?[\d０-９][\d０-９,.\s]*[)）]?円?)$"#)

    /// 「基本給252,000」のようにラベルと金額がくっついたトークンを分割する。
    private static func splitLabelAmount(_ token: TextToken) -> [TextToken] {
        let text = token.text.trimmingCharacters(in: .whitespaces)
        guard text.count >= 3 else { return [token] }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = labelAmount.firstMatch(in: text, range: range),
              let labelRange = Range(m.range(at: 1), in: text),
              let amountRange = Range(m.range(at: 2), in: text) else { return [token] }
        let labelPart = String(text[labelRange])
        let amountPart = String(text[amountRange])
        guard labelPart.count >= 2, Normalize.parseAmount(amountPart) != nil else { return [token] }
        if let last = labelPart.last, "年月日".contains(last) { return [token] }

        let labelWidth = token.w * Double(labelPart.count) / Double(text.count)
        var labelToken = token
        labelToken.text = labelPart
        labelToken.w = labelWidth
        var amountToken = token
        amountToken.text = amountPart
        amountToken.x = token.x + labelWidth
        amountToken.w = token.w - labelWidth
        return [labelToken, amountToken]
    }

    static func build(_ rawTokens: [TextToken]) -> Layout {
        let tokens = rawTokens.compactMap { token -> TextToken? in
            let text = Normalize.toHalfWidth(token.text).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            var copy = token
            copy.text = text
            return copy
        }
        guard !tokens.isEmpty else { return Layout(rows: [], tokens: [], slope: 0, medianHeight: 0) }

        let heights = tokens.map(\.h).filter { $0 > 0 }
        let medianHeight = median(heights) == 0 ? 10 : median(heights)
        let slope = estimateSkew(tokens, medianHeight: medianHeight)
        let tolerance = max(2, medianHeight * 0.55)

        var rows: [LayoutRow] = []
        for group in clusterRows(tokens, slope: slope, tolerance: tolerance) {
            let merged = mergeRowTokens(group, medianHeight: medianHeight).flatMap(splitLabelAmount)
            let sorted = merged.sorted { $0.x < $1.x }
            let key = median(sorted.map { rowKey($0, slope: slope) })
            rows.append(LayoutRow(index: 0, tokens: sorted, key: key))
        }
        rows.sort { $0.key < $1.key }
        for i in rows.indices { rows[i].index = i }

        return Layout(rows: rows, tokens: rows.flatMap(\.tokens), slope: slope, medianHeight: medianHeight)
    }

    /// 金額トークンの右端から「金額列」を推定する。
    static func detectAmountColumns(_ amounts: [Double], medianHeight: Double) -> [Double] {
        let edges = amounts.sorted()
        var columns: [(center: Double, members: [Double])] = []
        let tolerance = max(6, medianHeight * 1.2)
        for edge in edges {
            if var last = columns.last, edge - last.center <= tolerance {
                last.members.append(edge)
                last.center = last.members.reduce(0, +) / Double(last.members.count)
                columns[columns.count - 1] = last
            } else {
                columns.append((edge, [edge]))
            }
        }
        return columns.filter { $0.members.count >= 2 }.map(\.center)
    }

    /// ラベル列と金額列を、左から右の順序を保ったまま対応付ける。
    static func monotonicMatch(labelCenters: [Double], amountCenters: [Double]) -> [Int: Int] {
        let n = labelCenters.count
        let m = amountCenters.count
        guard n > 0, m > 0 else { return [:] }
        var dp = Array(repeating: Array(repeating: Double.infinity, count: m + 1), count: n + 1)
        var choice = Array(repeating: Array(repeating: "", count: m + 1), count: n + 1)
        for j in 0...m { dp[n][j] = 0 }
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                let pair = abs(labelCenters[i] - amountCenters[j]) + dp[i + 1][j + 1]
                let skip = dp[i][j + 1] + 1
                if pair <= skip {
                    dp[i][j] = pair
                    choice[i][j] = "pair"
                } else {
                    dp[i][j] = skip
                    choice[i][j] = "skip"
                }
            }
        }
        var result: [Int: Int] = [:]
        var i = 0, j = 0
        while i < n && j < m {
            if choice[i][j] == "pair" {
                result[i] = j
                i += 1
                j += 1
            } else {
                j += 1
            }
        }
        return result
    }
}
