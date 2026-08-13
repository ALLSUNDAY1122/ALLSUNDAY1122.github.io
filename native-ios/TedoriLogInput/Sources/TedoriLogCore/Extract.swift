import Foundation

/// 解析結果の状態。
/// この層は「候補」しか返さない。確定保存は SaveGuard を通したユーザー確認が必須。
public enum CandidateStatus: String, Codable {
    case confident        // 確定候補（検算の裏付けあり）
    case needsReview = "needs_review"  // 要確認
    case notFound = "not_found"        // 未検出
}

public struct Evidence: Codable, Equatable {
    public var value: Int
    public var label: String
    public var labelBox: BoundingBox
    public var amountBox: BoundingBox
    public var ocrConf: Double
    public var exactLabel: Bool
}

public struct BoundingBox: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public var page: Int
    public var text: String

    init(_ token: TextToken) {
        x = token.x
        y = token.y
        w = token.w
        h = token.h
        page = token.page
        text = token.text
    }
}

public struct Alternative: Codable, Equatable {
    public var value: Int
    public var label: String
    public var source: String
}

public struct ItemCandidate: Codable {
    public var key: ItemKey
    public var label: String
    public var value: Int?
    public var status: CandidateStatus
    public var confidence: Double
    public var reasons: [String]
    public var evidence: [Evidence]
    public var alternatives: [Alternative]
    public var derived: Bool
    public var corrected: Bool
    var minOcrConf: Double
}

public struct ReconcileCheck: Codable {
    public var id: String
    public var ok: Bool
    public var delta: Int?
    public var detail: String
}

public struct RepairLog: Codable {
    public var block: String
    public var target: String
    public var from: Int?
    public var to: Int?
    public var skippedReason: String?
}

public struct PayslipResult {
    public var ok: Bool
    public var error: String?
    public var message: String?
    public var route: String
    public var items: [ItemKey: ItemCandidate]
    public var grossTotal: Int?
    public var deductionTotal: Int?
    public var checks: [ReconcileCheck]
    public var repairs: [RepairLog]
    public var variant: String?
    public var disagreements: [String]
    public var tokenCount: Int
    public var rowCount: Int
    public var skewSlope: Double
    public var elapsedMs: Double

    public var confidentCount: Int { items.values.filter { $0.status == .confident }.count }
    public var needsReviewCount: Int { items.values.filter { $0.status == .needsReview }.count }
    public var notFoundCount: Int { items.values.filter { $0.status == .notFound }.count }
}

public enum PayslipExtractor {

    private static let confidentThreshold = 0.6
    private static let reviewThreshold = 0.28
    private static let lowOcrConf = 0.55
    /// OCR経路で「確定候補」にする最低の読み取り信頼度（合計が偶然合う誤読を確定にしないため）
    private static let ocrConfidentMin = 0.8

    private static let deductionKeys: [ItemKey] = [
        .healthInsurance, .pension, .employmentInsurance, .incomeTax, .residentTax,
    ]

    // MARK: - 内部構造

    private enum HitKind {
        case item(LabelMatch)
        case grossTotal
        case deductionTotal
        case otherDeduction
    }

    private struct Hit {
        let token: TextToken
        let row: Int
        let kind: HitKind
        var score: Double
        var itemKey: ItemKey? {
            if case let .item(match) = kind { return match.key }
            return nil
        }
        var isAggregate: Bool {
            if case let .item(match) = kind { return match.key.isAggregate }
            if case .otherDeduction = kind { return true }
            return false
        }
        var exactLabel: Bool {
            if case let .item(match) = kind { return match.exact && !match.loose }
            return true
        }
    }

    private struct AmountRef {
        let token: TextToken
        let parsed: Normalize.Amount
        let row: Int
    }

    private struct Pair {
        let hitIndex: Int
        let amountIndex: Int
        let relation: String
        let score: Double
    }

    private static func emptyItems() -> [ItemKey: ItemCandidate] {
        var items: [ItemKey: ItemCandidate] = [:]
        for key in ItemKey.allCases {
            items[key] = ItemCandidate(key: key, label: key.label, value: nil, status: .notFound,
                                       confidence: 0, reasons: [], evidence: [], alternatives: [],
                                       derived: false, corrected: false, minOcrConf: 1)
        }
        return items
    }

    // MARK: - 本体

