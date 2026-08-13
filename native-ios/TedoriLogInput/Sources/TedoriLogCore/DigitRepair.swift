import Foundation

/// 合計整合検算を使ったOCR桁誤りの補正。
/// 補正した値は必ず「要確認」で提示する（確定候補にはしない）。
/// 同じくらい尤もらしい直し方が複数ある場合は、正しい値を壊す危険の方が大きいので補正しない。
public enum DigitRepair {

    // OCRが混同しやすい数字（読まれた数字 → 本当は何だった可能性があるか）
    private static let reverse: [Character: [Character]] = {
        let confusion: [Character: String] = [
            "0": "9683", "1": "74", "2": "73", "3": "8952", "4": "917",
            "5": "6839", "6": "5809", "7": "129", "8": "36059", "9": "04378",
        ]
        var map: [Character: [Character]] = [:]
        for (truth, misreads) in confusion {
            for m in misreads where m.isNumber {
                map[m, default: []].append(truth)
            }
        }
        return map
    }()

    private static let substitutionCost = 1.0
    private static let deletionCost = 1.4
    private static let insertionCost = 1.6
    /// 最良解がこの倍率以内の別解を持つ場合は「曖昧」とみなして補正しない
    private static let ambiguityMargin = 1.35

    public struct Candidate {
        public let value: Int
        public let cost: Double
        public let kind: String
    }

    public struct Correction: Equatable {
        public let key: String
        public let from: Int
        public let to: Int
        public let kind: String
    }

    public struct Solution {
        public let corrections: [Correction]
        public let cost: Double
        public let ambiguous: Bool
    }

    public struct Term {
        public let key: String
        public let value: Int
        public let sign: Int
        public let correctable: Bool
        public let ocrConf: Double
        public let candidateValues: [Candidate]?

        public init(key: String, value: Int, sign: Int, correctable: Bool, ocrConf: Double,
                    candidateValues: [Candidate]? = nil) {
            self.key = key
            self.value = value
            self.sign = sign
            self.correctable = correctable
            self.ocrConf = ocrConf
            self.candidateValues = candidateValues
        }
    }

    /// 1文字だけ編集して得られる「本来の値」候補。
    public static func editCandidates(_ value: Int) -> [Candidate] {
        let digits = Array(String(abs(value)))
        var out: [Int: Candidate] = [:]
        func add(_ text: String, _ cost: Double, _ kind: String) {
            guard !text.isEmpty, text.allSatisfy(\.isNumber), let v = Int(text), v != abs(value) else { return }
            if let existing = out[v], existing.cost <= cost { return }
            out[v] = Candidate(value: v, cost: cost, kind: kind)
        }
        for i in digits.indices {
            for alt in reverse[digits[i]] ?? [] {
                var copy = digits
                copy[i] = alt
                add(String(copy), substitutionCost, "sub:\(digits[i])->\(alt)@\(i)")
            }
            if digits.count > 1 {
                var copy = digits
                copy.remove(at: i)
                add(String(copy), deletionCost, "del:\(digits[i])@\(i)")
            }
        }
        // OCRが数字を1つ読み落とした場合（先頭が落ちた／同じ数字の並びが潰れた）
        for d in 1...9 {
            add(String(d) + String(digits), insertionCost, "ins:\(d)@0")
        }
        for i in digits.indices {
            var copy = digits
            copy.insert(digits[i], at: i)
            add(String(copy), insertionCost, "dup:\(digits[i])@\(i)")
        }
        // 並びが実行ごとに変わると補正結果も変わるため、必ず同じ順序にそろえる
        return out.values.sorted { ($0.cost, $0.value) < ($1.cost, $1.value) }
    }

