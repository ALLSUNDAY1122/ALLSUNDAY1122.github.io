import Foundation

public struct JosanshiProductionIdentifiers: Equatable, Sendable {
    public let bundleID: String?
    public let appStoreConnectAppID: String?
    public let productID: String?

    public init(
        bundleID: String? = nil,
        appStoreConnectAppID: String? = nil,
        productID: String? = nil
    ) {
        self.bundleID = bundleID
        self.appStoreConnectAppID = appStoreConnectAppID
        self.productID = productID
    }

    public var isStoreKitReady: Bool {
        guard let productID else { return false }
        return !productID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isReleaseIdentityReady: Bool {
        [bundleID, appStoreConnectAppID].allSatisfy {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

public enum JosanshiExamConfiguration {
    public static let qualificationName = "助産師国家試験"
    public static let seriesName = "学びスプリント"
    public static let developmentNumber = 14

    public static let standardSprintCount = 8
    public static let selectableDailyTargets = [4, 8, 16]

    /// Confirmed from the official 109th morning and afternoon booklets.
    public static let latestConfirmedExamRound = 109
    public static let morningQuestionCount = 55
    public static let afternoonQuestionCount = 55
    public static let latestConfirmedQuestionCount = morningQuestionCount + afternoonQuestionCount
    public static let generalQuestionCountPerMock = 75
    public static let situationQuestionCountPerMock = 35
    public static let scenarioCaseCountPerMock = 12

    public static let originalMockSetCount = 3
    public static let originalProductionQuestionTarget = latestConfirmedQuestionCount * originalMockSetCount
    public static let originalGeneralQuestionTarget = generalQuestionCountPerMock * originalMockSetCount
    public static let originalSituationQuestionTarget = situationQuestionCountPerMock * originalMockSetCount
    public static let originalScenarioCaseTarget = scenarioCaseCountPerMock * originalMockSetCount

    /// Official examination subjects under the current rules.
    public static let subjects = [
        "基礎助産学",
        "助産診断・技術学",
        "地域母子保健",
        "助産管理"
    ]

    /// Current scope baseline confirmed against the 2026 MHLW review.
    public static let examScopeBaseline = "保健師助産師看護師国家試験出題基準 令和5年版"
    public static let sourceCheckedAt = "2026-08-12"

    /// Production identifiers are deliberately unset until a canonical value is provided.
    public static let productionIdentifiers = JosanshiProductionIdentifiers()

    /// Product-design allocation only. It is not represented as an official fixed MHLW subject quota.
    public static let subjectQuotaStatus = "独自カバレッジ設計・公式固定配分とは扱わない"
}
