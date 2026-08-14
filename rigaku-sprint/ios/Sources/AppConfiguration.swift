import Foundation

enum RigakuAppConfiguration {
    static let qualificationName = "理学療法士国家試験"
    static let seriesName = "学びスプリント"
    static let contentVersion = "0.1.0-dev"
    static let defaultDailyTarget = 8
    static let allowedDailyTargets = [4, 8, 16]

    struct ExamRound: Identifiable, Equatable {
        let round: Int
        let officialQuestionCount: Int?
        let publicationStatus: PublicationStatus

        var id: Int { round }
    }

    enum PublicationStatus: String, Equatable {
        case verifiedPublished
        case pendingPdfAudit
        case problemTextNotConfirmed
    }

    static let examRounds: [ExamRound] = [
        .init(round: 60, officialQuestionCount: 200, publicationStatus: .verifiedPublished),
        .init(round: 59, officialQuestionCount: 200, publicationStatus: .verifiedPublished),
        .init(round: 58, officialQuestionCount: 200, publicationStatus: .verifiedPublished)
    ]

    static let totalOfficialQuestionSlots = examRounds.compactMap(\.officialQuestionCount).reduce(0, +)

    static let generalSubjects = [
        "解剖学",
        "生理学",
        "運動学",
        "病理学概論",
        "臨床心理学",
        "リハビリテーション医学",
        "臨床医学大要",
        "理学療法"
    ]

    static let practicalSubjects = [
        "運動学",
        "臨床心理学",
        "リハビリテーション医学",
        "臨床医学大要",
        "理学療法"
    ]

    static var runtimeBundleIdentifier: String? {
        normalizedExternalIdentifier(Bundle.main.bundleIdentifier)
    }

    static var runtimePremiumProductID: String? {
        normalizedExternalIdentifier(
            Bundle.main.object(forInfoDictionaryKey: "RigakuPremiumProductID") as? String
        )
    }

    static func normalizedExternalIdentifier(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard !value.contains("$("), !value.contains("${") else { return nil }
        return value
    }
}
