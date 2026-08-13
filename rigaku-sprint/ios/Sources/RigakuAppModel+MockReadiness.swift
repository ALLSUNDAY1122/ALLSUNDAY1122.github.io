import Foundation
import LearningSprintCore

enum RigakuRouteGate {
    static func isComplete(audited: Int, expected: Int?) -> Bool {
        guard let expected, expected > 0 else { return false }
        return audited == expected
    }
}

extension RigakuAppModel {
    func auditedQuestionCount(forRound round: String) -> Int {
        questions.filter { $0.examRound == round }.count
    }

    func auditedQuestionCount(forSubject subject: String) -> Int {
        questions.filter { $0.subject == subject }.count
    }

    func isMockReady(round: String, expectedQuestionCount: Int?) -> Bool {
        RigakuRouteGate.isComplete(
            audited: auditedQuestionCount(forRound: round),
            expected: expectedQuestionCount
        )
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
