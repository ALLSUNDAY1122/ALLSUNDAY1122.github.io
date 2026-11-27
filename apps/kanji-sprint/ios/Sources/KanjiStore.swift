import Foundation
import SwiftUI

/// kanji-1026.json の1件分。ID は漢字そのもの。
struct KanjiEntry: Codable, Identifiable, Hashable {
    let kanji: String
    let grade: Int
    let strokeCount: Int
    let on: [String]
    let kun: [String]
    let strokes: [String]

    var id: String { kanji }

    /// 音読み（カタカナ）。接頭・接尾の「-」は表示しない。
    var onReadings: [String] { on.map { $0.replacingOccurrences(of: "-", with: "") } }

    /// 訓読み。送り仮名の区切り「.」で stem / okurigana に分けて返す。
    var kunReadings: [KunReading] { kun.map(KunReading.init(raw:)) }

    /// クイズの正解・選択肢に使う読み一覧（「.」「-」を取り除いた形、重複なし）。
    var allReadings: [String] {
        var result: [String] = []
        for raw in on + kun {
            let plain = raw
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ".", with: "")
            if !plain.isEmpty, !result.contains(plain) { result.append(plain) }
        }
        return result
    }
}

/// 訓読み1件。stem が漢字の読み部分、okurigana が送り仮名。
struct KunReading: Hashable {
    let stem: String
    let okurigana: String

    init(raw: String) {
        let cleaned = raw.replacingOccurrences(of: "-", with: "")
        if let dot = cleaned.firstIndex(of: ".") {
            stem = String(cleaned[..<dot])
            okurigana = String(cleaned[cleaned.index(after: dot)...])
        } else {
            stem = cleaned
            okurigana = ""
        }
    }

    /// 区切りを外した全文（例: あ.げる → あげる）。
    var plain: String { stem + okurigana }
}

/// KanjiVG の1画分。Path・点列とも 109×109 座標系。
struct KanjiStroke {
    let path: Path
    let points: [CGPoint]
    var start: CGPoint { points.first ?? .zero }
    var end: CGPoint { points.last ?? .zero }
}

/// KanjiVG の SVG パス文字列（M/m/C/c/S/s のみ使用される）を解析する。
/// 相対座標は絶対座標へ変換し、S/s の第1制御点は直前の曲線の第2制御点を
/// 現在点で反射させて求める（SVG 仕様どおり）。
enum SVGPathParser {
    private enum Token {
        case command(Character)
        case number(Double)
    }

    static func parse(_ d: String) -> KanjiStroke {
        let tokens = tokenize(d)
        var path = Path()
        var points: [CGPoint] = []
        var current = CGPoint.zero
        var prevControl2: CGPoint?
        var prevWasCurve = false
        var index = 0
        var command: Character = " "

        func takeNumber() -> Double? {
            guard index < tokens.count, case .number(let value) = tokens[index] else { return nil }
            index += 1
            return value
        }

        func point(relative: Bool, x: Double, y: Double) -> CGPoint {
            relative
                ? CGPoint(x: current.x + CGFloat(x), y: current.y + CGFloat(y))
                : CGPoint(x: CGFloat(x), y: CGFloat(y))
        }

        while index < tokens.count {
            if case .command(let c) = tokens[index] {
                command = c
                index += 1
                continue
            }
            switch command {
            case "M", "m":
                let relative = command == "m"
                var isFirst = true
                while let x = takeNumber(), let y = takeNumber() {
                    let p = point(relative: relative, x: x, y: y)
                    if isFirst {
                        path.move(to: p)
                        isFirst = false
                    } else {
                        path.addLine(to: p)
                    }
                    points.append(p)
                    current = p
                    prevWasCurve = false
                    prevControl2 = nil
                }
                command = relative ? "l" : "L"
            case "L", "l":
                let relative = command == "l"
                while let x = takeNumber(), let y = takeNumber() {
                    let p = point(relative: relative, x: x, y: y)
                    path.addLine(to: p)
                    points.append(p)
                    current = p
                    prevWasCurve = false
                    prevControl2 = nil
                }
            case "C", "c":
                let relative = command == "c"
                while let x1 = takeNumber(), let y1 = takeNumber(),
                      let x2 = takeNumber(), let y2 = takeNumber(),
                      let x = takeNumber(), let y = takeNumber() {
                    let c1 = point(relative: relative, x: x1, y: y1)
                    let c2 = point(relative: relative, x: x2, y: y2)
                    let end = point(relative: relative, x: x, y: y)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    points.append(contentsOf: sampleCubic(from: current, c1: c1, c2: c2, to: end))
                    prevControl2 = c2
                    prevWasCurve = true
                    current = end
                }
            case "S", "s":
                let relative = command == "s"
                while let x2 = takeNumber(), let y2 = takeNumber(),
                      let x = takeNumber(), let y = takeNumber() {
                    let c1: CGPoint
                    if prevWasCurve, let prev = prevControl2 {
                        c1 = CGPoint(x: 2 * current.x - prev.x, y: 2 * current.y - prev.y)
                    } else {
                        c1 = current
                    }
                    let c2 = point(relative: relative, x: x2, y: y2)
                    let end = point(relative: relative, x: x, y: y)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    points.append(contentsOf: sampleCubic(from: current, c1: c1, c2: c2, to: end))
                    prevControl2 = c2
                    prevWasCurve = true
                    current = end
                }
            default:
                index += 1
            }
        }
        return KanjiStroke(path: path, points: points)
    }

