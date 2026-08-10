import Foundation

enum LearningLogic {
    static func isCorrect(question: Question, choice: Int) -> Bool {
        question.isAllCorrect || question.officialAnswerNo == choice
    }

    static func recordAnswer(state: inout LearningState, question: Question, choice: Int, dayKey: String) -> Bool {
        let correct = isCorrect(question: question, choice: choice)
        var stat = state.attempts[question.id] ?? AttemptStat()
        stat.answered += 1
        if correct {
            stat.correct += 1
            stat.correctStreak += 1
            if stat.isWeak && stat.correctStreak >= 3 { stat.isWeak = false }
        } else {
            stat.correctStreak = 0
            stat.isWeak = true
        }
        state.attempts[question.id] = stat

        var day = state.days[dayKey] ?? DayStat()
        day.answered += 1
        if correct { day.correct += 1 }
        state.days[dayKey] = day
        return correct
    }

    static func selectQuestions(descriptor: SessionDescriptor, all: [Question], state: LearningState, dailyLimit: Int) -> [Question] {
        switch descriptor.kind {
        case .daily:
            return all.sorted { lhs, rhs in
                let la = state.attempts[lhs.id] ?? AttemptStat()
                let ra = state.attempts[rhs.id] ?? AttemptStat()
                if la.isWeak != ra.isWeak { return la.isWeak && !ra.isWeak }
                if la.answered != ra.answered { return la.answered < ra.answered }
                return lhs.id < rhs.id
            }.prefix(max(1, dailyLimit)).map { $0 }
        case .weak:
            return all.filter { state.attempts[$0.id]?.isWeak == true }
                .sorted { lhs, rhs in
                    let la = state.attempts[lhs.id] ?? AttemptStat()
                    let ra = state.attempts[rhs.id] ?? AttemptStat()
                    if la.correctStreak != ra.correctStreak { return la.correctStreak < ra.correctStreak }
                    return lhs.id < rhs.id
                }
        case .subject:
            return all.filter { $0.sourceYear == descriptor.year && $0.subject == descriptor.subject }
                .sorted { $0.sourceQuestionNo < $1.sourceQuestionNo }
        case .mock:
            return all.filter { $0.sourceYear == descriptor.year && $0.session == descriptor.session }
                .sorted { $0.sourceQuestionNo < $1.sourceQuestionNo }
        }
    }

    static func completeSession(state: inout LearningState, descriptor: SessionDescriptor) {
        state.completionCounts[descriptor.completionKey, default: 0] += 1
        state.resume = nil
    }

    static func validateResume(_ snapshot: SessionSnapshot?, questionsByID: [String: Question]) -> SessionSnapshot? {
        guard let snapshot,
              snapshot.index >= 0,
              snapshot.index < snapshot.questionIDs.count,
              snapshot.questionIDs.allSatisfy({ questionsByID[$0] != nil }) else { return nil }
        return snapshot
    }

    static func exportJSON(_ state: LearningState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(state)
    }

    static func importJSON(_ data: Data) throws -> LearningState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(LearningState.self, from: data)
        guard state.version <= LearningState.currentVersion else {
            throw NSError(domain: "ShoshiBackup", code: 1, userInfo: [NSLocalizedDescriptionKey: "このバックアップは新しいバージョンで作成されています。"])
        }
        return state
    }
}