    public static func extract(tokens rawTokens: [TextToken], route: String) -> PayslipResult {
        let started = Date()
        let layout = LayoutBuilder.build(rawTokens)
        guard !layout.tokens.isEmpty else {
            return PayslipResult(ok: false, error: "no_text_detected",
                                 message: "文字を検出できませんでした。撮り直すか、PDFを選び直してください。",
                                 route: route, items: emptyItems(), grossTotal: nil, deductionTotal: nil,
                                 checks: [], repairs: [], variant: nil, disagreements: [],
                                 tokenCount: 0, rowCount: 0, skewSlope: 0,
                                 elapsedMs: Date().timeIntervalSince(started) * 1000)
        }

        var hits: [Hit] = []
        var amounts: [AmountRef] = []
        for row in layout.rows {
            for token in row.tokens {
                let digits = token.text.filter(\.isNumber).count
                if let parsed = Normalize.parseAmount(token.text),
                   Double(digits) / Double(max(token.text.count, 1)) >= 0.5 {
                    amounts.append(AmountRef(token: token, parsed: parsed, row: row.index))
                    continue
                }
                if let total = Lexicon.matchTotal(token.text) {
                    hits.append(Hit(token: token, row: row.index,
                                    kind: total.kind == .gross ? .grossTotal : .deductionTotal,
                                    score: total.score))
                    continue
                }
                if let item = Lexicon.matchItem(token.text) {
                    hits.append(Hit(token: token, row: row.index, kind: .item(item), score: item.score))
                    continue
                }
                if Lexicon.isOtherDeduction(token.text) {
                    hits.append(Hit(token: token, row: row.index, kind: .otherDeduction, score: 0.8))
                }
            }
        }

        let columns = LayoutBuilder.detectAmountColumns(amounts.map { $0.token.right },
                                                        medianHeight: layout.medianHeight)
        var amountsByRow: [Int: [Int]] = [:]
        for (index, amount) in amounts.enumerated() { amountsByRow[amount.row, default: []].append(index) }
        var hitsByRow: [Int: [Int]] = [:]
        for (index, hit) in hits.enumerated() { hitsByRow[hit.row, default: []].append(index) }

        func columnBonus(_ amount: AmountRef) -> Double {
            guard !columns.isEmpty else { return 1 }
            let tolerance = max(6, layout.medianHeight * 1.2)
            return columns.contains { abs($0 - amount.token.right) <= tolerance } ? 1.06 : 0.94
        }
        func pairScore(_ hit: Hit, _ amount: AmountRef, _ positionWeight: Double) -> Double {
            let ocrConf = 0.6 + 0.4 * min(1, amount.token.conf)
            return hit.score * positionWeight * Normalize.amountPlausibility(amount.parsed.value)
                * amount.parsed.confidence * ocrConf * columnBonus(amount)
        }

        var pairs: [Pair] = []
        for (hitIndex, hit) in hits.enumerated() {
            let rowAmounts = (amountsByRow[hit.row] ?? []).sorted { amounts[$0].token.x < amounts[$1].token.x }
            let rowHits = (hitsByRow[hit.row] ?? []).sorted { hits[$0].token.x < hits[$1].token.x }

            let nextLabelX = rowHits.compactMap { index -> Double? in
                hits[index].token.x > hit.token.x + 1 ? hits[index].token.x : nil
            }.min() ?? .infinity
            let right = rowAmounts.filter {
                amounts[$0].token.x >= hit.token.right - 1 && amounts[$0].token.x < nextLabelX
            }
            let weights = [1.0, 0.5, 0.28]
            for (i, amountIndex) in right.prefix(3).enumerated() {
                pairs.append(Pair(hitIndex: hitIndex, amountIndex: amountIndex, relation: "same_row_right",
                                  score: pairScore(hit, amounts[amountIndex], weights[i])))
            }
            if right.isEmpty {
                // ラベルの左側で最も近い（xが最大の）金額。同点なら先に現れた方
                var leftIndex: Int?
                for candidate in rowAmounts where amounts[candidate].token.right <= hit.token.x + 1 {
                    if leftIndex == nil || amounts[candidate].token.x > amounts[leftIndex!].token.x {
                        leftIndex = candidate
                    }
                }
                if let leftIndex {
                    pairs.append(Pair(hitIndex: hitIndex, amountIndex: leftIndex, relation: "same_row_left",
                                      score: pairScore(hit, amounts[leftIndex], 0.45)))
                }
            }
            // 列ヘッダ型（ラベルの真下に金額）
            if rowHits.count >= 2, rowAmounts.count <= 1 {
                for distance in 1...2 {
                    let targetRow = hit.row + distance
                    let targetAmounts = (amountsByRow[targetRow] ?? [])
                        .sorted { amounts[$0].token.x < amounts[$1].token.x }
                    let targetHits = hitsByRow[targetRow] ?? []
                    guard targetAmounts.count >= 2, targetHits.count <= targetAmounts.count else { continue }
                    let matching = LayoutBuilder.monotonicMatch(
                        labelCenters: rowHits.map { hits[$0].token.centerX },
                        amountCenters: targetAmounts.map { amounts[$0].token.centerX })
                    guard let position = rowHits.firstIndex(of: hitIndex),
                          let amountPosition = matching[position] else { continue }
                    let amountIndex = targetAmounts[amountPosition]
                    guard abs(amounts[amountIndex].token.centerX - hit.token.centerX) <= layout.medianHeight * 12
                    else { continue }
                    pairs.append(Pair(hitIndex: hitIndex, amountIndex: amountIndex, relation: "column_below",
                                      score: pairScore(hit, amounts[amountIndex], distance == 1 ? 0.85 : 0.6)))
                    break
                }
            }
        }
        // 同点のときの順序も決めておく（不安定ソートで結果が揺れないように）
        pairs.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.hitIndex != $1.hitIndex { return $0.hitIndex < $1.hitIndex }
            return $0.amountIndex < $1.amountIndex
        }

