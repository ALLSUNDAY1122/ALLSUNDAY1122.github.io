import Foundation
import SwiftUI
import LearningSprintCore

struct SessionResult: Identifiable, Equatable {
    let id = UUID()
    let kind: SessionKind
    let correct: Int
    let total: Int
    var rate: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
}

@MainActor
final class KanriLearningStore: ObservableObject {
    @Published private(set) var questions: [LearningQuestion] = []
    @Published private(set) var state: LearningState
    @Published var selectedRound = 1
    @Published var activeSession: LearningSessionSnapshot?
    @Published var currentEvaluation: AnswerEvaluation?
    @Published var selectedAnswerIndex: Int?
    @Published var result: SessionResult?
    @Published var errorMessage: String?
    @Published var showPaywall = false
    @Published var importMessage: String?

    let purchase: PurchaseController
    private let stateStore: LearningStateStore
    private var repository: QuestionRepository?

    init(purchase: PurchaseController, bundle: Bundle = .main, stateDirectory: URL? = nil) {
        self.purchase = purchase
        self.stateStore = LearningStateStore(
            bundleID: KanriAppConfig.bundleID,
            contentVersion: KanriAppConfig.contentVersion,
            directoryURL: stateDirectory
        )
        do {
            let repository = try QuestionRepository.load(bundle: bundle)
            self.repository = repository
            self.questions = repository.questions
            self.state = try stateStore.load()
        } catch {
            self.state = LearningState(contentVersion: KanriAppConfig.contentVersion)
            self.errorMessage = error.localizedDescription
        }
        selectedRound = 1
    }

    var isPremium: Bool { purchase.isPremium || KanriAppConfig.uiTestPremium }
    var currentQuestion: LearningQuestion? {
        guard let session = activeSession,
              session.currentIndex >= 0,
              session.currentIndex < session.questionIDs.count else { return nil }
        return repository?.question(id: session.questionIDs[session.currentIndex])
    }
    var sessionProgressText: String {
        guard let session = activeSession else { return "" }
        return "\(session.currentIndex + 1) / \(session.questionIDs.count)"
    }
    var todayAnswered: Int { LearningEngine.todayAnsweredCount(state: state) }
    var uniqueAnsweredCount: Int { Set(state.attempts.map(\.questionID)).count }
    var accuracy: Int {
        guard !state.attempts.isEmpty else { return 0 }
        return Int((Double(state.attempts.filter(\.isCorrect).count) / Double(state.attempts.count) * 100).rounded())
    }
    var weakCount: Int { state.weakQuestions.count }
    var dailyProgress: Double { min(1, Double(todayAnswered) / Double(max(1, state.dailyTarget))) }
    var dailyLabel: String { "\(min(todayAnswered, state.dailyTarget)) / \(state.dailyTarget)" }
    var heatmap: [Date: Int] { LearningEngine.heatmap35Days(state: state) }
    var requiredDailyPace: Int? {
        LearningEngine.requiredDailyPace(totalQuestionCount: 600, uniqueAnsweredCount: uniqueAnsweredCount, examDate: state.examDate)
    }

    func setDailyTarget(_ value: Int) {
        state.dailyTarget = LearningState.validTarget(value) ? value : 8
        save()
    }

    func setTextSizeStep(_ value: Int) {
        state.textSizeStep = min(2, max(0, value)); save()
    }

    func setExamDate(_ date: Date?) {
        state.examDate = date; save()
    }

    func selectRound(_ round: Int) {
        guard (1...3).contains(round) else { return }
        if !isPremium && round != 1 {
            showPaywall = true
            return
        }
        selectedRound = round
    }

    func startToday() {
        let round = isPremium ? selectedRound : 1
        let pool = accessibleQuestions(round: round)
        startSession(
            LearningEngine.selectSprint(from: pool, target: state.dailyTarget, isPremium: isPremium),
            kind: .sprint
        )
    }

    func startSubject(_ subject: String, round: Int? = nil) {
        let round = round ?? selectedRound
        if !isPremium && round != 1 { showPaywall = true; return }
        let pool = accessibleQuestions(round: round).filter { $0.subject == subject }
        if pool.isEmpty { errorMessage = "この分野の問題を読み込めませんでした。"; return }
        let selected = LearningEngine.selectSprint(from: pool, target: state.dailyTarget, isPremium: isPremium)
        startSession(selected, kind: .subject("第\(round)回|\(subject)"))
    }

    func startWeak() {
        let source = isPremium ? questions : questions.filter { !$0.premium }
        let selected = LearningEngine.selectWeak(from: source, state: state, target: state.dailyTarget, isPremium: isPremium)
        guard !selected.isEmpty else { errorMessage = "現在、復習する苦手問題はありません。"; return }
        startSession(selected, kind: .weak)
    }

    func startMock(_ round: Int) {
        guard isPremium else { showPaywall = true; return }
        guard let repository else { errorMessage = "問題データを読み込めません。"; return }
        let set = repository.round(round)
        guard set.count == 200 else { errorMessage = "第\(round)回の模試データが200問ではありません。"; return }
        startSession(set, kind: .mock("第\(round)回"))
    }

