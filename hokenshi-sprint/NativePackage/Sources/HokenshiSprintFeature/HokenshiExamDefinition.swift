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
    public static let contentVersion = "hokenshi-foundation-2026-08-12"

    public static let supportedAnswerTypes: [LearningAnswerType] = [
        .singleChoice,
        .multiChoice,
        .numeric
    ]
}
