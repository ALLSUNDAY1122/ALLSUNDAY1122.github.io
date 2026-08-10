import Foundation
import Combine

@MainActor
final class LearningStore: ObservableObject {
    @Published var state: PersistedLearningState
    @Published var currentTab: MainTab = .home
    @Published var session: SessionState? = nil
    @Published var result: SessionResult? = nil
    @Published var startupError: String? = nil
    @Published var importMessage: String? = nil

    let repository: QuestionRepository

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let persistenceURL: URL

    init(bundle: Bundle = .main, persistenceURL: URL? = nil) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        do {
            self.repository = try QuestionRepository.load(bundle: bundle)
        } catch {
            self.repository = .empty
            self.startupError = error.localizedDescription
        }

        let baseURL: URL
        if let persistenceURL {
            baseURL = persistenceURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = appSupport.appendingPathComponent("NetworkSpecialistSprint", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            baseURL = directory.appendingPathComponent("learning-state.json")
        }
        self.persistenceURL = baseURL

        if ProcessInfo.processInfo.arguments.contains("-UITestReset") {
            try? FileManager.default.removeItem(at: baseURL)
        }

        let contentVersion = self.repository.payload.contentVersion
        if let data = try? Data(contentsOf: baseURL),
           let loaded = try? decoder.decode(PersistedLearningState.self, from: data) {
            self.state = Self.sanitize(loaded, repository: self.repository)
        } else {
            self.state = .fresh(contentVersion: contentVersion)
        }

        if self.state.contentVersion != contentVersion, contentVersion != "missing" {
            self.state.contentVersion = contentVersion
            self.state.inProgress = nil
        }
        self.session = self.state.inProgress
    }

    var settings: UserSettings { state.settings }
    var fontScale: CGFloat { state.settings.fontSize.scale }

    var uniqueQuestions: [Question] { repository.uniqueQuestions }
    var weakQuestions: [Question] {
        repository.uniqueQuestions.filter { state.weak[$0.id] != nil }
    }

    var totalAnswered: Int { state.answerLog.count }
    var totalCorrect: Int { state.answerLog.filter(\.correct).count }
    var overallAccuracy: Int {
        totalAnswered == 0 ? 0 : Int((Double(totalCorrect) / Double(totalAnswered) * 100).rounded())
    }
    var seenCount: Int { state.seenIDs.count }

    var todayAnswered: Int {
        state.answerLog.filter { Calendar.current.isDateInToday($0.answeredAt) }.count
    }

    var todayCorrect: Int {
        state.answerLog.filter { Calendar.current.isDateInToday($0.answeredAt) && $0.correct }.count
    }

    var todayGoalProgress: Double {
        guard state.settings.dailyGoal > 0 else { return 0 }
        return min(1, Double(todayAnswered) / Double(state.settings.dailyGoal))
    }

    var examCountdown: (days: Int, pace: Int)? {
        guard let examDate = state.settings.examDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let exam = calendar.startOfDay(for: examDate)
        guard let days = calendar.dateComponents([.day], from: today, to: exam).day else { return nil }
        let unseen = max(0, uniqueQuestions.count - seenCount)
        let pace = days > 0 ? max(1, Int(ceil(Double(unseen) / Double(days)))) : 0
        return (days, pace)
    }

    func startToday() {
        let goal = state.settings.dailyGoal
        let unseen = uniqueQuestions.filter { !state.seenIDs.contains($0.id) }.shuffled()
        let weak = weakQuestions.shuffled()
        let seen = uniqueQuestions.filter { state.seenIDs.contains($0.id) && state.weak[$0.id] == nil }.shuffled()
        var output: [Question] = []
        var ids = Set<String>()
        for pool in [unseen, weak, seen] {
            for question in pool where output.count < goal {
                guard ids.insert(question.id).inserted else { continue }
                output.append(question)
            }
        }
        startSession(key: "today", questions: output, title: "今日のスプリント", mode: .practice)
    }

    func startWeak() {
        let questions = weakQuestions.shuffled()
        guard !questions.isEmpty else { return }
        startSession(key: "weak", questions: questions, title: "苦手をつぶす", mode: .practice)
    }

