import Foundation
import Combine
import LearningSprintCore

public enum JosanshiLocalPersistenceConfiguration {
    /// Stable local namespace only. This is deliberately not the production Bundle ID.
    /// It can remain unchanged after App Store identity is assigned.
    public static let storageNamespace = "learning-sprint-14-josanshi-local"
    public static let contentVersion = "josanshi-content-v1"
}

public enum JosanshiLearningError: Error, Equatable {
    case contentUnavailable
    case subjectUnavailable(String)
    case weakQuestionsUnavailable
    case mockUnavailable(String)
    case noActiveSession
    case missingCurrentQuestion(String)
}

@MainActor
public final class JosanshiLearningCoordinator: ObservableObject {
    @Published public private(set) var state: LearningState
    @Published public private(set) var preferences: JosanshiPreferences
    @Published public private(set) var activeSession: LearningSessionSnapshot?
    @Published public private(set) var latestEvaluation: AnswerEvaluation?
    @Published public private(set) var persistenceErrorDescription: String?

    public private(set) var questions: [LearningQuestion]
    private let store: LearningStateStore?
    private let preferencesStore: JosanshiPreferencesStore?

    public init(
        questions: [LearningQuestion] = [],
        store: LearningStateStore? = nil,
        preferencesStore: JosanshiPreferencesStore? = nil,
        loadPersistedState: Bool = true
    ) {
        self.questions = questions
        self.store = store
        self.preferencesStore = preferencesStore ?? (loadPersistedState ? JosanshiPreferencesStore() : nil)

        if loadPersistedState, let store {
            do {
                let loaded = try store.load()
                self.state = loaded
                self.activeSession = loaded.resumeSession
                self.persistenceErrorDescription = nil
            } catch {
                self.state = LearningState(contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion)
                self.activeSession = nil
                self.persistenceErrorDescription = String(describing: error)
            }
        } else {
            self.state = LearningState(contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion)
            self.activeSession = nil
            self.persistenceErrorDescription = nil
        }

        do {
            self.preferences = try self.preferencesStore?.load() ?? JosanshiPreferences()
        } catch {
            self.preferences = JosanshiPreferences()
            self.persistenceErrorDescription = self.persistenceErrorDescription ?? String(describing: error)
        }
    }

    public static func defaultPersistentStore(directoryURL: URL? = nil) -> LearningStateStore {
        LearningStateStore(
            bundleID: JosanshiLocalPersistenceConfiguration.storageNamespace,
            contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion,
            directoryURL: directoryURL
        )
    }

    public func replaceQuestions(_ questions: [LearningQuestion]) {
        self.questions = questions
        if let session = activeSession {
            let known = Set(questions.map(\.id))
            if session.questionIDs.contains(where: { !known.contains($0) }) {
                state.resumeSession = nil
                activeSession = nil
                latestEvaluation = nil
                persist()
            }
        }
    }

    public func setDailyTarget(_ value: Int) {
        guard LearningState.validTarget(value) else { return }
        state.dailyTarget = value
        persist()
    }

    public func setExamDate(_ value: Date?) {
        state.examDate = value.map { Calendar.current.startOfDay(for: $0) }
        persist()
    }

    public func setTextSizeStep(_ value: Int) {
        guard (0...2).contains(value) else { return }
        preferences.textSizeStep = value
        persistPreferences()
    }

    public func setShuffleQuestions(_ value: Bool) {
        preferences.shuffleQuestions = value
        persistPreferences()
    }

    public func setShuffleChoices(_ value: Bool) {
        preferences.shuffleChoices = value
        persistPreferences()
    }

    @discardableResult
    public func startStandardSprint(isPremium: Bool = true, seed: UInt64? = nil) throws -> LearningSessionSnapshot {
        guard !questions.isEmpty else { throw JosanshiLearningError.contentUnavailable }
        let eligible = questions.filter { isPremium || !$0.premium }
        let selected: [LearningQuestion]
        if preferences.shuffleQuestions {
            selected = LearningEngine.selectSprint(
                from: eligible,
                target: state.dailyTarget,
                isPremium: true,
                seed: seed
            )
        } else {
            selected = Array(eligible.prefix(state.dailyTarget))
        }
        guard !selected.isEmpty else { throw JosanshiLearningError.contentUnavailable }
        return start(kind: .sprint, questions: selected)
    }

    @discardableResult
    public func startSubject(
        _ subject: String,
        isPremium: Bool = true,
        seed: UInt64? = nil
    ) throws -> LearningSessionSnapshot {
        guard JosanshiExamConfiguration.subjects.contains(subject) else {
            throw JosanshiLearningError.subjectUnavailable(subject)
        }
        let candidates = questions.filter { $0.subject == subject && (isPremium || !$0.premium) }
        guard !candidates.isEmpty else { throw JosanshiLearningError.subjectUnavailable(subject) }
        let selected: [LearningQuestion]
        if preferences.shuffleQuestions {
            selected = LearningEngine.selectSprint(
                from: candidates,
                target: state.dailyTarget,
                isPremium: true,
                seed: seed
            )
        } else {
            selected = Array(candidates.prefix(state.dailyTarget))
        }
        return start(kind: .subject(subject), questions: selected)
    }

    @discardableResult
    public func startWeakReview(isPremium: Bool = true) throws -> LearningSessionSnapshot {
        let selected = LearningEngine.selectWeak(
            from: questions,
            state: state,
            target: state.dailyTarget,
            isPremium: isPremium
        )
        guard !selected.isEmpty else { throw JosanshiLearningError.weakQuestionsUnavailable }
        return start(kind: .weak, questions: selected)
    }

