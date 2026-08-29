import Foundation
import Combine

struct Otsu4AttemptRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let finishedAt: Date
    let title: String
    let correct: Int
    let total: Int
    let subjectRates: [String: Int]
    let durationSeconds: Int
    let isMock: Bool
}

struct Otsu4StoredAnswer: Codable, Equatable {
    let selectedIndex: Int?
    let correct: Bool
    let unknown: Bool
}

struct Otsu4SessionSnapshot: Codable, Equatable {
    let kindCode: String
    let subject: String?
    let mockSet: Int?
    let goal: Int?
    let questionIDs: [String]
    let index: Int
    let answers: [String: Otsu4StoredAnswer]
    let startedAt: Date
}

struct Otsu4QuestionProgress: Codable, Equatable {
    var correctCount: Int = 0
    var answerCount: Int = 0
}

struct Otsu4PersistedLearningState: Codable, Equatable {
    var goal: Int = 8
    var examDate: Date?
    var weakStreaks: [String: Int] = [:]
    var weakIDs: Set<String> = []
    var dailyAnswered: [String: Int] = [:]
    var history: [Otsu4AttemptRecord] = []
    var resume: Otsu4SessionSnapshot?
    var fontScale: Int = 1
    var seenIDs: Set<String>?
    var questionProgress: [String: Otsu4QuestionProgress]?
}

@MainActor
final class Otsu4LearningStore: ObservableObject {
    static let storageKey = "otsu4_learning_state_v210"

