import Foundation

public enum LearningEngineError: Error, Equatable {
    case invalidQuestion(String)
    case missingAnswer
    case unsupportedAnswer
}

public enum LearningEngine {
    public static func evaluate(_ question: LearningQuestion, answer: AnswerPayload) throws -> AnswerEvaluation {
        if answer.isUnknown {
            return AnswerEvaluation(isCorrect: false, isUnknown: true, message: "わからない")
        }

        let correct: Bool
        switch question.answerType {
        case .singleChoice:
            guard answer.selectedIndices.count == 1 else {
                throw LearningEngineError.missingAnswer
            }
            let accepted = normalizedAcceptedIndexSets(for: question)
            guard !accepted.isEmpty, accepted.allSatisfy({ $0.count == 1 }) else {
                throw LearningEngineError.invalidQuestion(question.id)
            }
            correct = accepted.contains(Set(answer.selectedIndices))

        case .multiChoice:
            guard !answer.selectedIndices.isEmpty else {
                throw LearningEngineError.missingAnswer
            }
            let accepted = normalizedAcceptedIndexSets(for: question)
            guard !accepted.isEmpty else {
                throw LearningEngineError.invalidQuestion(question.id)
            }
            correct = accepted.contains(Set(answer.selectedIndices))

        case .numeric:
            guard let expected = question.correctNumber else {
                throw LearningEngineError.invalidQuestion(question.id)
            }
            guard let actual = answer.numberValue else {
                throw LearningEngineError.missingAnswer
            }
            let range = max(0, question.acceptedRange ?? 0)
            correct = abs(actual - expected) <= range

        case .blankSelect:
            guard !question.blanks.isEmpty else {
                throw LearningEngineError.invalidQuestion(question.id)
            }
            guard question.blanks.allSatisfy({ answer.blankValues[$0.key] != nil }) else {
                throw LearningEngineError.missingAnswer
            }
            correct = question.blanks.allSatisfy { field in
                answer.blankValues[field.key] == field.correctValue
            }

        case .declaration:
            guard !question.declarationFields.isEmpty else {
                throw LearningEngineError.invalidQuestion(question.id)
            }
            guard question.declarationFields.allSatisfy({ answer.declarationValues[$0.key] != nil }) else {
                throw LearningEngineError.missingAnswer
            }
            correct = question.declarationFields.allSatisfy { field in
                let actual = normalized(answer.declarationValues[field.key])
                let accepted = [field.correctValue] + field.aliases
                return accepted.map(normalized).contains(actual)
            }
        }

        return AnswerEvaluation(
            isCorrect: correct,
            isUnknown: false,
            message: correct ? "正解" : "不正解"
        )
    }

    public static func record(
        question: LearningQuestion,
        evaluation: AnswerEvaluation,
        state: inout LearningState,
        at date: Date = Date()
    ) {
        state.attempts.append(
            LearningAttempt(
                questionID: question.id,
                answeredAt: date,
                isCorrect: evaluation.isCorrect,
                isUnknown: evaluation.isUnknown,
                subject: question.subject,
                topic: question.topic
            )
        )

        if evaluation.isCorrect {
            guard var weak = state.weakQuestions[question.id] else { return }
            weak.consecutiveCorrect += 1
            weak.lastAnsweredAt = date
            if weak.consecutiveCorrect >= 3 {
                state.weakQuestions.removeValue(forKey: question.id)
            } else {
                state.weakQuestions[question.id] = weak
            }
        } else {
            state.weakQuestions[question.id] = WeakQuestionState(
                consecutiveCorrect: 0,
                lastAnsweredAt: date
            )
        }
    }

    public static func selectSprint(
        from questions: [LearningQuestion],
        target: Int,
        isPremium: Bool,
        seed: UInt64? = nil
    ) -> [LearningQuestion] {
        let target = LearningState.validTarget(target) ? target : 8
        let available = questions.filter { isPremium || !$0.premium }
        if available.count <= target { return available }
        if let seed {
            return Array(SeededShuffle.shuffle(available, seed: seed).prefix(target))
        }
        return Array(available.shuffled().prefix(target))
    }

    public static func selectWeak(
        from questions: [LearningQuestion],
        state: LearningState,
        target: Int,
        isPremium: Bool
    ) -> [LearningQuestion] {
        let ids = Set(state.weakQuestions.keys)
        let candidates = questions.filter { ids.contains($0.id) && (isPremium || !$0.premium) }
        return Array(candidates.sorted {
            let lhs = state.weakQuestions[$0.id]?.lastAnsweredAt ?? .distantPast
            let rhs = state.weakQuestions[$1.id]?.lastAnsweredAt ?? .distantPast
            return lhs < rhs
        }.prefix(LearningState.validTarget(target) ? target : 8))
    }

    public static func todayAnsweredCount(
        state: LearningState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        state.attempts.filter { calendar.isDate($0.answeredAt, inSameDayAs: now) }.count
    }

    public static func heatmap35Days(
        state: LearningState,
        endingAt endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date: Int] {
        guard let start = calendar.date(byAdding: .day, value: -34, to: calendar.startOfDay(for: endDate)) else {
            return [:]
        }
        var values: [Date: Int] = [:]
        for attempt in state.attempts {
            let day = calendar.startOfDay(for: attempt.answeredAt)
            if day >= start && day <= calendar.startOfDay(for: endDate) {
                values[day, default: 0] += 1
            }
        }
        return values
    }

    public static func subjectAccuracy(state: LearningState) -> [String: Double] {
        let grouped = Dictionary(grouping: state.attempts, by: \.subject)
        return grouped.mapValues { attempts in
            guard !attempts.isEmpty else { return 0 }
            return Double(attempts.filter(\.isCorrect).count) / Double(attempts.count)
        }
    }

    public static func requiredDailyPace(
        totalQuestionCount: Int,
        uniqueAnsweredCount: Int,
        examDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let examDate else { return nil }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: examDate)
        guard end >= start else { return 0 }
        let days = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
        let remaining = max(0, totalQuestionCount - uniqueAnsweredCount)
        return Int(ceil(Double(remaining) / Double(days)))
    }

    private static func normalizedAcceptedIndexSets(for question: LearningQuestion) -> [Set<Int>] {
        if let alternatives = question.acceptedIndexSets, !alternatives.isEmpty {
            return alternatives
                .filter { !$0.isEmpty }
                .map(Set.init)
        }
        guard !question.correctIndices.isEmpty else { return [] }
        return [Set(question.correctIndices)]
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "　", with: " ")
            .lowercased()
    }
}

private enum SeededShuffle {
    static func shuffle<T>(_ values: [T], seed: UInt64) -> [T] {
        var result = values
        var generator = LCG(state: seed == 0 ? 0x9E3779B97F4A7C15 : seed)
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let swapIndex = Int(generator.next() % UInt64(index + 1))
            if index != swapIndex { result.swapAt(index, swapIndex) }
        }
        return result
    }

    private struct LCG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = 2862933555777941757 &* state &+ 3037000493
            return state
        }
    }
}