        var usedAmounts = Set<Int>()
        var usedHits = Set<Int>()
        var assignedSingles = Set<String>()
        var accepted: [Pair] = []
        var rejected: [Pair] = []
        for pair in pairs {
            let hit = hits[pair.hitIndex]
            let singleKey: String? = {
                switch hit.kind {
                case .item(let match): return match.key.isAggregate ? nil : match.key.rawValue
                case .grossTotal: return "__gross"
                case .deductionTotal: return "__deduction"
                case .otherDeduction: return nil
                }
            }()
            if usedAmounts.contains(pair.amountIndex) || usedHits.contains(pair.hitIndex) {
                rejected.append(pair); continue
            }
            if let singleKey, assignedSingles.contains(singleKey) { rejected.append(pair); continue }
            if pair.score < reviewThreshold * 0.5 { rejected.append(pair); continue }
            usedAmounts.insert(pair.amountIndex)
            usedHits.insert(pair.hitIndex)
            if let singleKey { assignedSingles.insert(singleKey) }
            accepted.append(pair)
        }

        var items = emptyItems()
        var grossTotal: Int?
        var deductionTotal: Int?
        var otherDeductionSum = 0

        for pair in accepted {
            let hit = hits[pair.hitIndex]
            let amount = amounts[pair.amountIndex]
            switch hit.kind {
            case .grossTotal:
                if grossTotal == nil { grossTotal = abs(amount.parsed.value) }
            case .deductionTotal:
                if deductionTotal == nil { deductionTotal = abs(amount.parsed.value) }
            case .otherDeduction:
                otherDeductionSum += abs(amount.parsed.value)
            case .item(let match):
                var item = items[match.key]!
                let evidence = Evidence(value: abs(amount.parsed.value), label: hit.token.text,
                                        labelBox: BoundingBox(hit.token), amountBox: BoundingBox(amount.token),
                                        ocrConf: amount.token.conf, exactLabel: hit.exactLabel)
                if item.value == nil {
                    item.value = abs(amount.parsed.value)
                    item.confidence = pair.score
                    item.minOcrConf = amount.token.conf
                } else {
                    item.value! += abs(amount.parsed.value)
                    item.confidence = min(item.confidence, pair.score)
                    item.minOcrConf = min(item.minOcrConf, amount.token.conf)
                }
                item.evidence.append(evidence)
                item.status = statusFor(score: item.confidence, ocrConf: item.minOcrConf)
                items[match.key] = item
            }
        }

        for pair in rejected {
            guard let key = hits[pair.hitIndex].itemKey else { continue }
            var item = items[key]!
            guard item.alternatives.count < 3 else { continue }
            let value = abs(amounts[pair.amountIndex].parsed.value)
            guard !item.evidence.contains(where: { $0.value == value }) else { continue }
            item.alternatives.append(Alternative(value: value, label: hits[pair.hitIndex].token.text,
                                                 source: pair.relation))
            items[key] = item
        }

        var repairs: [RepairLog] = []
        var repairedBlocks = Set<String>()
        if route != "pdf_text" {
            repairWithTotals(items: &items, gross: &grossTotal, deduction: &deductionTotal,
                             otherDeductionSum: otherDeductionSum, repairs: &repairs,
                             repairedBlocks: &repairedBlocks)
        }

