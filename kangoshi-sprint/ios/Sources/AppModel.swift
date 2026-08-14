import Foundation
import SwiftUI

@MainActor
final class KangoshiAppModel: ObservableObject {
    @Published private(set) var content: NativeContentBundle
    @Published var learning: PersistedLearningState
    @Published var session: StudySession?
    @Published var lastFinished: HistoryEntry?
    @Published var selectedMajorSubject: String?

    private let stateKey = "kangoshi-native-learning-v1"
    private let questionsById: [String: NativeQuestion]

    init() {
        guard let url = Bundle.main.url(forResource: "questions.generated", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(NativeContentBundle.self, from: data),
              decoded.questions.count == 720 else {
            fatalError("Canonical 720-question native resource is missing or invalid")
        }
        content = decoded
        questionsById = Dictionary(uniqueKeysWithValues: decoded.questions.map { ($0.id, $0) })
        if let saved = UserDefaults.standard.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(PersistedLearningState.self, from: saved) {
            learning = state
        } else {
            learning = PersistedLearningState()
        }
    }

    var allQuestions: [NativeQuestion] { content.questions }
    var freeQuestions: [NativeQuestion] { content.freeSampleQuestionIds.compactMap { questionsById[$0] } }
    var currentQuestion: NativeQuestion? {
        guard let session, session.index < session.questionIds.count else { return nil }
        return questionsById[session.questionIds[session.index]]
    }
    var weakQuestions: [NativeQuestion] {
        learning.weak.keys.compactMap { questionsById[$0] }.sorted {
            (learning.weak[$0.id]?.misses ?? 0) > (learning.weak[$1.id]?.misses ?? 0)
        }
    }
    var majorSubjects: [String] {
        Array(Set(content.questions.map(\.majorSubject))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    var accuracy: Int {
        learning.totalAnswers > 0 ? Int((Double(learning.totalCorrect) / Double(learning.totalAnswers) * 100).rounded()) : 0
    }

    func todayCount() -> Int { learning.dailyAnswers[dayKey()] ?? 0 }
    func todayCorrect() -> Int { learning.dailyCorrect[dayKey()] ?? 0 }

    func startDaily(isPremium: Bool) {
        let pool = isPremium ? content.questions : freeQuestions
        start(pool: pool, title: "今日のスプリント", count: learning.goal)
    }

    func startFreeSample(category: String) {
        start(pool: freeQuestions.filter { $0.category == category }, title: "\(category) お試し", count: 8)
    }

    func startWeak() {
        start(pool: weakQuestions, title: "苦手をつぶす", count: min(learning.goal, weakQuestions.count))
    }

    func startMajor(_ major: String) {
        start(pool: content.questions.filter { $0.majorSubject == major }, title: major, count: learning.goal)
    }

    func startMock(exam: Int, category: String) {
        let rows = content.questions
            .filter { $0.sourceExam == exam && $0.category == category }
            .sorted { ($0.session, $0.questionNo) < ($1.session, $1.questionNo) }
        session = StudySession(questionIds: rows.map(\.id), title: "第\(exam)回・\(category)", sourceExam: exam, category: category, isMock: true)
    }

    func submitChoices(_ choices: [Int], unknown: Bool = false) {
        guard var s = session, !s.answered, let q = currentQuestion else { return }
        let sorted = choices.sorted()
        let correct = !unknown && q.scoringMode != "excluded" && q.acceptedChoiceSets.contains(sorted)
        let scored: Bool
        switch q.scoringMode {
        case "excluded": scored = false
        case "include_if_correct_exclude_if_wrong": scored = correct
        default: scored = true
        }
        let result = AnswerResult(questionId: q.id, correct: correct, scored: scored, unknown: unknown, responseChoices: sorted, numericResponse: nil)
        s.results.append(result); s.answered = true; session = s
        recordAttempt(question: q, correct: correct, neutral: q.scoringMode == "excluded")
    }

    func submitNumeric(_ value: Double?, unknown: Bool = false) {
        guard var s = session, !s.answered, let q = currentQuestion else { return }
        let correct: Bool
        if unknown || q.scoringMode == "excluded" || value == nil || q.numericAnswer == nil {
            correct = false
        } else {
            correct = abs(value! - q.numericAnswer!) <= q.tolerance
        }
        let scored = q.scoringMode != "excluded" && q.scoringMode != "include_if_correct_exclude_if_wrong" ? true : (q.scoringMode == "include_if_correct_exclude_if_wrong" ? correct : false)
        let result = AnswerResult(questionId: q.id, correct: correct, scored: scored, unknown: unknown, responseChoices: [], numericResponse: value)
        s.results.append(result); s.answered = true; session = s
        recordAttempt(question: q, correct: correct, neutral: q.scoringMode == "excluded")
    }

    func advance() {
        guard var s = session else { return }
        if s.index + 1 < s.questionIds.count {
            s.index += 1; s.answered = false; session = s
        } else {
            finishSession(s)
        }
    }

    func closeSession() { session = nil }

    func repeatLast() {
        guard let h = lastFinished else { return }
        if let exam = h.sourceExam, let category = h.category { startMock(exam: exam, category: category) }
        else { startDaily(isPremium: true) }
    }

    func setGoal(_ goal: Int) {
        guard [4,8,16].contains(goal) else { return }
        learning.goal = goal; save()
    }
    func setFontScale(_ scale: String) { learning.fontScale = scale; save() }
    func setExamDate(_ date: Date?) { learning.examDate = date; save() }

    func resetLearning() {
        learning = PersistedLearningState(); lastFinished = nil; session = nil; save()
    }

    func questions(in major: String) -> Int { content.questions.filter { $0.majorSubject == major }.count }
    func seen(in major: String) -> Int { content.questions.filter { $0.majorSubject == major && learning.seen.contains($0.id) }.count }
    func weak(in major: String) -> Int { content.questions.filter { $0.majorSubject == major && learning.weak[$0.id] != nil }.count }

    private func start(pool: [NativeQuestion], title: String, count: Int) {
        guard !pool.isEmpty, count > 0 else { return }
        let unseen = pool.filter { !learning.seen.contains($0.id) }.shuffled()
        let seen = pool.filter { learning.seen.contains($0.id) }.shuffled()
        let ids = Array((unseen + seen).prefix(min(count, pool.count))).map(\.id)
        session = StudySession(questionIds: ids, title: title, sourceExam: nil, category: nil, isMock: false)
    }

    private func recordAttempt(question q: NativeQuestion, correct: Bool, neutral: Bool) {
        learning.seen.insert(q.id)
        if !neutral {
            learning.totalAnswers += 1
            if correct { learning.totalCorrect += 1 }
            if correct, var w = learning.weak[q.id] {
                w.streak += 1
                if w.streak >= 3 { learning.weak.removeValue(forKey: q.id) }
                else { learning.weak[q.id] = w }
            } else if !correct {
                var w = learning.weak[q.id] ?? WeakProgress()
                w.streak = 0; w.misses += 1; learning.weak[q.id] = w
            }
            let key = dayKey()
            learning.dailyAnswers[key, default: 0] += 1
            if correct { learning.dailyCorrect[key, default: 0] += 1 }
        }
        save()
    }

    private func finishSession(_ s: StudySession) {
        let entry = HistoryEntry(date: Date(), title: s.title, correct: s.correct, scoredTotal: s.scoredTotal, attempted: s.attempted, sourceExam: s.sourceExam, category: s.category)
        learning.history.insert(entry, at: 0)
        if learning.history.count > 60 { learning.history = Array(learning.history.prefix(60)) }
        lastFinished = entry; session = nil; save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(learning) { UserDefaults.standard.set(data, forKey: stateKey) }
    }

    private func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = .current; f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