    @Published private(set) var state: Otsu4PersistedLearningState

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(Otsu4PersistedLearningState.self, from: data) {
            state = decoded
        } else {
            state = Otsu4PersistedLearningState()
        }
        self.defaults = defaults
    }

    private let defaults: UserDefaults

    var goal: Int { state.goal }
    var examDate: Date? { state.examDate }
    var fontScale: Int { state.fontScale }
    var weakCount: Int { state.weakIDs.count }
    var history: [Otsu4AttemptRecord] { state.history }
    var resumeSnapshot: Otsu4SessionSnapshot? { state.resume }
    var seenIDs: Set<String> { state.seenIDs ?? [] }
    var seenCount: Int { seenIDs.count }
    var totalCorrect: Int { state.history.reduce(0) { $0 + $1.correct } }

    var todayAnswered: Int {
        state.dailyAnswered[Self.dayKey(Date())] ?? 0
    }

    var todayProgress: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(todayAnswered) / Double(goal))
    }

    var examDaysRemaining: Int? {
        guard let examDate else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: examDate)
        return max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    func requiredDailyPace(totalAvailable: Int) -> Int? {
        guard let days = examDaysRemaining else { return nil }
        let remaining = max(0, totalAvailable - seenCount)
        if remaining == 0 { return 0 }
        guard days > 0 else { return remaining }
        return Int(ceil(Double(remaining) / Double(days)))
    }

    func requiredDailyPace(totalQuestions: Int) -> Int? {
        requiredDailyPace(totalAvailable: totalQuestions)
    }

    func last35DayCounts(referenceDate: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<35).map { offset in
            let daysAgo = 34 - offset
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return 0 }
            return state.dailyAnswered[Self.dayKey(date)] ?? 0
        }
    }

    func questionProgress(for questionID: String) -> Otsu4QuestionProgress {
        state.questionProgress?[questionID] ?? Otsu4QuestionProgress()
    }

    func recordQuestionAnswer(questionID: String, correct: Bool) {
        incrementQuestionProgress(questionID: questionID, correct: correct)
        save()
    }

    func setGoal(_ goal: Int) {
        guard Otsu4ContentStore.supportedSprintGoals.contains(goal) else { return }
        state.goal = goal
        save()
    }

    func setExamDate(_ date: Date?) {
        state.examDate = date
        save()
    }

    func setFontScale(_ value: Int) {
        state.fontScale = min(2, max(0, value))
        save()
    }

    func weakQuestions(from contentStore: Otsu4ContentStore, isPremium: Bool) -> [Otsu4Question] {
        let available = contentStore.availableQuestions(isPremium: isPremium)
        return available.filter { state.weakIDs.contains($0.id) }
    }

    func saveResume(session: Otsu4StudySession) {
        guard !session.isFinished else {
            clearResume()
            return
        }
        state.resume = session.snapshot
        save()
    }

    func clearResume() {
        state.resume = nil
        save()
    }

    func restoreSession(from contentStore: Otsu4ContentStore) -> Otsu4StudySession? {
        guard let snapshot = state.resume else { return nil }
        let byID = Dictionary(uniqueKeysWithValues: contentStore.allQuestions.map { ($0.id, $0) })
        let questions = snapshot.questionIDs.compactMap { byID[$0] }
        guard questions.count == snapshot.questionIDs.count,
              let kind = Otsu4StudyKind(snapshot: snapshot) else {
            clearResume()
            return nil
        }
        return Otsu4StudySession(
            kind: kind,
            questions: questions,
            snapshot: snapshot,
            onAnswer: { [weak self] questionID, correct in
                self?.recordQuestionAnswer(questionID: questionID, correct: correct)
            }
        )
    }

    func complete(session: Otsu4StudySession) {
        let duration = max(0, Int(Date().timeIntervalSince(session.startedAt)))
        var rates: [String: Int] = [:]
        for (subject, result) in session.subjectResults {
            rates[subject] = result.rate
        }
        let record = Otsu4AttemptRecord(
            id: UUID(),
            finishedAt: Date(),
            title: session.kind.title,
            correct: session.correctCount,
            total: session.questions.count,
            subjectRates: rates,
            durationSeconds: duration,
            isMock: session.kind.isMock
        )
        state.history.insert(record, at: 0)
        state.history = Array(state.history.prefix(200))

        var seen = state.seenIDs ?? []
        seen.formUnion(session.answers.keys)
        state.seenIDs = seen

        if !session.kind.isMock {
            let answered = session.answers.count
            let key = Self.dayKey(Date())
            state.dailyAnswered[key, default: 0] += answered
        }

        // Non-mock answers are recorded immediately when chosen so that a long
        // subject session can be interrupted without losing per-question stats.
        // Mock answers are mutable until submission, so record their final state here.
        if session.kind.isMock {
            for q in session.questions {
                guard let answer = session.answers[q.id] else { continue }
                incrementQuestionProgress(questionID: q.id, correct: answer.correct)
            }
        }

        for q in session.questions {
            guard let answer = session.answers[q.id] else { continue }
            if answer.correct {
                if state.weakIDs.contains(q.id) {
                    let streak = state.weakStreaks[q.id, default: 0] + 1
                    if streak >= 3 {
                        state.weakIDs.remove(q.id)
                        state.weakStreaks.removeValue(forKey: q.id)
                    } else {
                        state.weakStreaks[q.id] = streak
                    }
                }
            } else {
                state.weakIDs.insert(q.id)
                state.weakStreaks[q.id] = 0
            }
        }

        state.resume = nil
        save()
    }

    func resetLearningData() {
        let goal = state.goal
        let exam = state.examDate
        let font = state.fontScale
        state = Otsu4PersistedLearningState(goal: goal, examDate: exam, fontScale: font)
        save()
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(state)
    }

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(Otsu4PersistedLearningState.self, from: data)
        guard Otsu4ContentStore.supportedSprintGoals.contains(imported.goal),
              (0...2).contains(imported.fontScale) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        state = imported
        save()
    }

    private func incrementQuestionProgress(questionID: String, correct: Bool) {
        var map = state.questionProgress ?? [:]
        var progress = map[questionID] ?? Otsu4QuestionProgress()
        progress.answerCount += 1
        if correct {
            progress.correctCount += 1
        }
        map[questionID] = progress
        state.questionProgress = map
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