        let checks = reconcile(items: items, gross: grossTotal, deduction: deductionTotal,
                               otherDeductionSum: otherDeductionSum)
        applyChecks(items: &items, checks: checks, gross: grossTotal, deduction: deductionTotal,
                    repairedBlocks: repairedBlocks)

        // 検算の裏付けが取れた項目だけを確定候補にする
        var supported = Set<ItemKey>()
        for check in checks where check.ok {
            switch check.id {
            case "pay_total": supported.formUnion([.basicPay, .overtime, .otherAllowance])
            case "deduction_total": supported.formUnion(deductionKeys)
            case "net_pay": supported.insert(.netPay)
            default: break
            }
        }
        for key in ItemKey.allCases {
            var item = items[key]!
            if item.status == .confident && !supported.contains(key) {
                item.status = .needsReview
                item.reasons.append("合計検算の裏付けが無いため要確認")
            } else if item.status == .confident && route != "pdf_text" && item.minOcrConf < ocrConfidentMin {
                item.status = .needsReview
                item.reasons.append("読み取り信頼度が低いため要確認（合計が合っていても確定にしない）")
            } else if item.status == .confident && key.isAggregate &&
                        item.evidence.contains(where: { !$0.exactLabel }) {
                // 残業関連とその他手当は互いに振り替えても支給合計が変わらないため
                item.status = .needsReview
                item.reasons.append("項目名が完全一致でない手当を含むため要確認（振替の可能性）")
            }
            items[key] = item
        }

