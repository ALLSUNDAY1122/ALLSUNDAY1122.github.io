import Foundation
import LearningSprintCore

extension RigakuAppModel {
    func auditedQuestionCount(forRound round: String) -> Int {
        questions.filter { $0.examRound == round }.count
    }

    func auditedQuestionCount(forSubject subject: String) -> Int {
        questions.filter { $0.subject == subject }.count
    }

    func isMockReady(round: String, expectedQuestionCount: Int?) -> Bool {
        guard let expectedQuestionCount else { return false }
        return auditedQuestionCount(forRound: round) == expectedQuestionCount
    }

    func isSessionAvailable(_ kind: SessionKind) -> Bool {
        switch kind {
        case .mock(let round):
            let expected = RigakuAppConfiguration.examRounds
                .first { String($0.round) == round }?
                .officialQuestionCount
            return isMockReady(round: round, expectedQuestionCount: expected)
        case .subject(let subject):
            return auditedQuestionCount(forSubject: subject) > 0
        case .weak:
            return canStudy && weakCount > 0
        case .sprint:
            return canStudy
        }
    }
}