    func resume() {
        guard var snapshot = state.resumeSession else { return }
        let requiresPremium = snapshot.questionIDs.contains { repository?.question(id: $0)?.premium == true }
        if requiresPremium && !isPremium { showPaywall = true; return }
        while snapshot.currentIndex < snapshot.questionIDs.count,
              snapshot.answers[snapshot.questionIDs[snapshot.currentIndex]] != nil {
            snapshot.currentIndex += 1
        }
        if snapshot.currentIndex >= snapshot.questionIDs.count {
            complete(snapshot)
            return
        }
        activeSession = snapshot
        state.resumeSession = snapshot
        currentEvaluation = nil
        selectedAnswerIndex = nil
        save()
    }

    func answer(index: Int?) {
        guard var session = activeSession, let question = currentQuestion else { return }
        guard session.answers[question.id] == nil else { return }
        let payload = index.map { AnswerPayload(selectedIndices: [$0]) } ?? .unknown
        do {
            let evaluation = try LearningEngine.evaluate(question, answer: payload)
            session.answers[question.id] = payload
            LearningEngine.record(question: question, evaluation: evaluation, state: &state)
            activeSession = session
            state.resumeSession = session
            selectedAnswerIndex = index
            currentEvaluation = evaluation
            save()
        } catch {
            errorMessage = "採点できませんでした。問題データを確認してください。"
        }
    }

    func advance() {
        guard var session = activeSession else { return }
        guard let q = currentQuestion, session.answers[q.id] != nil else { return }
        if session.currentIndex >= session.questionIDs.count - 1 {
            complete(session)
            return
        }
        session.currentIndex += 1
        activeSession = session
        state.resumeSession = session
        currentEvaluation = nil
        selectedAnswerIndex = nil
        save()
    }

    func leaveSession() {
        activeSession = nil
        currentEvaluation = nil
        selectedAnswerIndex = nil
        save()
    }

    func dismissResult() { result = nil }

    func answeredCount(round: Int) -> Int {
        guard let repository else { return 0 }
        let ids = Set(repository.round(round).map(\.id))
        return Set(state.attempts.map(\.questionID).filter(ids.contains)).count
    }

    func answeredCount(round: Int, subject: String) -> Int {
        guard let repository else { return 0 }
        let ids = Set(repository.round(round, subject: subject).map(\.id))
        return Set(state.attempts.map(\.questionID).filter(ids.contains)).count
    }

    func questionCount(round: Int, subject: String) -> Int {
        repository?.round(round, subject: subject).count ?? 0
    }

    func completionCount(round: Int, subject: String) -> Int {
        state.completionCount(for: .subject("第\(round)回|\(subject)"))
    }

    func mockCompletionCount(round: Int) -> Int {
        state.completionCount(for: .mock("第\(round)回"))
    }

    func subjectAccuracy(_ subject: String) -> Int? {
        let attempts = state.attempts.filter { $0.subject == subject }
        guard !attempts.isEmpty else { return nil }
        return Int((Double(attempts.filter(\.isCorrect).count) / Double(attempts.count) * 100).rounded())
    }

    func exportBackup() throws -> Data { try stateStore.exportBackup(state) }

    func importBackup(_ data: Data) {
        do {
            state = try stateStore.importBackup(data, allowContentVersionMigration: false)
            activeSession = nil; result = nil
            importMessage = "JSONバックアップを復元しました。"
        } catch {
            importMessage = error.localizedDescription
        }
    }

    func resetLearningData() {
        do {
            try stateStore.reset()
            state = LearningState(contentVersion: KanriAppConfig.contentVersion)
            activeSession = nil; result = nil
            importMessage = "学習データをリセットしました。"
        } catch { importMessage = error.localizedDescription }
    }

    private func accessibleQuestions(round: Int) -> [LearningQuestion] {
        guard let repository else { return [] }
        let set = repository.round(round)
        return isPremium ? set : set.filter { !$0.premium }
    }

    private func startSession(_ selected: [LearningQuestion], kind: SessionKind) {
        guard !selected.isEmpty else { errorMessage = "出題できる問題がありません。"; return }
        let snapshot = LearningSessionSnapshot(kind: kind, questionIDs: selected.map(\.id))
        activeSession = snapshot
        state.resumeSession = snapshot
        currentEvaluation = nil
        selectedAnswerIndex = nil
        result = nil
        save()
    }

    private func complete(_ session: LearningSessionSnapshot) {
        var correct = 0
        for id in session.questionIDs {
            guard let q = repository?.question(id: id), let answer = session.answers[id],
                  let evaluation = try? LearningEngine.evaluate(q, answer: answer) else { continue }
            if evaluation.isCorrect { correct += 1 }
        }
        state.recordCompletion(for: session.kind)
        state.resumeSession = nil
        activeSession = nil
        currentEvaluation = nil
        selectedAnswerIndex = nil
        result = SessionResult(kind: session.kind, correct: correct, total: session.questionIDs.count)
        save()
    }

    private func save() {
        do { try stateStore.save(state) }
        catch { errorMessage = "学習状態を保存できませんでした。" }
    }
}
