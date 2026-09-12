import Foundation
import Combine

enum Otsu4StudyKind: Equatable {
    case sprint(Int)
    case weak
    case subject(String)
    case mock(Int)

    var title: String {
        switch self {
        case .sprint(let goal): return "今日のスプリント・\(goal)問"
        case .weak: return "苦手をつぶす"
        case .subject(let name): return name
        case .mock(let set): return "模擬試験 第\(set)回"
        }
    }

    var isMock: Bool {
        if case .mock = self { return true }
        return false
    }

    init?(snapshot: Otsu4SessionSnapshot) {
        switch snapshot.kindCode {
        case "sprint": self = .sprint(snapshot.goal ?? 8)
        case "weak": self = .weak
        case "subject":
            guard let subject = snapshot.subject else { return nil }
            self = .subject(subject)
        case "mock":
            guard let set = snapshot.mockSet else { return nil }
            self = .mock(set)
        default: return nil
        }
    }
}

struct Otsu4AnswerState: Equatable {
    let selectedIndex: Int?
    let correct: Bool
    let unknown: Bool

    // Golden Master view aliases.
    var selected: Int? { selectedIndex }
    var isCorrect: Bool { correct }
}

struct Otsu4SubjectResult: Equatable {
    let correct: Int
    let total: Int

    var rate: Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total) * 100).rounded())
    }

    var passed: Bool { rate >= 60 }
}

@MainActor
final class Otsu4StudySession: ObservableObject, Identifiable {
    static let mockDurationSeconds = 120 * 60

    let id = UUID()
    let kind: Otsu4StudyKind
    let questions: [Otsu4Question]
    let startedAt: Date

    @Published private(set) var index: Int
    @Published private(set) var answers: [String: Otsu4AnswerState]
    @Published private(set) var isFinished = false
    private var timerTask: Task<Void, Never>?

    init(kind: Otsu4StudyKind, questions: [Otsu4Question], snapshot: Otsu4SessionSnapshot? = nil) {
        self.kind = kind
        self.questions = questions
        self.startedAt = snapshot?.startedAt ?? Date()
        self.index = min(max(0, snapshot?.index ?? 0), max(0, questions.count - 1))
        self.answers = snapshot?.answers.mapValues {
            Otsu4AnswerState(selectedIndex: $0.selectedIndex, correct: $0.correct, unknown: $0.unknown)
        } ?? [:]

        if kind.isMock {
            timerTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self else { return }
                    self.objectWillChange.send()
                    self.finishIfTimeExpired()
                    if self.isFinished { return }
                }
            }
        }
    }

    deinit {
        timerTask?.cancel()
    }

    var isMock: Bool { kind.isMock }
    var currentQuestion: Otsu4Question { questions[index] }
    var currentAnswer: Otsu4AnswerState? { answers[currentQuestion.id] }
    var currentAnswerState: Otsu4AnswerState? { currentAnswer }
    var hasAnsweredCurrent: Bool { currentAnswer != nil }
    var currentNumber: Int { index + 1 }
    var total: Int { questions.count }

    var progressText: String {
        if kind.isMock {
            return "\(index + 1)/\(questions.count)  \(timerText())"
        }
        return "\(index + 1) / \(questions.count)"
    }

    var canGoBack: Bool { kind.isMock && index > 0 }
    var isLast: Bool { index == questions.count - 1 }

    func remainingSeconds(at date: Date = Date()) -> Int {
        guard kind.isMock else { return 0 }
        let elapsed = max(0, Int(date.timeIntervalSince(startedAt)))
        return max(0, Self.mockDurationSeconds - elapsed)
    }

    func timerText(at date: Date = Date()) -> String {
        let remaining = remainingSeconds(at: date)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func finishIfTimeExpired(at date: Date = Date()) {
        guard kind.isMock, !isFinished, remainingSeconds(at: date) <= 0 else { return }
        finish()
    }

    func finishBecauseTimeExpired() {
        finishIfTimeExpired()
    }

    var snapshot: Otsu4SessionSnapshot {
        let kindCode: String
        var subject: String?
        var mockSet: Int?
        var goal: Int?
        switch kind {
        case .sprint(let value):
            kindCode = "sprint"
            goal = value
        case .weak:
            kindCode = "weak"
        case .subject(let value):
            kindCode = "subject"
            subject = value
        case .mock(let value):
            kindCode = "mock"
            mockSet = value
        }
        return Otsu4SessionSnapshot(
            kindCode: kindCode,
            subject: subject,
            mockSet: mockSet,
            goal: goal,
            questionIDs: questions.map(\.id),
            index: index,
            answers: answers.mapValues {
                Otsu4StoredAnswer(selectedIndex: $0.selectedIndex, correct: $0.correct, unknown: $0.unknown)
            },
            startedAt: startedAt
        )
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
        if isLast { finish() } else { index += 1 }
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
        timerTask?.cancel()
        timerTask = nil
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

    var correctRate: Int { scoreRate }
    var unknownCount: Int { answers.values.filter(\.unknown).count }

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
        return subjectResults.count == 3 && subjectResults.values.allSatisfy { $0.rate >= 60 }
    }
}
