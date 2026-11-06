import Foundation
import LearningSprintCore

struct RigakuExamConfigDocument: Decodable {
    struct RoundConfig: Decodable {
        struct OfficialScoring: Decodable {
            let generalMax: Int
            let practicalMax: Int
            let totalMax: Int
            let passTotal: Int
            let passPractical: Int
        }
        let total: Int
        let officialScoring: OfficialScoring
    }

    let roundConfig: [String: RoundConfig]
}

struct RigakuScoringAdjustmentDocument: Decodable {
    struct Adjustment: Decodable {
        let id: String
        let treatment: String
    }
    let adjustments: [Adjustment]
}

struct RigakuMockScore: Equatable {
    let round: String
    let generalPoints: Int
    let practicalPoints: Int
    let generalMax: Int
    let practicalMax: Int
    let passTotal: Int
    let passPractical: Int

    var totalPoints: Int { generalPoints + practicalPoints }
    var totalMax: Int { generalMax + practicalMax }
    var passed: Bool {
        totalPoints >= passTotal && practicalPoints >= passPractical
    }
}

struct RigakuExamScoringRepository {
    let examConfig: RigakuExamConfigDocument
    let excludedQuestionIDs: Set<String>

    static func loadBundled(bundle: Bundle = .main) throws -> RigakuExamScoringRepository {
        guard let configURL = bundle.url(forResource: "exam-config", withExtension: "json"),
              let adjustmentURL = bundle.url(forResource: "scoring-adjustments", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "模試採点正本が見つかりません。"
            ])
        }
        let decoder = JSONDecoder()
        let config = try decoder.decode(
            RigakuExamConfigDocument.self,
            from: Data(contentsOf: configURL)
        )
        let adjustments = try decoder.decode(
            RigakuScoringAdjustmentDocument.self,
            from: Data(contentsOf: adjustmentURL)
        )
        let excluded = Set(
            adjustments.adjustments
                .filter { $0.treatment == "excluded" }
                .map(\.id)
        )
        return RigakuExamScoringRepository(examConfig: config, excludedQuestionIDs: excluded)
    }

    func score(
        round: String,
        questions: [LearningQuestion],
        correctness: [String: Bool]
    ) -> RigakuMockScore? {
        guard let config = examConfig.roundConfig[round] else { return nil }
        var generalPoints = 0
        var practicalPoints = 0

        for question in questions {
            guard correctness[question.id] == true else { continue }
            guard !excludedQuestionIDs.contains(question.id) else { continue }
            guard let position = Self.position(for: question.id) else { continue }
            if position <= 20 {
                practicalPoints += 3
            } else {
                generalPoints += 1
            }
        }

        return RigakuMockScore(
            round: round,
            generalPoints: generalPoints,
            practicalPoints: practicalPoints,
            generalMax: config.officialScoring.generalMax,
            practicalMax: config.officialScoring.practicalMax,
            passTotal: config.officialScoring.passTotal,
            passPractical: config.officialScoring.passPractical
        )
    }

    func points(for questionID: String) -> Int {
        guard !excludedQuestionIDs.contains(questionID),
              let position = Self.position(for: questionID) else { return 0 }
        return position <= 20 ? 3 : 1
    }

    private static func position(for questionID: String) -> Int? {
        let components = questionID.split(separator: "-")
        guard components.count >= 4 else { return nil }
        return Int(components[3])
    }
}
