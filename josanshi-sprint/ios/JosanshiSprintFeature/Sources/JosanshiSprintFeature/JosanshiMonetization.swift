import Foundation

public enum JosanshiMonetizationConfiguration {
    public static let purchaseModel = "non_consumable"
    public static let freeQuestionCountPerSubject = 15
    public static let freeQuestionTarget = freeQuestionCountPerSubject * JosanshiExamConfiguration.subjects.count

    public static let freeFeatures = [
        "今日のスプリント",
        "1日の目標 4 / 8 / 16問",
        "基本の学習進捗",
        "試験日カウントダウン"
    ]

    public static let premiumFeatures = [
        "全330問",
        "4分野別演習",
        "苦手だけ復習",
        "独自模試3回（各110問）",
        "詳細な学習記録",
        "JSONバックアップ・復元"
    ]

    /// The free pool is derived from the audited production bank instead of a second content source.
    /// It uses the first 15 general questions per official subject in stable mock/session/slot order.
    /// Situation-setting questions remain Premium so linked scenarios are never partially exposed.
    public static func freeQuestionIDs(in questions: [JosanshiProductionQuestion]) -> Set<String> {
        var result = Set<String>()
        for subject in JosanshiExamConfiguration.subjects {
            let selected = questions
                .filter { $0.subject == subject && $0.questionType == "general" }
                .sorted(by: stableQuestionOrder)
                .prefix(freeQuestionCountPerSubject)
            result.formUnion(selected.map(\.id))
        }
        return result
    }

    private static func stableQuestionOrder(_ lhs: JosanshiProductionQuestion, _ rhs: JosanshiProductionQuestion) -> Bool {
        if lhs.mockRound != rhs.mockRound { return lhs.mockRound < rhs.mockRound }
        if lhs.session != rhs.session { return lhs.session < rhs.session }
        if lhs.slotNumber != rhs.slotNumber { return lhs.slotNumber < rhs.slotNumber }
        return lhs.id < rhs.id
    }
}
