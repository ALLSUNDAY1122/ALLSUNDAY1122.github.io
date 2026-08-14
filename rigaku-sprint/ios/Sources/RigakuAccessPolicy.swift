import LearningSprintCore

struct RigakuAccessPolicy {
    static let freeQuestionLimit = 60

    static let freeQuestionQuotas: [String: Int] = [
        "理学療法": 16,
        "臨床医学大要": 14,
        "生理学": 7,
        "解剖学": 6,
        "リハビリテーション医学": 5,
        "臨床心理学": 5,
        "運動学": 5,
        "病理学概論": 2,
    ]

    static func freeQuestionIDs(from questions: [LearningQuestion]) -> Set<String> {
        var result = Set<String>()

        for subject in RigakuAppConfiguration.generalSubjects {
            guard let quota = freeQuestionQuotas[subject], quota > 0 else { continue }

            let subjectQuestions = questions.filter { $0.subject == subject }
            var byRound: [String: [LearningQuestion]] = [:]
            for round in RigakuAppConfiguration.examRounds.map({ String($0.round) }) {
                byRound[round] = subjectQuestions
                    .filter { $0.examRound == round }
                    .sorted { $0.id < $1.id }
            }

            let roundOrder = RigakuAppConfiguration.examRounds.map { String($0.round) }
            var offsets = Dictionary(uniqueKeysWithValues: roundOrder.map { ($0, 0) })

            while result.filter({ id in subjectQuestions.contains(where: { $0.id == id }) }).count < quota {
                var addedInCycle = false
                for round in roundOrder {
                    guard result.filter({ id in subjectQuestions.contains(where: { $0.id == id }) }).count < quota else { break }
                    let offset = offsets[round, default: 0]
                    guard let candidates = byRound[round], offset < candidates.count else { continue }
                    result.insert(candidates[offset].id)
                    offsets[round] = offset + 1
                    addedInCycle = true
                }
                if !addedInCycle { break }
            }
        }

        return result
    }

    static func accessibleQuestions(
        from questions: [LearningQuestion],
        isPremium: Bool
    ) -> [LearningQuestion] {
        guard !isPremium else { return questions }
        let freeIDs = freeQuestionIDs(from: questions)
        return questions.filter { freeIDs.contains($0.id) }
    }

    static func canAccessMock(isPremium: Bool) -> Bool {
        isPremium
    }

    static func canAccessFullWeakReview(isPremium: Bool) -> Bool {
        isPremium
    }
}
