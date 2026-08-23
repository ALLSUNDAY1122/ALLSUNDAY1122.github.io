import Foundation
import SwiftUI

struct FieldQuestionBatch: Identifiable {
    let index: Int
    let questions: [Question]

    var id: Int { index }
    var count: Int { questions.count }
    var title: String { "セット\(index + 1)" }
}

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var questions: [Question] = []
    @Published private(set) var questionMap: [String: Question] = [:]
    @Published var state = LearningState()
    @Published var route: AppRoute = .tabs
    @Published var selectedTab: MainTab = .home
    @Published var feedback: AnswerFeedback?
    @Published var selectedAnswers: [Int] = []
    @Published var loadError: String?
    @Published var paywallPresented = false

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        loadQuestions()
        loadState()
        sanitizeState()
    }

    var activeQuestions: [Question] { questions.filter(\.isScored) }
    var activeSession: ActiveSession? { state.inProgress }
    var currentQuestion: Question? {
        guard let s = state.inProgress, s.index >= 0, s.index < s.ids.count else { return nil }
        return questionMap[s.ids[s.index]]
    }
    var overallAccuracy: Double {
        guard state.totalAnswered > 0 else { return 0 }
        return Double(state.totalCorrect) / Double(state.totalAnswered)
    }
    var learningProgress: Double {
        let total = activeQuestions.count
        guard total > 0 else { return 0 }
        let completed = state.seen.filter { questionMap[$0]?.isScored == true }.count
        return min(1, Double(completed) / Double(total))
    }
    var learnedCount: Int { state.seen.filter { questionMap[$0]?.isScored == true }.count }
    var todayRecord: DailyRecord { state.daily[Self.dayKey(Date())] ?? DailyRecord() }
    var todayProgress: Double {
        guard state.goal > 0 else { return 0 }
        return min(1, Double(todayRecord.answered) / Double(state.goal))
    }
    var weakCount: Int { state.weak.count }
    var studyDays: Int { state.daily.values.filter { $0.answered > 0 }.count }
    var streak: Int {
        var d = Calendar.current.startOfDay(for: Date())
        var count = 0
        if (state.daily[Self.dayKey(d)]?.answered ?? 0) == 0 {
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }
        for _ in 0..<365 {
            guard (state.daily[Self.dayKey(d)]?.answered ?? 0) > 0 else { break }
            count += 1
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return count
    }

    var uniqueFields: [String] { Array(Set(activeQuestions.map(\.field))).sorted() }

    func fieldQuestions(_ field: String, premium: Bool) -> [Question] {
        activeQuestions.filter { $0.field == field && (premium || $0.isFree) }
    }

    func fieldQuestionBatches(_ field: String, premium: Bool, targetSize: Int = 20) -> [FieldQuestionBatch] {
        let sorted = fieldQuestions(field, premium: premium).sorted {
            if $0.exam != $1.exam { return $0.exam > $1.exam }
            return $0.questionNo < $1.questionNo
        }
        var canonical = Set<String>()
        let ordered = sorted.filter { canonical.insert($0.canonicalId).inserted }
        guard !ordered.isEmpty else { return [] }

        let preferred = max(1, targetSize)
        let batchCount = max(1, Int(ceil(Double(ordered.count) / Double(preferred))))
        let baseSize = ordered.count / batchCount
        let largerBatchCount = ordered.count % batchCount
        var cursor = 0
        var result: [FieldQuestionBatch] = []

        for index in 0..<batchCount {
            let size = baseSize + (index < largerBatchCount ? 1 : 0)
            let end = min(cursor + size, ordered.count)
            result.append(FieldQuestionBatch(index: index, questions: Array(ordered[cursor..<end])))
            cursor = end
        }
        return result
    }

    func sectionQuestions(exam: Int, section: String, premium: Bool) -> [Question] {
        activeQuestions.filter { $0.exam == exam && $0.section == section && (premium || $0.isFree) }
    }

    func startDaily(premium: Bool) {
        let pool = activeQuestions.filter { premium || $0.isFree }
        startSession(title: "今日のスプリント", field: "総合", pool: pool, count: state.goal, mockKey: nil, examBalanced: true)
    }

    func startField(_ field: String, premium: Bool) {
        let batches = fieldQuestionBatches(field, premium: premium)
        guard let first = batches.first else { return }
        startSession(title: "\(field)・\(first.title)", field: field, pool: first.questions, count: first.count, mockKey: nil)
    }

    func startFieldBatch(_ field: String, batchIndex: Int, premium: Bool) {
        let batches = fieldQuestionBatches(field, premium: premium)
        guard batches.indices.contains(batchIndex) else { return }
        let batch = batches[batchIndex]
        startSession(title: "\(field)・\(batch.title)", field: field, pool: batch.questions, count: batch.count, mockKey: nil)
    }

    func startWeak(premium: Bool) {
        let ids = state.weak.keys.sorted { (state.weak[$0]?.lastAnsweredAt ?? .distantPast) > (state.weak[$1]?.lastAnsweredAt ?? .distantPast) }
        let pool = ids.compactMap { questionMap[$0] }.filter { $0.isScored && (premium || $0.isFree) }
        guard !pool.isEmpty else { return }
        startSession(title: "苦手をつぶす", field: "苦手復習", pool: pool, count: min(state.goal, pool.count), mockKey: nil)
    }

    func startMock(exam: Int, section: String, premium: Bool) {
        let pool = sectionQuestions(exam: exam, section: section, premium: premium)
        guard !pool.isEmpty else { return }
        startSession(title: "第\(exam)回 \(section)", field: section, pool: pool, count: pool.count, mockKey: "\(exam)-\(section)")
    }

    func resume() {
        guard var session = state.inProgress else { return }
        if session.index >= session.ids.count {
            route = .result
            return
        }

        // If the user closed the quiz after grading but before tapping Next,
        // advance to the first unanswered item instead of counting it twice.
        while session.index < session.ids.count,
              session.answers.contains(where: { $0.questionID == session.ids[session.index] }) {
            session.index += 1
        }
        state.inProgress = session
        feedback = nil
        selectedAnswers = []
        if session.index >= session.ids.count {
            finishSessionIfNeeded()
        } else {
            route = .quiz
            persist()
        }
    }

    func quitQuiz() {
        persist()
        feedback = nil
        selectedAnswers = []
        route = .tabs
    }

    func toggleSelection(_ index: Int) {
        guard feedback == nil, let q = currentQuestion else { return }
        if q.selectionCount == 1 {
            selectedAnswers = [index]
            grade(unknown: false)
            return
        }
        if let i = selectedAnswers.firstIndex(of: index) {
            selectedAnswers.remove(at: i)
        } else if selectedAnswers.count < q.selectionCount {
            selectedAnswers.append(index)
        }
        if selectedAnswers.count == q.selectionCount { grade(unknown: false) }
    }

    func revealUnknown() { grade(unknown: true) }

    func nextQuestion() {
        guard var s = state.inProgress else { return }
        if s.index + 1 >= s.ids.count {
            finishSessionIfNeeded()
            return
        }
        s.index += 1
        state.inProgress = s
        feedback = nil
        selectedAnswers = []
        persist()
    }

    func clearCompletedSession() {
        state.inProgress = nil
        feedback = nil
        selectedAnswers = []
        route = .tabs
        persist()
    }

    func fieldRecord(_ field: String) -> FieldRecord { state.fields[field] ?? FieldRecord() }

    func dailyCells35() -> [(date: Date, answered: Int, isToday: Bool, isFuture: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysToSaturday = 7 - weekday
        let end = cal.date(byAdding: .day, value: daysToSaturday, to: today) ?? today
        let start = cal.date(byAdding: .day, value: -34, to: end) ?? today
        return (0..<35).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: start) ?? start
            return (date, state.daily[Self.dayKey(date)]?.answered ?? 0, cal.isDate(date, inSameDayAs: today), date > today)
        }
    }

    func exportData() throws -> Data { try encoder.encode(state) }

    func importData(_ data: Data) throws {
        state = try decoder.decode(LearningState.self, from: data)
        sanitizeState()
        persist()
    }

    func resetLearningData() {
        let settings = (state.fontSize, state.goal, state.shuffleQuestions, state.shuffleChoices, state.examDate)
        state = LearningState()
        state.fontSize = settings.0
        state.goal = settings.1
        state.shuffleQuestions = settings.2
        state.shuffleChoices = settings.3
        state.examDate = settings.4
        feedback = nil
        selectedAnswers = []
        route = .tabs
        persist()
    }

    func updateGoal(_ value: Int) { state.goal = [4, 8, 16].contains(value) ? value : 8; persist() }
    func updateFontSize(_ value: Int) { state.fontSize = [16, 18, 20].contains(value) ? value : 16; persist() }
    func updateShuffleQuestions(_ value: Bool) { state.shuffleQuestions = value; persist() }
    func updateShuffleChoices(_ value: Bool) { state.shuffleChoices = value; persist() }
    func updateExamDate(_ value: Date?) { state.examDate = value; persist() }

    func remainingDays() -> Int? {
        guard let date = state.examDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        return days >= 0 ? days : nil
    }

    func unansweredCount(premium: Bool) -> Int {
        activeQuestions.filter { (premium || $0.isFree) && !state.seen.contains($0.id) }.count
    }

    private func startSession(title: String, field: String, pool: [Question], count: Int, mockKey: String?, examBalanced: Bool = false) {
        guard !pool.isEmpty else { return }
        var candidates = pool
        if state.shuffleQuestions { candidates.shuffle() }
        if mockKey == nil {
            var unique: [Question] = []
            var canonical = Set<String>()
            for q in candidates where !canonical.contains(q.canonicalId) {
                canonical.insert(q.canonicalId)
                unique.append(q)
            }
            candidates = unique
        }
        let target = max(1, min(count, candidates.count))
        let chosen = examBalanced ? examBalancedSelection(from: candidates, count: target) : Array(candidates.prefix(target))
        var orders: [String: [Int]] = [:]
        for q in chosen {
            var order = Array(q.availableChoices.indices)
            if state.shuffleChoices && !q.isMediaQuestion { order.shuffle() }
            orders[q.id] = order
        }
        state.inProgress = ActiveSession(title: title, field: field, ids: chosen.map(\.id), index: 0, answers: [], choiceOrders: orders, mockKey: mockKey)
        feedback = nil
        selectedAnswers = []
        route = .quiz
        persist()
    }

    private func examBalancedSelection(from candidates: [Question], count: Int) -> [Question] {
        // The pharmacist national exam has 345 questions per exam:
        // 90 mandatory, 105 theory, and 150 practical. Keep short daily sessions
        // close to that composition so random variance does not make them
        // disproportionately easy or mandatory-question heavy.
        let sections: [(name: String, weight: Int)] = [("必須", 90), ("理論", 105), ("実践", 150)]
        let denominator = 345.0
        var quotas: [String: Int] = [:]
        var assigned = 0
        var remainders: [(name: String, value: Double)] = []

        for section in sections {
            let exact = Double(count * section.weight) / denominator
            let base = Int(exact.rounded(.down))
            quotas[section.name] = base
            assigned += base
            remainders.append((section.name, exact - Double(base)))
        }

        let remaining = max(0, count - assigned)
        let orderedRemainders = remainders.sorted {
            if $0.value == $1.value { return $0.name < $1.name }
            return $0.value > $1.value
        }
        for item in orderedRemainders.prefix(remaining) {
            quotas[item.name, default: 0] += 1
        }

        var selected: [Question] = []
        var used = Set<String>()
        for section in sections {
            let quota = quotas[section.name, default: 0]
            for question in candidates where question.section == section.name && selected.filter({ $0.section == section.name }).count < quota {
                selected.append(question)
                used.insert(question.id)
            }
        }

        if selected.count < count {
            for question in candidates where !used.contains(question.id) {
                selected.append(question)
                used.insert(question.id)
                if selected.count == count { break }
            }
        }

        if state.shuffleQuestions { selected.shuffle() }
        return Array(selected.prefix(count))
    }

    private func grade(unknown: Bool) {
        guard feedback == nil, var s = state.inProgress, let q = currentQuestion else { return }
        guard !s.answers.contains(where: { $0.questionID == q.id }) else { return }
        let selected = unknown ? [] : selectedAnswers
        let correct = !unknown && q.accepts(selected)
        let weakMessage = applyLearningResult(question: q, correct: correct, unknown: unknown)
        s.answers.append(SessionAnswer(questionID: q.id, correct: correct, unknown: unknown))
        state.inProgress = s
        feedback = AnswerFeedback(question: q, selected: selected, correct: correct, unknown: unknown, weakMessage: weakMessage)
        persist()
    }

    private func applyLearningResult(question q: Question, correct: Bool, unknown: Bool) -> String {
        state.totalAnswered += 1
        if correct { state.totalCorrect += 1 }
        state.seen.insert(q.id)

        let key = Self.dayKey(Date())
        var daily = state.daily[key] ?? DailyRecord()
        daily.answered += 1
        if correct { daily.correct += 1 }
        state.daily[key] = daily

        var field = state.fields[q.field] ?? FieldRecord()
        field.answered += 1
        if correct { field.correct += 1 }
        state.fields[q.field] = field

        if correct, var weak = state.weak[q.id] {
            weak.streak += 1
            weak.lastAnsweredAt = Date()
            if weak.streak >= 3 {
                state.weak.removeValue(forKey: q.id)
                return "3回連続正解。苦手から卒業しました。"
            }
            state.weak[q.id] = weak
            return "苦手卒業まであと\(3 - weak.streak)回"
        }
        if !correct || unknown {
            state.weak[q.id] = WeakRecord(streak: 0, lastAnsweredAt: Date())
            return "苦手に追加しました。あとで復習できます。"
        }
        return "この問題は正解として記録しました。"
    }

    private func finishSessionIfNeeded() {
        guard var s = state.inProgress else { return }
        if s.index >= s.ids.count {
            route = .result
            return
        }
        let score = s.answers.filter(\.correct).count
        let total = s.ids.count
        s.index = s.ids.count
        state.inProgress = s
        state.history.insert(SessionHistory(id: UUID(), completedAt: Date(), title: s.title, score: score, total: total), at: 0)
        if state.history.count > 30 { state.history = Array(state.history.prefix(30)) }
        if let key = s.mockKey { state.mock[key] = MockResult(score: score, total: total, completedAt: Date()) }
        feedback = nil
        selectedAnswers = []
        route = .result
        persist()
    }

    private func loadQuestions() {
        guard let url = Bundle.main.url(forResource: "questions.native", withExtension: "json") else {
            loadError = "問題データが見つかりません。"
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let bundle = try decoder.decode(QuestionBundle.self, from: data)
            guard bundle.questions.count == 1035 else { throw NSError(domain: "QuestionBundle", code: 1035) }
            questions = bundle.questions
            questionMap = Dictionary(uniqueKeysWithValues: bundle.questions.map { ($0.id, $0) })
        } catch {
            loadError = "問題データを読み込めませんでした。"
        }
    }

    private func loadState() {
        do {
            state = try decoder.decode(LearningState.self, from: Data(contentsOf: stateURL()))
        } catch {
            state = LearningState()
        }
    }

    private func sanitizeState() {
        let validIDs = Set(questions.map(\.id))
        state.weak = state.weak.filter { validIDs.contains($0.key) }
        state.seen = state.seen.intersection(validIDs)
        if let s = state.inProgress, s.ids.contains(where: { !validIDs.contains($0) }) { state.inProgress = nil }
        if ![4, 8, 16].contains(state.goal) { state.goal = 8 }
        if ![16, 18, 20].contains(state.fontSize) { state.fontSize = 16 }
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(state)
            let url = stateURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            // A persistence failure must not crash a study session.
        }
    }

    private func stateURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("PharmacistSprint", isDirectory: true).appendingPathComponent("learning-state.json")
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
