import Foundation
import LearningSprintCore

public struct HokenshiExamBlueprint: Equatable, Sendable {
    public let referenceRound: Int
    public let morningQuestions: Int
    public let afternoonQuestions: Int
    public let generalQuestions: Int
    public let situationalQuestions: Int
    public let sourceStandard: String
    public let subjects: [String]

    public var totalQuestions: Int { morningQuestions + afternoonQuestions }
    public var situationalPoints: Int { situationalQuestions * 2 }

    public static let current = HokenshiExamBlueprint(
        referenceRound: 112,
        morningQuestions: 55,
        afternoonQuestions: 55,
        generalQuestions: 75,
        situationalQuestions: 35,
        sourceStandard: "保健師国家試験出題基準 令和5年版",
        subjects: [
            "公衆衛生看護学概論",
            "公衆衛生看護方法論I",
            "公衆衛生看護方法論II",
            "対象別公衆衛生看護活動論",
            "学校保健・産業保健",
            "健康危機管理",
            "公衆衛生看護管理論",
            "疫学",
            "保健統計",
            "保健医療福祉行政論"
        ]
    )
}

/// 2026-03-19に厚生労働省が公表した制度改善検討部会報告書を、
/// 第113回以降も見据えた作問・UI設計の追加正本として保持する。
/// 同報告書は令和5年版出題基準の見直しを行わず、現行出題数・試験時間を維持する方針を示している。
public enum HokenshiExamPolicy2026 {
    public static let evidenceDate = "2026-03-19"
    public static let standardRevisionRequired = false
    public static let keepCurrentQuestionCount = true
    public static let keepCurrentExamTime = true
    public static let latestLawAndStatisticsShouldBeTested = true
    public static let visualMaterialShouldContinue = true
    public static let communityDiagnosisShouldUseData = true

    /// 状況設定問題は原則3連問。保健師は出題数の都合で2連問も許容される。
    /// 35問を模試で再現する場合は11組×3問 + 1組×2問とする。
    public static let situationalScenarioGroupSizes = Array(repeating: 3, count: 11) + [2]

    /// 報告書に沿った中心Taxonomy。
    public static let generalTaxonomies = ["I", "I-prime", "II"]
    public static let situationalTaxonomies = ["II", "III"]

    public static var plannedSituationalQuestionCount: Int {
        situationalScenarioGroupSizes.reduce(0, +)
    }
}

public enum HokenshiQuestionOrigin: String, Codable, Sendable {
    case originalFromPrimarySource
    case officialMHLWUnmodified
    case officialMHLWAdapted
    case thirdPartyMaterial
}

public enum HokenshiRightsDecision: Equatable, Sendable {
    case allowedAfterStandardAudit
    case requiresPerItemAudit
    case blocked(reason: String)
}

public enum HokenshiRightsPolicy {
    public static func decision(
        for origin: HokenshiQuestionOrigin,
        thirdPartyRightsCleared: Bool = false
    ) -> HokenshiRightsDecision {
        switch origin {
        case .originalFromPrimarySource:
            return .allowedAfterStandardAudit
        case .officialMHLWUnmodified, .officialMHLWAdapted:
            return .requiresPerItemAudit
        case .thirdPartyMaterial:
            return thirdPartyRightsCleared
                ? .requiresPerItemAudit
                : .blocked(reason: "第三者権利の処理が確認できない素材は収録しない")
        }
    }
}

public enum HokenshiSprintConfiguration {
    public static let appName = "保健師国家試験｜学びスプリント"
    public static let standardSprintCount = 8
    public static let selectableSprintCounts = [4, 8, 16]
    public static let plannedMockExamCount = 3
    public static let questionsPerMockExam = HokenshiExamBlueprint.current.totalQuestions
    public static let plannedIndependentQuestionCount = plannedMockExamCount * questionsPerMockExam
    public static let contentVersion = "hokenshi-content-plan-2026-08-13"

    /// 初期独自模試は、出題基準10分類を欠落なく反復できるよう各分類11問ずつ配置する。
    /// これは厚労省の科目別公式出題割合を主張する値ではなく、学習アプリ内の均等型設計である。
    public static let plannedQuestionsPerSubjectPerMock = 11

    public static let supportedAnswerTypes: [LearningAnswerType] = [
        .singleChoice,
        .multiChoice,
        .numeric
    ]
}
