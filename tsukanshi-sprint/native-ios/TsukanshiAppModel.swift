import Foundation
import SwiftUI
import LearningSprintCore

@MainActor
final class TsukanshiStudySession: ObservableObject, Identifiable {
    let id = UUID()
    let kind: SessionKind
    let questions: [LearningQuestion]
    let startedAt: Date
    @Published var currentIndex: Int
    @Published var answers: [String: AnswerPayload]
    @Published var evaluations: [String: AnswerEvaluation]
    @Published var currentEvaluation: AnswerEvaluation?
    @Published var isFinished = false

    init(kind: SessionKind, questions: [LearningQuestion], snapshot: LearningSessionSnapshot? = nil) {
        self.kind = kind
        self.questions = questions
        self.startedAt = snapshot?.startedAt ?? Date()
        self.currentIndex = min(max(0, snapshot?.currentIndex ?? 0), max(0, questions.count - 1))
        self.answers = snapshot?.answers ?? [:]
        self.evaluations = [:]
        if let snapshot, !isMock {
            for question in questions {
                if let answer = snapshot.answers[question.id],
                   let evaluation = try? LearningEngine.evaluate(question, answer: answer) {
                    self.evaluations[question.id] = evaluation
                }
            }
            if currentIndex < questions.count {
                self.currentEvaluation = self.evaluations[questions[currentIndex].id]
            }
        }
    }

    var isMock: Bool {
        if case .mock = kind { return true }
        return false
    }