    func startDomain(_ domain: String) {
        let questions = Array(repository.uniqueQuestions(domain: domain).shuffled().prefix(state.settings.dailyGoal))
        startSession(key: "domain:\(domain)", questions: questions, title: domain, mode: .practice)
    }

    func startMock(year: Int) {
        startSession(
            key: "exam:\(year)",
            questions: repository.questions(forYear: year),
            title: "\(year)年度 春期 午前II",
            mode: .mock
        )
    }

    func retryQuestions(_ ids: [String], title: String = "復習") {
        let questions = ids.compactMap { repository.question(id: $0) }
        guard !questions.isEmpty else { return }
        startSession(key: "retry", questions: questions, title: title, mode: .practice)
    }

    func resumeSession() {
        guard let inProgress = state.inProgress else { return }
        session = inProgress
        result = nil
    }

    func exitSessionToHome() {
        if let session {
            state.inProgress = session
            persist()
        }
        self.session = nil
        self.result = nil
        self.currentTab = .home
    }

    func currentQuestion() -> Question? {
        guard let session,
              session.questionIDs.indices.contains(session.index) else { return nil }
        return repository.question(id: session.questionIDs[session.index])
    }

    func response(for question: Question) -> SessionResponse? {
        session?.responses[question.id]
    }

    func submitAnswer(_ selectedIndex: Int?) {
        guard var session,
              session.questionIDs.indices.contains(session.index),
              let question = repository.question(id: session.questionIDs[session.index]),
              session.responses[question.id] == nil else { return }

        let isUnknown = selectedIndex == nil
        let correct = selectedIndex == question.answerIndex
        let response = SessionResponse(selectedIndex: selectedIndex, isUnknown: isUnknown, correct: correct)
        session.responses[question.id] = response
        self.session = session

        let canonicalID = question.canonicalID
        state.seenIDs.insert(canonicalID)
        updateWeakState(canonicalID: canonicalID, correct: correct)
        state.answerLog.append(AnswerLogEntry(
            id: UUID(),
            questionID: question.id,
            canonicalQuestionID: canonicalID,
            answeredAt: Date(),
            responseIndex: selectedIndex,
            isUnknown: isUnknown,
            correct: correct,
            uiDomain: question.uiDomain,
            sessionKey: session.key,
            examYear: question.examYear
        ))
        if state.answerLog.count > 4000 {
            state.answerLog.removeFirst(state.answerLog.count - 4000)
        }
        state.inProgress = session
        persist()
    }

    func advanceSession() {
        guard var session else { return }
        let currentID = session.questionIDs[session.index]
        guard session.responses[currentID] != nil else { return }

        if session.index + 1 < session.questionIDs.count {
            session.index += 1
            self.session = session
            state.inProgress = session
            persist()
        } else {
            completeSession(session)
        }
    }

    func completionCount(for key: String) -> Int {
        state.sessionCompletions[key, default: 0]
    }

    func latestCompletion(for key: String) -> CompletionRecord? {
        state.completionHistory.first { $0.key == key }
    }

    func domainStats(_ domain: String) -> (answered: Int, accuracy: Int) {
        let logs = state.answerLog.filter { $0.uiDomain == domain }
        guard !logs.isEmpty else { return (0, 0) }
        let correct = logs.filter(\.correct).count
        return (logs.count, Int((Double(correct) / Double(logs.count) * 100).rounded()))
    }

    func resultDomainStats(_ result: SessionResult) -> [(domain: String, total: Int, correct: Int)] {
        var values: [String: (Int, Int)] = [:]
        for id in result.questionIDs {
            guard let q = repository.question(id: id), let response = result.responses[id] else { continue }
            let current = values[q.uiDomain] ?? (0, 0)
            values[q.uiDomain] = (current.0 + 1, current.1 + (response.correct ? 1 : 0))
        }
        return values.map { (domain: $0.key, total: $0.value.0, correct: $0.value.1) }
            .sorted { $0.domain.localizedStandardCompare($1.domain) == .orderedAscending }
    }

    func missedQuestionIDs(in result: SessionResult) -> [String] {
        result.questionIDs.compactMap { id in
            guard let response = result.responses[id], !response.correct else { return nil }
            guard let q = repository.question(id: id) else { return nil }
            return q.canonicalID
        }.uniqued()
    }

