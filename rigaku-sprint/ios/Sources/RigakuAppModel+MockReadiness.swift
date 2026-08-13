import Foundation

extension RigakuAppModel {
    func auditedQuestionCount(forRound round: String) -> Int {
        questions.filter { $0.examRound == round }.count
    }

    func isMockReady(round: String, expectedQuestionCount: Int?) -> Bool {
        guard let expectedQuestionCount else { return false }
        return auditedQuestionCount(forRound: round) == expectedQuestionCount
    }
}