    @discardableResult
    public func startMock(_ mockRound: Int, isPremium: Bool = true) throws -> LearningSessionSnapshot {
        let roundValue = String(mockRound)
        let candidates = questions.filter {
            $0.examRound == roundValue && (isPremium || !$0.premium)
        }
        guard !candidates.isEmpty else { throw JosanshiLearningError.mockUnavailable(roundValue) }
        return start(kind: .mock(roundValue), questions: candidates)
    }

    public var currentQuestion: LearningQuestion? {
        guard let session = activeSession,
              session.currentIndex >= 0,
              session.currentIndex < session.questionIDs.count else { return nil }
        let id = session.questionIDs[session.currentIndex]
        return questions.first(where: { $0.id == id })
    }

    public var sessionProgressText: String {
        guard let session = activeSession else { return "0 / 0" }
        return "\(min(session.currentIndex + 1, session.questionIDs.count)) / \(session.questionIDs.count)"
    }

    public func submit(_ answer: AnswerPayload, at date: Date = Date()) throws -> AnswerEvaluation {
        guard var session = activeSession else { throw JosanshiLearningError.noActiveSession }
        guard session.currentIndex < session.questionIDs.count else { throw JosanshiLearningError.noActiveSession }
        let questionID = session.questionIDs[session.currentIndex]
        guard let question = questions.first(where: { $0.id == questionID }) else {
            throw JosanshiLearningError.missingCurrentQuestion(questionID)
        }

        let evaluation = try LearningEngine.evaluate(question, answer: answer)
        LearningEngine.record(question: question, evaluation: evaluation, state: &state, at: date)
        session.answers[questionID] = answer
        latestEvaluation = evaluation

        if session.currentIndex + 1 >= session.questionIDs.count {
            state.recordCompletion(for: session.kind)
            state.resumeSession = nil
            activeSession = nil
        } else {
            session.currentIndex += 1
            state.resumeSession = session
            activeSession = session
        }
        persist()
        return evaluation
    }

    public func markUnknown(at date: Date = Date()) throws -> AnswerEvaluation {
        try submit(.unknown, at: date)
    }

    public func clearSession() {
        activeSession = nil
        latestEvaluation = nil
        state.resumeSession = nil
        persist()
    }

    public func resetLearningHistory() {
        let dailyTarget = state.dailyTarget
        let examDate = state.examDate
        state = LearningState(
            dailyTarget: dailyTarget,
            examDate: examDate,
            contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion
        )
        activeSession = nil
        latestEvaluation = nil
        persist()
    }

    public func resumePersistedSession() -> Bool {
        guard let snapshot = state.resumeSession else { return false }
        let known = Set(questions.map(\.id))
        guard snapshot.questionIDs.allSatisfy(known.contains) else {
            state.resumeSession = nil
            activeSession = nil
            persist()
            return false
        }
        activeSession = snapshot
        latestEvaluation = nil
        return true
    }

    public func exportBackup() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(JosanshiBackupEnvelope(state: state, preferences: preferences))
    }

    public func importBackup(_ data: Data) throws {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(JosanshiBackupEnvelope.self, from: data) {
            guard envelope.namespace == JosanshiLocalPersistenceConfiguration.storageNamespace else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "別の資格アプリのバックアップです。"])
            }
            guard envelope.state.contentVersion == JosanshiLocalPersistenceConfiguration.contentVersion else {
                throw LearningStateStoreError.invalidContentVersion(
                    expected: JosanshiLocalPersistenceConfiguration.contentVersion,
                    actual: envelope.state.contentVersion
                )
            }
            guard LearningState.validTarget(envelope.state.dailyTarget) else {
                throw LearningStateStoreError.invalidTarget(envelope.state.dailyTarget)
            }
            state = envelope.state
            preferences = envelope.preferences
            activeSession = state.resumeSession
            persist()
            persistPreferences()
            return
        }

        guard let store else {
            state = try decoder.decode(LearningState.self, from: data)
            activeSession = state.resumeSession
            return
        }
        state = try store.importBackup(data, allowContentVersionMigration: false)
        activeSession = state.resumeSession
        persistenceErrorDescription = nil
    }

    public var todayAnsweredCount: Int {
        LearningEngine.todayAnsweredCount(state: state)
    }

    public var heatmap35Days: [Date: Int] {
        LearningEngine.heatmap35Days(state: state)
    }

    public var subjectAccuracy: [String: Double] {
        LearningEngine.subjectAccuracy(state: state)
    }

    public var weakQuestionCount: Int {
        state.weakQuestions.count
    }

    public var totalAnsweredCount: Int { state.attempts.count }
    public var totalCorrectCount: Int { state.attempts.filter(\.isCorrect).count }
    public var uniqueAnsweredCount: Int { Set(state.attempts.map(\.questionID)).count }

    public var requiredDailyPace: Int? {
        guard let examDate = state.examDate else { return nil }
        return LearningEngine.requiredDailyPace(
            totalQuestionCount: questions.count,
            uniqueAnsweredCount: uniqueAnsweredCount,
            examDate: examDate
        )
    }

    private func start(kind: SessionKind, questions selected: [LearningQuestion]) -> LearningSessionSnapshot {
        if let activeSession {
            return activeSession
        }
        let snapshot = LearningSessionSnapshot(kind: kind, questionIDs: selected.map(\.id))
        activeSession = snapshot
        latestEvaluation = nil
        state.resumeSession = snapshot
        persist()
        return snapshot
    }

    private func persist() {
        guard let store else { return }
        do {
            try store.save(state)
            persistenceErrorDescription = nil
        } catch {
            persistenceErrorDescription = String(describing: error)
        }
    }

    private func persistPreferences() {
        guard let preferencesStore else { return }
        do {
            try preferencesStore.save(preferences)
            persistenceErrorDescription = nil
        } catch {
            persistenceErrorDescription = String(describing: error)
        }
    }
}