    /// 集計項目（複数行の合算）の補正候補。構成要素のどれか1つを1桁直した合計を返す。
    public static func aggregateCandidates(parts: [Int]) -> [Candidate] {
        let total = parts.reduce(0) { $0 + abs($1) }
        var out: [Int: Candidate] = [:]
        for (index, part) in parts.enumerated() {
            for candidate in editCandidates(abs(part)) {
                let value = total - abs(part) + candidate.value
                guard value >= 0 else { continue }
                if let existing = out[value], existing.cost <= candidate.cost { continue }
                out[value] = Candidate(value: value, cost: candidate.cost, kind: "\(candidate.kind)#\(index)")
            }
        }
        return out.values.sorted { ($0.cost, $0.value) < ($1.cost, $1.value) }
    }

    private struct State {
        var delta: Int
        var cost: Double
        var corrections: [Correction]
    }

    /// sum(sign * value) == 0 になるよう、各項の1桁補正の組み合わせを探索する。
    public static func solve(terms: [Term], maxCorrections: Int = 4) -> Solution? {
        let base = terms.reduce(0) { $0 + $1.sign * $1.value }
        if base == 0 { return Solution(corrections: [], cost: 0, ambiguous: false) }

        var options: [[(delta: Int, cost: Double, correction: Correction?)]] = []
        for term in terms {
            var list: [(delta: Int, cost: Double, correction: Correction?)] = [(0, 0, nil)]
            if term.correctable {
                let candidates = term.candidateValues ?? editCandidates(term.value)
                let confPenalty = 0.6 + 1.4 * min(1, max(0, term.ocrConf))
                for candidate in candidates {
                    list.append((
                        delta: term.sign * (candidate.value - term.value),
                        cost: candidate.cost * confPenalty,
                        correction: Correction(key: term.key, from: term.value, to: candidate.value, kind: candidate.kind)
                    ))
                }
            }
            options.append(list)
        }

        // 候補数が多い項を左右へ交互に振り分けて探索量を抑える
        let order = options.enumerated().sorted { $0.element.count > $1.element.count }
        var groups: [[Int]] = [[], []]
        var sizes = [1, 1]
        for (index, list) in order {
            let target = sizes[0] <= sizes[1] ? 0 : 1
            groups[target].append(index)
            sizes[target] *= max(1, list.count)
        }

        func enumerate(_ indexes: [Int]) -> [State] {
            var states = [State(delta: 0, cost: 0, corrections: [])]
            for i in indexes {
                var next: [State] = []
                next.reserveCapacity(states.count * options[i].count)
                for state in states {
                    for option in options[i] {
                        var corrections = state.corrections
                        if let correction = option.correction { corrections.append(correction) }
                        if corrections.count > maxCorrections { continue }
                        next.append(State(delta: state.delta + option.delta,
                                          cost: state.cost + option.cost,
                                          corrections: corrections))
                    }
                }
                states = next
            }
            return states
        }

        let left = enumerate(groups[0])
        let right = enumerate(groups[1])
        var rightByDelta: [Int: State] = [:]
        for state in right {
            if let existing = rightByDelta[state.delta], existing.cost <= state.cost { continue }
            rightByDelta[state.delta] = state
        }

        var best: (corrections: [Correction], cost: Double)?
        var runnerUp: (corrections: [Correction], cost: Double)?
        func sameFix(_ a: [Correction], _ b: [Correction]) -> Bool {
            a.count == b.count && zip(a, b).allSatisfy { $0.key == $1.key && $0.to == $1.to }
        }

        for state in left {
            let need = -(base + state.delta)
            guard let match = rightByDelta[need] else { continue }
            let corrections = state.corrections + match.corrections
            guard !corrections.isEmpty, corrections.count <= maxCorrections else { continue }
            let cost = state.cost + match.cost + Double(corrections.count) * 0.4
            if best == nil || cost < best!.cost {
                if let current = best, !sameFix(current.corrections, corrections) { runnerUp = current }
                best = (corrections, cost)
            } else if (runnerUp == nil || cost < runnerUp!.cost),
                      let current = best, !sameFix(current.corrections, corrections) {
                runnerUp = (corrections, cost)
            }
        }
        guard let best else { return nil }
        let ambiguous = runnerUp.map { $0.cost < best.cost * ambiguityMargin } ?? false
        return Solution(corrections: best.corrections, cost: best.cost, ambiguous: ambiguous)
    }
}
