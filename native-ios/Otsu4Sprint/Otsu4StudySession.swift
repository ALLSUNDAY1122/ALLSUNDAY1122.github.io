import Foundation
import Combine

enum Otsu4StudyKind: Equatable {
    case today12
    case subject(String)
    case mock35

    var title: String {
        switch self {
        case .today12: return "今日の12問"
        case .subject(let name): return name
        case .mock35: return "本番35問"
        }
    }

    var isMock: Bool {
        if case .mock35 = self { return true }
        return false
    }
}

struct Otsu4AnswerState: Equatable {
    let selectedIndex: Int?
    let correct: Bool
    let unknown: Bool
}

struct Otsu4SubjectResult: Equatable {
    let correct: Int
    let total: Int

    var rate: Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total) * 100).rounded())
    }
}

@MainActor
final class Otsu4StudySession: ObservableObject, Identifiable {
    let id = UUID()
    let kind: Otsu4StudyKind
    let questions: [Otsu4Question]
    let startedAt = Date()

    @Published private(set) var index = 0
    @Published private(set) var answers: [String: Otsu4AnswerState] = [:]
    @Published private(set) var isFinished = false

    init(kind: Otsu4StudyKind, questions: [Otsu4Question]) {
        self.kind = kind
        self.questions = questions
    }

    var currentQuestion: Otsu4Question {
        questions[index]
    }

    var currentAnswer: Otsu4AnswerState? {
        answers[currentQuestion.id]
    }

    var progressText: String {
        "\(index + 1) / \(questions.count)"
    }

    var canGoBack: Bool {
        kind.isMock && index > 0
    }

    var isLast: Bool {
        index == questions.count - 1
    }

    func choose(_ choice: Int?) {
        guard !isFinished else { return }
        let q = currentQuestion
        if !kind.isMock, answers[q.id] != nil { return }
        answers[q.id] = Otsu4AnswerState(
            selectedIndex: choice,
            correct: choice == q.answer,
            unknown: choice == nil
        )
    }

    func next() {
        guard !isFinished else { return }
        if isLast {
            finish()
        } else {
            index += 1
        }
    }

    func previous() {
        guard canGoBack else { return }
        index -= 1
    }

    func finish() {
        guard !isFinished else { return }
        if kind.isMock {
            for q in questions where answers[q.id] == nil {
                answers[q.id] = Otsu4AnswerState(selectedIndex: nil, correct: false, unknown: true)
            }
        }
        isFinished = true
    }

    var correctCount: Int {
        questions.reduce(into: 0) { total, q in
            if answers[q.id]?.correct == true { total += 1 }
        }
    }

    var scoreRate: Int {
        guard !questions.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(questions.count) * 100).rounded())
    }

    var subjectResults: [String: Otsu4SubjectResult] {
        var result: [String: Otsu4SubjectResult] = [:]
        for subject in ["法令", "物理・化学", "性質・消火"] {
            let rows = questions.filter { $0.subject == subject }
            guard !rows.isEmpty else { continue }
            let correct = rows.filter { answers[$0.id]?.correct == true }.count
            result[subject] = Otsu4SubjectResult(correct: correct, total: rows.count)
        }
        return result
    }

    var mockPassEstimate: Bool {
        guard kind.isMock else { return false }
        return subjectResults.values.allSatisfy { $0.rate >= 60 }
    }
}
