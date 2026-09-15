import Foundation

/// 9項目の判定辞書。
/// 語を列挙するのではなく「語の作られ方」で判定する（未知の明細の言い回しに追従するため）。
/// canonical は OCR で字が化けたときのあいまい一致用。
public enum ItemKey: String, CaseIterable, Codable {
    case basicPay = "basic_pay"
    case overtime
    case otherAllowance = "other_allowance"
    case healthInsurance = "health_insurance"
    case pension
    case employmentInsurance = "employment_insurance"
    case incomeTax = "income_tax"
    case residentTax = "resident_tax"
    case netPay = "net_pay"

    public var label: String {
        switch self {
        case .basicPay: return "基本給"
        case .overtime: return "残業関連"
        case .otherAllowance: return "その他手当"
        case .healthInsurance: return "健康保険"
        case .pension: return "厚生年金"
        case .employmentInsurance: return "雇用保険"
        case .incomeTax: return "所得税"
        case .residentTax: return "住民税"
        case .netPay: return "差引支給額"
        }
    }

    /// 複数行を合算する項目か。
    public var isAggregate: Bool { self == .overtime || self == .otherAllowance }
}

public enum ItemGroup { case pay, deduct, net }

struct LexiconEntry {
    let key: ItemKey
    let group: ItemGroup
    let patterns: [NSRegularExpression]
    let canonical: [String]
    let deny: [NSRegularExpression]
    var loosePattern: NSRegularExpression?
}

public struct LabelMatch {
    public let key: ItemKey
    public let score: Double
    public let matched: String
    public let group: ItemGroup
    public let exact: Bool
    public let loose: Bool
    var length: Int
}

public struct TotalMatch {
    public enum Kind: String { case gross, deduction }
    public let kind: Kind
    public let score: Double
}

public enum Lexicon {

