import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    private static let storageKey = "shoshi-learning-state-v2"
    private static let trialConsumedKey = "shoshi-native-trial-completed-v2"

    let questions: [Question]
    let questionsByID: [String: Question]
    let startupError: String?

    @Published var state: LearningState
    @Published var activeSession: SessionSnapshot?
    @Published var selectedChoice: Int?
    @Published var lastWasCorrect: Bool?
    @Published var showFeedback = false
    @Published var lastResult: SessionResult?
    @Published var importMessage: String?

    init() {
        do {
            let loaded = try QuestionRepository.load()
            questions = loaded
            questionsByID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            startupError = nil
        } catch {
            questions = []
            questionsByID = [:]
            startupError = error.localizedDescription
        }

        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let restored = try? LearningLogic.importJSON(data) {
            state = restored
        } else {
            state = LearningState()
        }

        let resume = LearningLogic.validateResume(state.resume, questionsByID: questionsByID)
        state.resume = resume
        activeSession = resume
        selectedChoice = resume?.answeredChoice
        lastWasCorrect = resume?.answeredCorrect
        showFeedback = resume?.answeredChoice != nil
    }

    var currentQuestion: Question? {
        guard let session = activeSession,
              session.index < session.questionIDs.count else { return nil }
        return questionsByID[session.questionIDs[session.index]]
    }

    var todayKey: String { Self.dayFormatter.string(from: Date()) }
    var todayAnswered: Int { state.days[todayKey]?.answered ?? 0 }
    var weakCount: Int { state.weakIDs.count }
    var overallAccuracy: Double { state.overallAccuracy }
    var selectedTextSize: String { state.textSize }
    var trialConsumed: Bool { UserDefaults.standard.bool(forKey: Self.trialConsumedKey) }

    func subjects(for year: Int) -> [String] {
        Array(Set(questions.filter { $0.sourceYear == year }.map(\.subject))).sorted { a, b in
            let order = ["憲法","民法","刑法","商法・会社法","民事訴訟法","民事保全法","民事執行法","司法書士法","供託法","不動産登記法","商業登記法"]
            return (order.firstIndex(of: a) ?? 999) < (order.firstIndex(of: b) ?? 999)
        }
    }

    func questionCount(year: Int, subject: String) -> Int {
        questions.filter { $0.sourceYear == year && $0.subject == subject }.count
    }

    func completionCount(year: Int, subject: String) -> Int {
        state.completionCounts[SessionDescriptor.subject(year: year, subject: subject).completionKey, default: 0]
    }

    func start(_ descriptor: SessionDescriptor, premium: Bool) -> Bool {
        if !premium {
            if descriptor.kind != .daily { return false }
            if trialConsumed { return false }
        }
        let limit = descriptor.kind == .daily ? (premium ? state.dailyGoal : min(state.dailyGoal, 8)) : Int.max
        let selected = LearningLogic.selectQuestions(descriptor: descriptor, all: questions, state: state, dailyLimit: limit)
        guard !selected.isEmpty else { return false }
        let snapshot = SessionSnapshot(descriptor: descriptor, questionIDs: selected.map(\.id), index: 0, correctCount: 0, answeredChoice: nil, answeredCorrect: nil)
        activeSession = snapshot
        state.resume = snapshot
        selectedChoice = nil
        lastWasCorrect = nil
        showFeedback = false
        lastResult = nil
        persist()
        return true
    }

    func resume(premium: Bool) -> Bool {
        guard let saved = LearningLogic.validateResume(state.resume, questionsByID: questionsByID) else { return false }
        if !premium && saved.descriptor.kind != .daily { return false }
        if !premium && trialConsumed { return false }
        activeSession = saved
        selectedChoice = saved.answeredChoice
        lastWasCorrect = saved.answeredCorrect
        showFeedback = saved.answeredChoice != nil
        return true
    }

    func answer(_ choice: Int) {
        guard var session = activeSession, session.answeredChoice == nil, let question = currentQuestion else { return }
        let correct = LearningLogic.recordAnswer(state: &state, question: question, choice: choice, dayKey: todayKey)
        if correct { session.correctCount += 1 }
        session.answeredChoice = choice
        session.answeredCorrect = correct
        activeSession = session
        state.resume = session
        selectedChoice = choice
        lastWasCorrect = correct
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showFeedback = true }
        persist()
    }

    func next(premium: Bool) {
        guard var session = activeSession, session.answeredChoice != nil else { return }
        if session.index + 1 >= session.questionIDs.count {
            let result = SessionResult(descriptor: session.descriptor, correct: session.correctCount, total: session.questionIDs.count)
            if session.descriptor.kind == .daily && !premium {
                UserDefaults.standard.set(true, forKey: Self.trialConsumedKey)
            }
            LearningLogic.completeSession(state: &state, descriptor: session.descriptor)
            activeSession = nil
            lastResult = result
            selectedChoice = nil
            lastWasCorrect = nil
            showFeedback = false
            persist()
            return
        }
        session.index += 1
        session.answeredChoice = nil
        session.answeredCorrect = nil
        activeSession = session
        state.resume = session
        selectedChoice = nil
        lastWasCorrect = nil
        showFeedback = false
        persist()
    }

    func leaveQuizKeepingResume() { activeSession = nil }
    func closeResult() { lastResult = nil }

    func setDailyGoal(_ goal: Int) { state.dailyGoal = [4,8,16].contains(goal) ? goal : 8; persist() }
    func setTextSize(_ value: String) { state.textSize = ["small","medium","large"].contains(value) ? value : "medium"; persist() }
    func setExamDate(_ date: Date?) { state.examDate = date; persist() }

    func subjectAccuracy(_ subject: String) -> Double {
        let ids = questions.filter { $0.subject == subject }.map(\.id)
        let stats = ids.compactMap { state.attempts[$0] }
        let answered = stats.reduce(0) { $0 + $1.answered }
        guard answered > 0 else { return 0 }
        return Double(stats.reduce(0) { $0 + $1.correct }) / Double(answered)
    }

    func dayStat(_ date: Date) -> DayStat { state.days[Self.dayFormatter.string(from: date)] ?? DayStat() }
    func exportBackupData() throws -> Data { try LearningLogic.exportJSON(state) }

    func importBackupData(_ data: Data) throws {
        var imported = try LearningLogic.importJSON(data)
        imported.resume = LearningLogic.validateResume(imported.resume, questionsByID: questionsByID)
        state = imported
        activeSession = nil
        lastResult = nil
        selectedChoice = nil
        lastWasCorrect = nil
        showFeedback = false
        persist()
        importMessage = "バックアップを読み込みました。"
    }

    func resetLearningData() {
        let goal = state.dailyGoal
        let text = state.textSize
        state = LearningState()
        state.dailyGoal = goal
        state.textSize = text
        activeSession = nil
        lastResult = nil
        persist()
    }

    private func persist() {
        if let data = try? LearningLogic.exportJSON(state) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
