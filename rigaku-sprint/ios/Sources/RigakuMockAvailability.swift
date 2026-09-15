import Foundation
import LearningSprintCore

extension RigakuAppModel {
    static let expectedQuestionsPerMockRound = 200

    func loadedMockQuestionCount(round: String) -> Int {
        questions.filter { $0.examRound == round }.count
    }

    func completeMockQuestions(round: String) -> [LearningQuestion] {
        let candidates = questions(for: .mock(round))
        guard candidates.count == Self.expectedQuestionsPerMockRound else { return [] }
        return candidates
    }

    func isMockAvailable(round: String) -> Bool {
        completeMockQuestions(round: round).count == Self.expectedQuestionsPerMockRound
    }
}