    /// 3次ベジェ曲線をサンプリングした点列（始点は含めず、終点を含む）。
    private static func sampleCubic(from p0: CGPoint, c1 p1: CGPoint, c2 p2: CGPoint, to p3: CGPoint, steps: Int = 20) -> [CGPoint] {
        var result: [CGPoint] = []
        result.reserveCapacity(steps)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * mt * p0.x + 3 * mt * mt * t * p1.x + 3 * mt * t * t * p2.x + t * t * t * p3.x
            let y = mt * mt * mt * p0.y + 3 * mt * mt * t * p1.y + 3 * mt * t * t * p2.y + t * t * t * p3.y
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "M" || c == "m" || c == "C" || c == "c" || c == "S" || c == "s" || c == "L" || c == "l" {
                tokens.append(.command(c))
                i += 1
            } else if c == " " || c == "," || c == "\n" || c == "\t" {
                i += 1
            } else {
                var j = i
                var text = ""
                if j < chars.count, chars[j] == "-" || chars[j] == "+" {
                    text.append(chars[j])
                    j += 1
                }
                var seenDot = false
                while j < chars.count {
                    let ch = chars[j]
                    if ch.isNumber {
                        text.append(ch)
                        j += 1
                    } else if ch == ".", !seenDot {
                        seenDot = true
                        text.append(ch)
                        j += 1
                    } else {
                        break
                    }
                }
                if let value = Double(text) {
                    tokens.append(.number(value))
                }
                i = max(j, i + 1)
            }
        }
        return tokens
    }
}

/// 漢字データの読み込みと検索。パース済みの画はキャッシュする。
final class KanjiStore {
    static let shared = KanjiStore()

    let entries: [KanjiEntry]
    let byGrade: [Int: [KanjiEntry]]
    private let byKanji: [String: KanjiEntry]
    private var strokeCache: [String: [KanjiStroke]] = [:]

    private struct KanjiBank: Decodable {
        let kanji: [KanjiEntry]
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "kanji-1026", withExtension: "json") else {
            assertionFailure("kanji-1026.json is missing from app resources")
            entries = []
            byGrade = [:]
            byKanji = [:]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(KanjiBank.self, from: data).kanji
            precondition(decoded.count == 1026, "Expected 1026 kanji")
            precondition(Set(decoded.map(\.kanji)).count == decoded.count, "Duplicate kanji")
            entries = decoded
        } catch {
            assertionFailure("Kanji decode failed: \(error)")
            entries = []
        }
        byGrade = Dictionary(grouping: entries) { $0.grade }
        byKanji = Dictionary(uniqueKeysWithValues: entries.map { ($0.kanji, $0) })
    }

    func entry(_ kanji: String) -> KanjiEntry? {
        byKanji[kanji]
    }

    /// 筆順どおりのパース済みの画（109×109 座標系）。なぞり判定にも使う。
    func strokes(for entry: KanjiEntry) -> [KanjiStroke] {
        if let cached = strokeCache[entry.kanji] { return cached }
        let parsed = entry.strokes.map(SVGPathParser.parse)
        strokeCache[entry.kanji] = parsed
        return parsed
    }

    /// 今日の学習: 苦手を先に並べ、残りを学年のラウンドロビンで埋める。
    func daily(limit: Int = 10, weakIDs: [String] = []) -> [KanjiEntry] {
        let weakSet = Set(weakIDs)
        var output: [KanjiEntry] = Array(entries.filter { weakSet.contains($0.kanji) }.prefix(limit))
        let used = Set(output.map(\.kanji))
        var buckets: [Int: [KanjiEntry]] = [:]
        for grade in 1...6 {
            buckets[grade] = (byGrade[grade] ?? []).filter { !used.contains($0.kanji) }
        }
        while output.count < limit {
            var added = false
            for grade in 1...6 where output.count < limit {
                if var bucket = buckets[grade], !bucket.isEmpty {
                    output.append(bucket.removeFirst())
                    buckets[grade] = bucket
                    added = true
                }
            }
            if !added { break }
        }
        return output
    }
}

/// KanjiVG の1画（109×109 座標系の Path）を、描画領域に合わせて拡縮する Shape。
struct KanjiStrokeShape: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 109
        let dx = (rect.width - 109 * scale) / 2
        let dy = (rect.height - 109 * scale) / 2
        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy)
        return path.applying(transform)
    }
}