    private static func re(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    // 勤怠欄など「金額ではない行」を拾わないための共通除外
    private static let timeLike = ["時間$", "時間数", "日数$", "回数$", "単価$", "率$"]

    private static let entries: [LexiconEntry] = [
        LexiconEntry(
            key: .basicPay, group: .pay,
            patterns: ["基本給", "^本給$", "本俸", "月例給", "基準内(給与|賃金|給)", "^基準給$", "^標準給与$"].map(re),
            canonical: ["基本給", "基本給額", "本給", "本俸", "月例給", "基準内賃金", "基準内給与", "基準給"],
            deny: (["控除"] + timeLike).map(re), loosePattern: nil),
        LexiconEntry(
            key: .overtime, group: .pay,
            patterns: ["時間外", "残業", "超勤", "超過勤務", "所定外", "法定外", "深夜", "休日", "割増"].map(re),
            canonical: ["時間外手当", "残業手当", "時間外勤務手当", "超過勤務手当", "深夜手当", "休日出勤手当", "残業代"],
            deny: timeLike.map(re), loosePattern: nil),
        LexiconEntry(
            key: .otherAllowance, group: .pay,
            patterns: [
                "通勤(手当|費)", "交通費", "住宅(手当|補助)", "家族手当", "扶養手当", "役職手当", "職務手当",
                "資格手当", "技能手当", "皆勤手当", "精勤手当", "食事(手当|補助)", "在宅(勤務)?手当",
                "地域手当", "調整手当", "現場手当", "営業手当", "単身赴任手当", "特殊(作業)?手当", "諸手当",
                "その他(手当|支給)",
            ].map(re),
            canonical: ["通勤手当", "住宅手当", "家族手当", "役職手当", "資格手当", "皆勤手当", "職務手当"],
            deny: (["残業", "時間外", "深夜", "休日", "超勤", "所定外", "割増"] + timeLike).map(re),
            loosePattern: re("(手当|手富|季当)$")),
        LexiconEntry(
            key: .healthInsurance, group: .deduct,
            patterns: ["健康保険", "^健保"].map(re),
            canonical: ["健康保険料", "健康保険", "健保料", "健保"],
            deny: (["介護", "基金"] + timeLike).map(re), loosePattern: nil),
        LexiconEntry(
            key: .pension, group: .deduct,
            patterns: ["厚生年金", "^厚年"].map(re),
            canonical: ["厚生年金保険料", "厚生年金", "厚年保険料", "厚年"],
            deny: (["国民年金", "基金"] + timeLike).map(re), loosePattern: nil),
        LexiconEntry(
            key: .employmentInsurance, group: .deduct,
            patterns: ["雇用保険", "^雇保"].map(re),
            canonical: ["雇用保険料", "雇用保険", "雇保"],
            deny: timeLike.map(re), loosePattern: nil),
        LexiconEntry(
            key: .incomeTax, group: .deduct,
            patterns: ["所得税", "源泉"].map(re),
            canonical: ["所得税", "源泉所得税", "源泉税", "所得税額"],
            deny: (["住民", "市県民", "市町村", "調整$", "課税対象"] + timeLike).map(re), loosePattern: nil),
        LexiconEntry(
            key: .residentTax, group: .deduct,
            patterns: ["住民税", "市県民税", "市民税", "県民税", "市町村民税", "地方税", "特別徴収"].map(re),
            canonical: ["住民税", "市県民税", "市民税", "地方税", "特別徴収住民税"],
            deny: timeLike.map(re), loosePattern: nil),
        LexiconEntry(
            key: .netPay, group: .net,
            patterns: ["差引(支給|支払|合計|額)", "手取", "振込(額|金額)", "^支払額$", "^支給額$"].map(re),
            canonical: ["差引支給額", "差引支払額", "差引支給", "手取額", "振込額", "銀行振込額", "差引合計"],
            deny: (["総支給", "支給合計", "支給額合計", "支給額計", "課税", "累計"] + timeLike).map(re),
            loosePattern: nil),
    ]

    private static let grossTotal = (
        patterns: ["総支給", "支給(合計|額計|計|総額)", "^合計支給額$"].map(re),
        canonical: ["総支給額", "支給合計", "支給額計", "支給計"],
        deny: (["差引", "控除"] + timeLike).map(re)
    )
    private static let deductionTotal = (
        patterns: ["控除(合計|額計|計|総額)", "総控除"].map(re),
        canonical: ["控除合計", "控除額計", "控除計", "総控除額"],
        deny: (["支給"] + timeLike).map(re)
    )

    private static let otherDeductionPatterns = [
        "介護保険", "組合費", "財形", "社宅", "生命保険", "互助会", "親睦会", "共済", "積立",
        "貸付", "前払", "欠勤控除", "遅刻早退",
    ].map(re)

    private static func denied(_ text: String, _ deny: [NSRegularExpression]) -> Bool {
        deny.contains { Normalize.matches($0, text) }
    }

    private static func patternScore(_ text: String, _ patterns: [NSRegularExpression]) -> (score: Double, matched: String)? {
        var best: (score: Double, matched: String)?
        for pattern in patterns {
            guard let matched = Normalize.firstMatchText(pattern, text) else { continue }
            let coverage = Double(matched.count) / Double(max(text.count, 1))
            let score = 0.9 + 0.1 * coverage
            if best == nil || score > best!.score { best = (score, matched) }
        }
        return best
    }

    private static func fuzzyScore(_ text: String, _ canonical: [String]) -> (score: Double, matched: String)? {
        var best: (score: Double, matched: String)?
        for variant in canonical {
            let s = Normalize.fuzzyContains(text, Normalize.normalizeLabel(variant))
            if s == 0 || s == 1 { continue }
            let score = s * 0.9
            if best == nil || score > best!.score { best = (score, variant) }
        }
        return best
    }

    /// ラベル文字列から該当項目を判定する。
    public static func matchItem(_ rawText: String) -> LabelMatch? {
        let text = Normalize.normalizeLabel(rawText)
        guard !text.isEmpty, text.count <= 24 else { return nil }

        var best: LabelMatch?
        for entry in entries {
            if denied(text, entry.deny) { continue }
            guard let hit = patternScore(text, entry.patterns) else { continue }
            let candidate = LabelMatch(key: entry.key, score: hit.score, matched: hit.matched,
                                       group: entry.group, exact: true, loose: false, length: hit.matched.count)
            if best == nil || candidate.score > best!.score ||
                (candidate.score == best!.score && candidate.length > best!.length) {
                best = candidate
            }
        }
        if let best { return best }

        for entry in entries {
            if denied(text, entry.deny) { continue }
            guard let hit = fuzzyScore(text, entry.canonical) else { continue }
            let candidate = LabelMatch(key: entry.key, score: hit.score, matched: hit.matched,
                                       group: entry.group, exact: false, loose: false, length: hit.matched.count)
            if best == nil || candidate.score > best!.score { best = candidate }
        }
        if let best { return best }

        if let other = entries.first(where: { $0.key == .otherAllowance }),
           let loose = other.loosePattern,
           Normalize.matches(loose, text), !denied(text, other.deny) {
            return LabelMatch(key: .otherAllowance, score: 0.55, matched: text,
                              group: .pay, exact: false, loose: true, length: text.count)
        }
        return nil
    }

    /// 合計行（支給合計 / 控除合計）の判定。
    public static func matchTotal(_ rawText: String) -> TotalMatch? {
        let text = Normalize.normalizeLabel(rawText)
        guard !text.isEmpty else { return nil }
        var best: TotalMatch?
        for (kind, spec) in [(TotalMatch.Kind.gross, grossTotal), (TotalMatch.Kind.deduction, deductionTotal)] {
            if denied(text, spec.deny) { continue }
            let hit = patternScore(text, spec.patterns) ?? fuzzyScore(text, spec.canonical)
            guard let hit else { continue }
            if best == nil || hit.score > best!.score { best = TotalMatch(kind: kind, score: hit.score) }
        }
        return best
    }

    /// 9項目外の控除項目か。
    public static func isOtherDeduction(_ rawText: String) -> Bool {
        let text = Normalize.normalizeLabel(rawText)
        guard !text.isEmpty else { return false }
        return otherDeductionPatterns.contains { Normalize.matches($0, text) }
    }
}