    func heatmap(days: Int = 35) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = state.answerLog.filter { calendar.isDate($0.answeredAt, inSameDayAs: date) }.count
            return (date, count)
        }
    }

    func setDailyGoal(_ goal: Int) {
        guard [4, 8, 16].contains(goal) else { return }
        state.settings.dailyGoal = goal
        persist()
    }

    func setFontSize(_ value: FontSizePreference) {
        state.settings.fontSize = value
        persist()
    }

    func setExamDate(_ date: Date?) {
        state.settings.examDate = date
        persist()
    }

    func exportBackup() throws -> Data {
        let envelope = BackupEnvelope(
            exportedAt: Date(),
            app: "ネットワークスペシャリスト｜学びスプリント",
            bundleID: "jp.allsunday1122.networkspecialist",
            contentVersion: repository.payload.contentVersion,
            state: state
        )
        return try encoder.encode(envelope)
    }

    func importBackup(_ data: Data) throws {
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard envelope.bundleID == "jp.allsunday1122.networkspecialist" else {
            throw BackupError.wrongApp
        }
        let sanitized = Self.sanitize(envelope.state, repository: repository)
        state = sanitized
        session = sanitized.inProgress
        result = nil
        persist()
        importMessage = "バックアップを読み込みました。"
    }

    func clearImportMessage() {
        importMessage = nil
    }

    private func startSession(key: String, questions: [Question], title: String, mode: SessionMode) {
        guard !questions.isEmpty else { return }
        let session = SessionState(
            key: key,
            title: title,
            mode: mode,
            questionIDs: questions.map(\.id),
            index: 0,
            responses: [:],
            startedAt: Date()
        )
        self.session = session
        self.result = nil
        state.inProgress = session
        persist()
    }

    private func updateWeakState(canonicalID: String, correct: Bool) {
        if correct {
            guard var progress = state.weak[canonicalID] else { return }
            progress.streak += 1
            progress.lastUpdatedAt = Date()
            if progress.streak >= 3 {
                state.weak.removeValue(forKey: canonicalID)
            } else {
                state.weak[canonicalID] = progress
            }
        } else {
            state.weak[canonicalID] = WeakProgress(streak: 0, lastUpdatedAt: Date())
        }
    }

    private func completeSession(_ session: SessionState) {
        let result = SessionResult(
            key: session.key,
            title: session.title,
            mode: session.mode,
            questionIDs: session.questionIDs,
            responses: session.responses,
            completedAt: Date()
        )
        state.sessionCompletions[session.key, default: 0] += 1
        state.completionHistory.insert(CompletionRecord(
            id: UUID(),
            key: session.key,
            title: session.title,
            mode: session.mode,
            completedAt: Date(),
            total: result.total,
            correct: result.correct
        ), at: 0)
        if state.completionHistory.count > 100 {
            state.completionHistory.removeLast(state.completionHistory.count - 100)
        }
        state.inProgress = nil
        self.session = nil
        self.result = result
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(state) else { return }
        do {
            let directory = persistenceURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: persistenceURL, options: [.atomic])
        } catch {
            // Persistence failure must not crash an active study session.
        }
    }

    private static func sanitize(_ loaded: PersistedLearningState, repository: QuestionRepository) -> PersistedLearningState {
        var state = loaded
        let validCanonicalIDs = Set(repository.uniqueQuestions.map(\.id))
        let validOccurrenceIDs = Set(repository.occurrences.map(\.id))

        state.weak = state.weak.filter { validCanonicalIDs.contains($0.key) }
        state.seenIDs = Set(state.seenIDs.filter { validCanonicalIDs.contains($0) })
        state.answerLog = state.answerLog.filter { validOccurrenceIDs.contains($0.questionID) }
        if ![4, 8, 16].contains(state.settings.dailyGoal) {
            state.settings.dailyGoal = 8
        }
        if let inProgress = state.inProgress,
           inProgress.questionIDs.contains(where: { !validOccurrenceIDs.contains($0) }) {
            state.inProgress = nil
        }
        if repository.payload.contentVersion != "missing" {
            state.contentVersion = repository.payload.contentVersion
        }
        return state
    }

    enum BackupError: LocalizedError {
        case wrongApp

        var errorDescription: String? {
            switch self {
            case .wrongApp: return "このバックアップはネットワークスペシャリスト用ではありません。"
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