        return PayslipResult(ok: true, error: nil, message: nil, route: route, items: items,
                             grossTotal: grossTotal, deductionTotal: deductionTotal,
                             checks: checks, repairs: repairs, variant: nil, disagreements: [],
                             tokenCount: layout.tokens.count, rowCount: layout.rows.count,
                             skewSlope: layout.slope,
                             elapsedMs: Date().timeIntervalSince(started) * 1000)
    }

    private static func statusFor(score: Double, ocrConf: Double) -> CandidateStatus {
        if score >= confidentThreshold && ocrConf >= lowOcrConf { return .confident }
        if score >= reviewThreshold { return .needsReview }
        return .notFound
    }

    // MARK: - 検算

    private static func reconcile(items: [ItemKey: ItemCandidate], gross: Int?, deduction: Int?,
                                  otherDeductionSum: Int) -> [ReconcileCheck] {
        var checks: [ReconcileCheck] = []
        let basic = items[.basicPay]!.value
        let overtime = items[.overtime]!.value
        let other = items[.otherAllowance]!.value
        let deductionValues = deductionKeys.map { items[$0]!.value }
        let knownDeductionSum = deductionValues.allSatisfy { $0 != nil }
            ? deductionValues.compactMap { $0 }.reduce(0, +) : nil

        if let gross, let basic, let overtime, let other {
            let delta = gross - (basic + overtime + other)
            checks.append(ReconcileCheck(id: "pay_total", ok: delta == 0, delta: delta,
                                         detail: "支給合計 \(gross) と 基本給+残業+その他 \(basic + overtime + other) の差 \(delta)"))
        }
        if let deduction, let knownDeductionSum {
            let delta = deduction - (knownDeductionSum + otherDeductionSum)
            checks.append(ReconcileCheck(id: "deduction_total", ok: delta == 0, delta: delta,
                                         detail: "控除合計 \(deduction) と 控除項目合計 \(knownDeductionSum + otherDeductionSum) の差 \(delta)"))
        }
        if let gross, let deduction {
            let derived = gross - deduction
            let net = items[.netPay]!.value
            checks.append(ReconcileCheck(
                id: "net_pay", ok: net != nil && net == derived,
                delta: net.map { $0 - derived },
                detail: net == nil
                    ? "差引支給額は未検出。支給合計-控除合計=\(derived) を候補にできる"
                    : "差引支給額 \(net!) と 支給合計-控除合計 \(derived) の差 \(net! - derived)"))
        }
        return checks
    }

    private static func applyChecks(items: inout [ItemKey: ItemCandidate], checks: [ReconcileCheck],
                                    gross: Int?, deduction: Int?, repairedBlocks: Set<String>) {
        func upgrade(_ key: ItemKey, _ reason: String) {
            var item = items[key]!
            guard item.value != nil else { return }
            if item.corrected || item.derived {
                item.reasons.append(reason)
                items[key] = item
                return
            }
            if item.status == .needsReview && item.confidence >= reviewThreshold && item.minOcrConf >= lowOcrConf {
                item.status = .confident
            }
            item.reasons.append(reason)
            items[key] = item
        }
        func downgrade(_ key: ItemKey, _ reason: String) {
            var item = items[key]!
            guard item.value != nil else { return }
            if item.status == .confident { item.status = .needsReview }
            item.reasons.append(reason)
            items[key] = item
        }

        for check in checks {
            let keys: [ItemKey]
            switch check.id {
            case "pay_total": keys = [.basicPay, .overtime, .otherAllowance]
            case "deduction_total": keys = deductionKeys
            default: keys = [.netPay]
            }
            if repairedBlocks.contains(check.id) && check.ok {
                for key in keys {
                    var item = items[key]!
                    guard item.value != nil else { continue }
                    if item.status == .confident { item.status = .needsReview }
                    item.reasons.append("同ブロックで桁誤りの補正・判断保留があったため要確認")
                    items[key] = item
                }
                continue
            }
            switch check.id {
            case "pay_total", "deduction_total":
                if check.ok { keys.forEach { upgrade($0, check.id == "pay_total" ? "支給合計と一致" : "控除合計と一致") } }
                else { keys.forEach { downgrade($0, "\(check.id == "pay_total" ? "支給合計" : "控除合計")と不一致(差 \(check.delta ?? 0))") } }
            case "net_pay":
                var net = items[.netPay]!
                if check.ok {
                    upgrade(.netPay, "支給合計-控除合計と一致")
                } else if net.value == nil, let gross, let deduction, gross - deduction > 0 {
                    net.value = gross - deduction
                    net.status = .needsReview
                    net.confidence = 0.5
                    net.derived = true
                    net.reasons.append("支給合計-控除合計から算出した候補（要確認）")
                    items[.netPay] = net
                } else if net.value != nil {
                    downgrade(.netPay, "支給合計-控除合計と不一致(差 \(check.delta ?? 0))")
                }
            default: break
            }
        }

        // その他手当が見つからない場合、支給合計からの差分を要確認候補として提示する
        var other = items[.otherAllowance]!
        if other.value == nil, let gross,
           let basic = items[.basicPay]!.value, let overtime = items[.overtime]!.value {
            let derived = gross - basic - overtime
            if derived > 0 {
                other.value = derived
                other.status = .needsReview
                other.confidence = 0.45
                other.derived = true
                other.reasons.append("支給合計から基本給・残業を引いた差分（要確認）")
                items[.otherAllowance] = other
            }
        }
    }

    // MARK: - 桁誤り補正

    private static func repairWithTotals(items: inout [ItemKey: ItemCandidate], gross: inout Int?,
                                         deduction: inout Int?, otherDeductionSum: Int,
                                         repairs: inout [RepairLog], repairedBlocks: inout Set<String>) {
        var grossCorrected = false
        var deductionCorrected = false

        func term(_ key: ItemKey, sign: Int) -> DigitRepair.Term {
            let item = items[key]!
            let parts = item.evidence.map(\.value)
            return DigitRepair.Term(key: key.rawValue, value: item.value ?? 0, sign: sign,
                                    correctable: !item.derived, ocrConf: item.minOcrConf,
                                    candidateValues: parts.count > 1
                                        ? DigitRepair.aggregateCandidates(parts: parts) : nil)
        }

        func apply(_ solution: DigitRepair.Solution?, block: String) {
            guard let solution, !solution.corrections.isEmpty else { return }
            if solution.ambiguous {
                repairs.append(RepairLog(block: block, target: "-", from: nil, to: nil,
                                         skippedReason: "同等の補正候補が複数あるため補正しない"))
                repairedBlocks.insert(block)
                return
            }
            repairedBlocks.insert(block)
            for correction in solution.corrections {
                if correction.key == "__gross" {
                    repairs.append(RepairLog(block: block, target: "支給合計", from: gross, to: correction.to, skippedReason: nil))
                    gross = correction.to
                    grossCorrected = true
                } else if correction.key == "__deduction" {
                    repairs.append(RepairLog(block: block, target: "控除合計", from: deduction, to: correction.to, skippedReason: nil))
                    deduction = correction.to
                    deductionCorrected = true
                } else if let key = ItemKey(rawValue: correction.key) {
                    var item = items[key]!
                    guard item.value != nil else { continue }
                    item.alternatives.insert(Alternative(value: correction.from, label: "OCR読み取り値", source: "ocr_raw"), at: 0)
                    item.value = correction.to
                    item.corrected = true
                    item.status = .needsReview
                    item.reasons.append("合計との整合から桁誤りを補正（\(correction.from)→\(correction.to)）。要確認")
                    items[key] = item
                    repairs.append(RepairLog(block: block, target: key.label, from: correction.from,
                                             to: correction.to, skippedReason: nil))
                }
            }
        }

        // 1) まず合計同士で基準になる合計を確かめる
        if let g = gross, let d = deduction, items[.netPay]!.value != nil {
            let terms = [
                DigitRepair.Term(key: "__gross", value: g, sign: 1, correctable: true, ocrConf: 0.8),
                DigitRepair.Term(key: "__deduction", value: d, sign: -1, correctable: true, ocrConf: 0.8),
                term(.netPay, sign: -1),
            ]
            apply(DigitRepair.solve(terms: terms, maxCorrections: 2), block: "net_pay")
        }
        // 2) 確かめた支給合計を基準に支給側を検算
        if let g = gross, items[.basicPay]!.value != nil, items[.overtime]!.value != nil,
           items[.otherAllowance]!.value != nil {
            let terms = [
                term(.basicPay, sign: 1), term(.overtime, sign: 1), term(.otherAllowance, sign: 1),
                DigitRepair.Term(key: "__gross", value: g, sign: -1, correctable: !grossCorrected, ocrConf: 0.8),
            ]
            apply(DigitRepair.solve(terms: terms), block: "pay_total")
        }
        // 3) 控除側
        if let d = deduction, deductionKeys.allSatisfy({ items[$0]!.value != nil }) {
            var terms = deductionKeys.map { term($0, sign: 1) }
            terms.append(DigitRepair.Term(key: "__other_deduction", value: otherDeductionSum, sign: 1,
                                          correctable: false, ocrConf: 1))
            terms.append(DigitRepair.Term(key: "__deduction", value: d, sign: -1,
                                          correctable: !deductionCorrected, ocrConf: 0.8))
            apply(DigitRepair.solve(terms: terms), block: "deduction_total")
        }
    }

    // MARK: - 複数読み取りからの選択

    /// 解析結果の自己評価（正解を知らずに「筋の通り具合」を測る）。
    public static func selfAssessment(_ result: PayslipResult) -> Double {
        guard result.ok else { return -.infinity }
        let checksOk = result.checks.filter(\.ok).count
        return 3 * Double(checksOk) + Double(result.confidentCount)
            + 0.4 * Double(result.needsReviewCount) - 0.8 * Double(result.notFoundCount)
            - 0.5 * Double(result.repairs.count)
    }

    public struct Variant {
        public let name: String
        public let tokens: [TextToken]
        public init(name: String, tokens: [TextToken]) {
            self.name = name
            self.tokens = tokens
        }
    }

    /// 複数の読み取り結果から最も筋の通る結果を選び、食い違う項目は確定候補から外す。
    public static func extractBest(variants: [Variant], route: String) -> PayslipResult {
        guard !variants.isEmpty else { return extract(tokens: [], route: route) }
        var results: [(name: String, result: PayslipResult, score: Double)] = []
        for variant in variants {
            let result = extract(tokens: variant.tokens, route: route)
            results.append((variant.name, result, selfAssessment(result)))
        }
        // 同点のときは先に評価した方を採る（JS版と同じ順序。max(by:)は最後の最大値を返すため使わない）
        var best: (name: String, result: PayslipResult, score: Double)?
        for candidate in results where best == nil || candidate.score > best!.score {
            best = candidate
        }
        guard let best else { return extract(tokens: [], route: route) }
        var result = best.result
        result.variant = best.name

        for key in ItemKey.allCases {
            var item = result.items[key]!
            guard let value = item.value else { continue }
            for other in results where other.name != best.name {
                guard other.result.ok, let otherValue = other.result.items[key]?.value,
                      otherValue != value else { continue }
                if item.status == .confident { item.status = .needsReview }
                item.reasons.append("別条件の読み取りでは \(otherValue) と読めたため要確認")
                if !item.alternatives.contains(where: { $0.value == otherValue }) {
                    item.alternatives.insert(Alternative(value: otherValue, label: "別の読み取り(\(other.name))",
                                                         source: "variant"), at: 0)
                }
                result.disagreements.append(key.rawValue)
                break
            }
            result.items[key] = item
        }
        return result
    }
}