    var currentQuestion: LearningQuestion? {
        guard currentIndex >= 0, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progressText: String {
        guard !questions.isEmpty else { return "0 / 0" }
        return "\(min(currentIndex + 1, questions.count)) / \(questions.count)"
    }

    var snapshot: LearningSessionSnapshot {
        LearningSessionSnapshot(
            kind: kind,
            questionIDs: questions.map(\.id),
            currentIndex: currentIndex,
            startedAt: startedAt,
            answers: answers
        )
    }

    func answer(_ payload: AnswerPayload) throws -> AnswerEvaluation? {
        guard let question = currentQuestion else { return nil }
        if isMock {
            currentEvaluation = nil
            if payload.isUnknown || isCompleteMockAnswer(payload, for: question) {
                answers[question.id] = payload
            } else {
                answers.removeValue(forKey: question.id)
            }
            return nil
        }

        answers[question.id] = payload
        let evaluation = try LearningEngine.evaluate(question, answer: payload)
        evaluations[question.id] = evaluation
        currentEvaluation = evaluation
        return evaluation
    }

    func advance() {
        guard currentIndex + 1 < questions.count else {
            isFinished = true
            currentEvaluation = nil
            return
        }
        currentIndex += 1
        currentEvaluation = nil
        if !isMock, let question = currentQuestion {
            currentEvaluation = evaluations[question.id]
        }
    }

    func finishMock() {
        guard isMock else { return }
        var results: [String: AnswerEvaluation] = [:]
        for question in questions {
            let payload = answers[question.id] ?? .unknown
            if let evaluation = try? LearningEngine.evaluate(question, answer: payload) {
                results[question.id] = evaluation
            }
        }
        evaluations = results
        isFinished = true
    }

    var correctCount: Int {
        evaluations.values.filter(\.isCorrect).count
    }

    private func isCompleteMockAnswer(_ payload: AnswerPayload, for question: LearningQuestion) -> Bool {
        switch question.answerType {
        case .singleChoice:
            return payload.selectedIndices.count == 1
        case .multiChoice:
            return payload.selectedIndices.count == question.correctIndices.count
        case .numeric:
            return payload.numberValue != nil
        case .blankSelect:
            return question.blanks.allSatisfy { payload.blankValues[$0.key] != nil }
        case .declaration:
            return question.declarationFields.allSatisfy {
                !(payload.declarationValues[$0.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }
}

@MainActor
final class TsukanshiAppModel: ObservableObject {
    @Published private(set) var content: TsukanshiContentStore?
    @Published private(set) var state: LearningState
    @Published var activeSession: TsukanshiStudySession?
    @Published var loadError: String?
    @Published var transientMessage: String?

    let purchaseController = PurchaseController(productID: TsukanshiNativeConfig.productID)
    private var stateStore: LearningStateStore?

    init() {
        self.state = LearningState(contentVersion: "tsukanshi-2026-07-v01")
        do {
            let content = try TsukanshiContentStore()
            self.content = content
            let store = LearningStateStore(
                bundleID: TsukanshiNativeConfig.bundleID,
                contentVersion: content.bank.contentVersion
            )
            self.stateStore = store
            var loaded = try store.load()
            if loaded.contentVersion != content.bank.contentVersion {
                loaded.contentVersion = content.bank.contentVersion
                loaded.resumeSession = nil
            }
            if loaded.examDate == nil {
                loaded.examDate = TsukanshiNativeConfig.qualification.defaultExamDate
            }
            self.state = loaded
            try? store.save(loaded)
        } catch {
            loadError = error.localizedDescription
        }
    }

    var todayAnswered: Int { LearningEngine.todayAnsweredCount(state: state) }
    var todayProgress: Double { Double(min(todayAnswered, state.dailyTarget)) / Double(max(1, state.dailyTarget)) }
    var weakCount: Int { state.weakQuestions.count }
    var uniqueAnsweredCount: Int { Set(state.attempts.map(\.questionID)).count }
    var subjectAccuracy: [String: Double] { LearningEngine.subjectAccuracy(state: state) }
    var heatmap: [Date: Int] { LearningEngine.heatmap35Days(state: state) }

    var examDaysRemaining: Int? {
        guard let examDate = state.examDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: examDate)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    var requiredDailyPace: Int? {
        LearningEngine.requiredDailyPace(
            totalQuestionCount: content?.bank.studyQuestionCount ?? 480,
            uniqueAnsweredCount: uniqueAnsweredCount,
            examDate: state.examDate
        )
    }

    func setDailyTarget(_ value: Int) {
        guard LearningState.validTarget(value) else { return }
        state.dailyTarget = value
        persist()
    }

    func setTextSizeStep(_ value: Int) {
        state.textSizeStep = min(2, max(0, value))
        persist()
    }

    func setExamDate(_ date: Date?) {
        state.examDate = date
        persist()
    }

    func startSprint() {
        guard let content else { return }
        let selected = LearningEngine.selectSprint(
            from: content.studyQuestions,
            target: state.dailyTarget,
            isPremium: purchaseController.isPremium
        )
        start(kind: .sprint, questions: selected)
    }

    func startWeak() {
        guard let content else { return }
        let selected = LearningEngine.selectWeak(
            from: content.questions,
            state: state,
            target: state.dailyTarget,
            isPremium: purchaseController.isPremium
        )
        start(kind: .weak, questions: selected)
    }

    func startSubject(_ subject: String) {
        guard let content else { return }
        let selected = LearningEngine.selectSprint(
            from: content.questions(subject: subject, premium: purchaseController.isPremium),
            target: state.dailyTarget,
            isPremium: purchaseController.isPremium
        )
        start(kind: .subject(subject), questions: selected)
    }

    func startMock(round: String, subject: String) {
        guard let content else { return }
        let questions = content.mockQuestions(
            round: round,
            subject: subject,
            premium: purchaseController.isPremium
        )
        start(kind: .mock("\(round)|\(subject)"), questions: questions)
    }

    func resume() {
        guard let content, let snapshot = state.resumeSession else { return }
        let byID = Dictionary(uniqueKeysWithValues: content.questions.map { ($0.id, $0) })
        let questions = snapshot.questionIDs.compactMap { byID[$0] }
        guard questions.count == snapshot.questionIDs.count, !questions.isEmpty else {
            state.resumeSession = nil
            persist()
            return
        }
        activeSession = TsukanshiStudySession(kind: snapshot.kind, questions: questions, snapshot: snapshot)
    }

    func submit(_ payload: AnswerPayload, in session: TsukanshiStudySession) {
        guard let question = session.currentQuestion else { return }
        do {
            if let evaluation = try session.answer(payload) {
                LearningEngine.record(question: question, evaluation: evaluation, state: &state)
                persist()
            } else {
                saveResume(session)
            }
        } catch {
            transientMessage = "回答を採点できません: \(error.localizedDescription)"
        }
    }

    func advance(_ session: TsukanshiStudySession) {
        if session.isMock && session.currentIndex + 1 >= session.questions.count {
            finishMock(session)
            return
        }
        session.advance()
        if session.isFinished {
            state.resumeSession = nil
        } else {
            state.resumeSession = session.snapshot
        }
        persist()
    }

    func finishMock(_ session: TsukanshiStudySession) {
        session.finishMock()
        for question in session.questions {
            let evaluation = session.evaluations[question.id] ?? AnswerEvaluation(isCorrect: false, isUnknown: true, message: "わからない")
            LearningEngine.record(question: question, evaluation: evaluation, state: &state)
        }
        state.resumeSession = nil
        persist()
    }

    func closeSession(_ session: TsukanshiStudySession) {
        if !session.isFinished { saveResume(session) }
        activeSession = nil
    }

    func clearResume() {
        state.resumeSession = nil
        persist()
    }

    func backupData() throws -> Data {
        guard let stateStore else { throw CocoaError(.fileNoSuchFile) }
        return try stateStore.exportBackup(state)
    }

    func importBackup(_ data: Data) {
        guard let stateStore else { return }
        do {
            state = try stateStore.importBackup(data)
            transientMessage = "バックアップを復元しました"
        } catch {
            transientMessage = "復元できません: \(error.localizedDescription)"
        }
    }

    private func start(kind: SessionKind, questions: [LearningQuestion]) {
        guard !questions.isEmpty else {
            transientMessage = "利用できる問題がありません"
            return
        }
        state.resumeSession = nil
        persist()
        activeSession = TsukanshiStudySession(kind: kind, questions: questions)
    }

    private func saveResume(_ session: TsukanshiStudySession) {
        state.resumeSession = session.snapshot
        persist()
    }

    private func persist() {
        try? stateStore?.save(state)
        objectWillChange.send()
    }
}
