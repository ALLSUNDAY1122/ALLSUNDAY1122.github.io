import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct QuestionPayload: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let qualification: String
    let sourceCheckedAt: String
    let productionTargetCount: Int
    let questions: [AppQuestion]
}

struct AppQuestion: Codable, Identifiable, Hashable {
    let id: String
    let round: Int
    let edition: Int
    let questionNo: Int
    let subject: String
    let domain: String
    let topic: String
    let question: String
    let choices: [String]
    let correctIndex: Int
    let memoryLine: String
    let shortExplanation: String
    let detailExplanation: String
    let sourceURL: String
    let referenceDate: String
    let originType: String
    let rightsBasis: String
}

enum MainTab: String, CaseIterable, Identifiable {
    case home, mock, history, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "ホーム"
        case .mock: return "模試"
        case .history: return "記録"
        case .settings: return "設定"
        }
    }
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .mock: return "doc.text"
        case .history: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

enum SessionMode: String, Codable { case practice, mock }

enum FontSizePreference: String, Codable, CaseIterable, Identifiable {
    case normal, large, xlarge
    var id: String { rawValue }
    var title: String {
        switch self {
        case .normal: return "標準"
        case .large: return "大"
        case .xlarge: return "特大"
        }
    }
    var scale: CGFloat {
        switch self {
        case .normal: return 1
        case .large: return 1.13
        case .xlarge: return 1.27
        }
    }
}

struct UserSettings: Codable, Equatable {
    var dailyGoal: Int = 8
    var fontSize: FontSizePreference = .normal
    var examDate: Date? = nil
}

struct WeakProgress: Codable, Equatable {
    var streak: Int
    var lastUpdatedAt: Date
}

struct AnswerLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let questionID: String
    let answeredAt: Date
    let responseIndex: Int?
    let isUnknown: Bool
    let correct: Bool
    let domain: String
    let sessionKey: String
    let edition: Int
}

struct SessionResponse: Codable, Equatable {
    let selectedIndex: Int?
    let isUnknown: Bool
    let correct: Bool
}

struct SessionState: Codable, Equatable {
    let key: String
    let title: String
    let mode: SessionMode
    let questionIDs: [String]
    var index: Int
    var responses: [String: SessionResponse]
    let startedAt: Date
    var total: Int { questionIDs.count }
}

struct CompletionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let key: String
    let title: String
    let mode: SessionMode
    let completedAt: Date
    let total: Int
    let correct: Int
}

struct PersistedLearningState: Codable, Equatable {
    var schemaVersion: Int = 1
    var contentVersion: String
    var weak: [String: WeakProgress] = [:]
    var seenIDs: Set<String> = []
    var answerLog: [AnswerLogEntry] = []
    var sessionCompletions: [String: Int] = [:]
    var completionHistory: [CompletionRecord] = []
    var settings: UserSettings = .init()
    var inProgress: SessionState? = nil

    static func fresh(contentVersion: String) -> PersistedLearningState {
        PersistedLearningState(contentVersion: contentVersion)
    }
}

struct SessionResult: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let title: String
    let mode: SessionMode
    let questionIDs: [String]
    let responses: [String: SessionResponse]
    var total: Int { questionIDs.count }
    var correct: Int { responses.values.filter(\.correct).count }
    var accuracy: Int {
        total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded())
    }
}

struct BackupEnvelope: Codable {
    let exportedAt: Date
    let appNamespace: String
    let contentVersion: String
    let state: PersistedLearningState
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct QuestionRepository {
    let payload: QuestionPayload
    private let byID: [String: AppQuestion]

    init(payload: QuestionPayload) {
        self.payload = payload
        self.byID = Dictionary(uniqueKeysWithValues: payload.questions.map { ($0.id, $0) })
    }

    static func load(bundle: Bundle = .main) throws -> QuestionRepository {
        let productionURL = bundle.url(forResource: "questions.production", withExtension: "json")
            ?? bundle.url(forResource: "questions.production", withExtension: "json", subdirectory: "Resources")
        let prototypeURL = bundle.url(forResource: "questions.prototype", withExtension: "json")
            ?? bundle.url(forResource: "questions.prototype", withExtension: "json", subdirectory: "Resources")
        guard let url = productionURL ?? prototypeURL else {
            throw RepositoryError.missingResource
        }
        let payload = try JSONDecoder().decode(QuestionPayload.self, from: Data(contentsOf: url))
        try validate(payload)
        return QuestionRepository(payload: payload)
    }

    static var empty: QuestionRepository {
        QuestionRepository(payload: QuestionPayload(
            schemaVersion: 1,
            contentVersion: "missing",
            qualification: "不動産鑑定士試験・短答式",
            sourceCheckedAt: "",
            productionTargetCount: 240,
            questions: []
        ))
    }

    var questions: [AppQuestion] { payload.questions }
    var editions: [Int] { Array(Set(questions.map(\.edition))).sorted(by: >) }
    var domains: [String] {
        Array(Set(questions.map(\.domain))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func question(id: String) -> AppQuestion? { byID[id] }
    func questions(edition: Int) -> [AppQuestion] {
        questions.filter { $0.edition == edition }.sorted {
            if $0.subject == $1.subject { return $0.questionNo < $1.questionNo }
            return $0.subject < $1.subject
        }
    }
    func questions(domain: String) -> [AppQuestion] { questions.filter { $0.domain == domain } }

    private static func validate(_ payload: QuestionPayload) throws {
        guard payload.productionTargetCount == 240 else { throw RepositoryError.invalidProductionTarget }
        let isProduction = payload.contentVersion.hasPrefix("official-240-")
        let expectedTotal = isProduction ? 240 : 12
        let expectedPerSubjectRound = isProduction ? 40 : 2
        let expectedChoiceCount = isProduction ? 5 : 4
        guard payload.questions.count == expectedTotal else {
            throw RepositoryError.invalidQuestionCount(expected: expectedTotal, actual: payload.questions.count)
        }
        guard Set(payload.questions.map(\.id)).count == payload.questions.count else { throw RepositoryError.duplicateIDs }
        guard Set(payload.questions.map(\.edition)) == Set([2026, 2025, 2024]) else {
            throw RepositoryError.invalidEditions
        }
        for round in 1...3 {
            for subject in ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"] {
                let count = payload.questions.filter { $0.round == round && $0.subject == subject }.count
                guard count == expectedPerSubjectRound else {
                    throw RepositoryError.invalidRoundSubject(round, subject, expected: expectedPerSubjectRound, actual: count)
                }
            }
        }
        for question in payload.questions {
            guard question.choices.count == expectedChoiceCount,
                  question.choices.indices.contains(question.correctIndex),
                  !question.question.isEmpty,
                  !question.memoryLine.isEmpty,
                  !question.shortExplanation.isEmpty,
                  !question.detailExplanation.isEmpty,
                  URL(string: question.sourceURL) != nil,
                  !question.referenceDate.isEmpty,
                  !question.originType.isEmpty,
                  !question.rightsBasis.isEmpty else {
                throw RepositoryError.invalidQuestion(question.id)
            }
        }
    }

    enum RepositoryError: LocalizedError {
        case missingResource
        case invalidProductionTarget
        case invalidQuestionCount(expected: Int, actual: Int)
        case duplicateIDs
        case invalidEditions
        case invalidRoundSubject(Int, String, expected: Int, actual: Int)
        case invalidQuestion(String)

        var errorDescription: String? {
            switch self {
            case .missingResource: return "問題データを読み込めません。"
            case .invalidProductionTarget: return "製品版問題枠は240問でなければなりません。"
            case .invalidQuestionCount(let expected, let actual): return "問題数が\(actual)問です。期待値は\(expected)問です。"
            case .duplicateIDs: return "問題IDが重複しています。"
            case .invalidEditions: return "収録年度は令和8・7・6年の3年度でなければなりません。"
            case .invalidRoundSubject(let round, let subject, let expected, let actual):
                return "R\(round)・\(subject)が\(actual)問です。期待値は\(expected)問です。"
            case .invalidQuestion(let id): return "\(id)の必須データが不正です。"
            }
        }
    }
}

@MainActor
final class LearningStore: ObservableObject {
    static let backupNamespace = "kanteishi-shortanswer-sprint"

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
            self.startupError = nil
        } catch {
            self.repository = .empty
            self.startupError = error.localizedDescription
        }

        if let persistenceURL {
            self.persistenceURL = persistenceURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = base.appendingPathComponent("KanteishiShortAnswerSprint", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.persistenceURL = directory.appendingPathComponent("learning-state.json")
        }

        if let data = try? Data(contentsOf: self.persistenceURL),
           let loaded = try? decoder.decode(PersistedLearningState.self, from: data) {
            self.state = Self.sanitize(loaded, repository: self.repository)
        } else {
            self.state = .fresh(contentVersion: self.repository.payload.contentVersion)
        }
        if self.repository.payload.contentVersion != "missing",
           self.state.contentVersion != self.repository.payload.contentVersion {
            self.state.contentVersion = self.repository.payload.contentVersion
            self.state.inProgress = nil
        }
        self.session = self.state.inProgress
    }

    var settings: UserSettings { state.settings }
    var fontScale: CGFloat { settings.fontSize.scale }
    var totalAnswered: Int { state.answerLog.count }
    var totalCorrect: Int { state.answerLog.filter(\.correct).count }
    var overallAccuracy: Int {
        totalAnswered == 0 ? 0 : Int((Double(totalCorrect) / Double(totalAnswered) * 100).rounded())
    }
    var seenCount: Int { state.seenIDs.count }
    var weakQuestions: [AppQuestion] { repository.questions.filter { state.weak[$0.id] != nil } }
    var todayAnswered: Int { state.answerLog.filter { Calendar.current.isDateInToday($0.answeredAt) }.count }
    var todayCorrect: Int { state.answerLog.filter { Calendar.current.isDateInToday($0.answeredAt) && $0.correct }.count }
    var todaySessionTarget: Int { min(settings.dailyGoal, repository.questions.count) }
    var todayGoalProgress: Double {
        todaySessionTarget == 0 ? 0 : min(1, Double(todayAnswered) / Double(todaySessionTarget))
    }
    var examCountdown: (days: Int, pace: Int)? {
        guard let examDate = settings.examDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: examDate)
        ).day ?? 0
        let remaining = max(0, repository.payload.productionTargetCount - seenCount)
        return (days, days > 0 ? max(1, Int(ceil(Double(remaining) / Double(days)))) : 0)
    }

    func startToday() {
        startSession(
            key: "today",
            questions: Array(repository.questions.shuffled().prefix(todaySessionTarget)),
            title: "今日のスプリント",
            mode: .practice
        )
    }

    func startWeak() {
        startSession(key: "weak", questions: weakQuestions.shuffled(), title: "苦手をつぶす", mode: .practice)
    }

    func startDomain(_ domain: String) {
        startSession(
            key: "domain:\(domain)",
            questions: Array(repository.questions(domain: domain).shuffled().prefix(settings.dailyGoal)),
            title: domain,
            mode: .practice
        )
    }

    func startMock(edition: Int) {
        startSession(
            key: "exam:\(edition)",
            questions: repository.questions(edition: edition),
            title: "令和\(edition - 2018)年 模擬試験",
            mode: .mock
        )
    }

    func startEditionSubject(edition: Int, subject: String) {
        let questions = repository.questions(edition: edition).filter { $0.subject == subject }
        startSession(
            key: "exam:\(edition):subject:\(subject)",
            questions: questions,
            title: "令和\(edition - 2018)年・\(subject)",
            mode: .practice
        )
    }

    func retryQuestions(_ ids: [String], title: String) {
        startSession(
            key: "retry",
            questions: ids.compactMap { repository.question(id: $0) },
            title: title,
            mode: .practice
        )
    }

    func resumeSession() { session = state.inProgress; result = nil }

    func exitSessionToHome() {
        if let session {
            state.inProgress = session
            persist()
        }
        self.session = nil
        result = nil
        currentTab = .home
    }

    func currentQuestion() -> AppQuestion? {
        guard let session, session.questionIDs.indices.contains(session.index) else { return nil }
        return repository.question(id: session.questionIDs[session.index])
    }

    func response(for question: AppQuestion) -> SessionResponse? { session?.responses[question.id] }

    func submitAnswer(_ selectedIndex: Int?) {
        guard var session,
              let question = currentQuestion(),
              session.responses[question.id] == nil else { return }
        let isUnknown = selectedIndex == nil
        let correct = selectedIndex == question.correctIndex
        session.responses[question.id] = SessionResponse(
            selectedIndex: selectedIndex,
            isUnknown: isUnknown,
            correct: correct
        )
        self.session = session
        state.seenIDs.insert(question.id)
        updateWeak(question.id, correct: correct)
        state.answerLog.append(AnswerLogEntry(
            id: UUID(),
            questionID: question.id,
            answeredAt: Date(),
            responseIndex: selectedIndex,
            isUnknown: isUnknown,
            correct: correct,
            domain: question.domain,
            sessionKey: session.key,
            edition: question.edition
        ))
        if state.answerLog.count > 4000 {
            state.answerLog.removeFirst(state.answerLog.count - 4000)
        }
        state.inProgress = session
        persist()
    }

    func advanceSession() {
        guard var session,
              session.questionIDs.indices.contains(session.index),
              session.responses[session.questionIDs[session.index]] != nil else { return }
        if session.index + 1 < session.total {
            session.index += 1
            self.session = session
            state.inProgress = session
            persist()
        } else {
            complete(session)
        }
    }

    func completionCount(for key: String) -> Int { state.sessionCompletions[key, default: 0] }
    func latestCompletion(for key: String) -> CompletionRecord? { state.completionHistory.first { $0.key == key } }

    func domainStats(_ domain: String) -> (answered: Int, accuracy: Int) {
        let logs = state.answerLog.filter { $0.domain == domain }
        guard !logs.isEmpty else { return (0, 0) }
        return (logs.count, Int((Double(logs.filter(\.correct).count) / Double(logs.count) * 100).rounded()))
    }

    func resultDomainStats(_ result: SessionResult) -> [(domain: String, total: Int, correct: Int)] {
        var values: [String: (Int, Int)] = [:]
        for id in result.questionIDs {
            guard let question = repository.question(id: id), let response = result.responses[id] else { continue }
            let current = values[question.domain] ?? (0, 0)
            values[question.domain] = (current.0 + 1, current.1 + (response.correct ? 1 : 0))
        }
        return values.map { (domain: $0.key, total: $0.value.0, correct: $0.value.1) }
            .sorted { $0.domain < $1.domain }
    }

    func missedQuestionIDs(in result: SessionResult) -> [String] {
        result.questionIDs.filter { !(result.responses[$0]?.correct ?? false) }
    }

    func heatmap(days: Int = 35) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date, state.answerLog.filter { calendar.isDate($0.answeredAt, inSameDayAs: date) }.count)
        }
    }

    func setDailyGoal(_ value: Int) {
        guard [4, 8, 16].contains(value) else { return }
        state.settings.dailyGoal = value
        persist()
    }
    func setFontSize(_ value: FontSizePreference) { state.settings.fontSize = value; persist() }
    func setExamDate(_ value: Date?) { state.settings.examDate = value; persist() }

    func exportBackup() throws -> Data {
        try encoder.encode(BackupEnvelope(
            exportedAt: Date(),
            appNamespace: Self.backupNamespace,
            contentVersion: repository.payload.contentVersion,
            state: state
        ))
    }

    func importBackup(_ data: Data) throws {
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard envelope.appNamespace == Self.backupNamespace else { throw BackupError.wrongApp }
        let restored = Self.sanitize(envelope.state, repository: repository)
        state = restored
        session = restored.inProgress
        result = nil
        persist()
        importMessage = "バックアップを読み込みました。"
    }

    func clearImportMessage() { importMessage = nil }

    private func startSession(key: String, questions: [AppQuestion], title: String, mode: SessionMode) {
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
        result = nil
        state.inProgress = session
        persist()
    }

    private func updateWeak(_ id: String, correct: Bool) {
        if correct {
            guard var progress = state.weak[id] else { return }
            progress.streak += 1
            progress.lastUpdatedAt = Date()
            if progress.streak >= 3 {
                state.weak.removeValue(forKey: id)
            } else {
                state.weak[id] = progress
            }
        } else {
            state.weak[id] = WeakProgress(streak: 0, lastUpdatedAt: Date())
        }
    }

    private func complete(_ session: SessionState) {
        let result = SessionResult(
            key: session.key,
            title: session.title,
            mode: session.mode,
            questionIDs: session.questionIDs,
            responses: session.responses
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
        let directory = persistenceURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: persistenceURL, options: .atomic)
    }

    private static func sanitize(_ loaded: PersistedLearningState, repository: QuestionRepository) -> PersistedLearningState {
        var state = loaded
        let validIDs = Set(repository.questions.map(\.id))
        state.weak = state.weak.filter { validIDs.contains($0.key) }
        state.seenIDs = Set(state.seenIDs.filter { validIDs.contains($0) })
        state.answerLog = state.answerLog.filter { validIDs.contains($0.questionID) }
        if ![4, 8, 16].contains(state.settings.dailyGoal) {
            state.settings.dailyGoal = 8
        }
        if let inProgress = state.inProgress,
           inProgress.questionIDs.isEmpty || inProgress.questionIDs.contains(where: { !validIDs.contains($0) }) {
            state.inProgress = nil
        }
        if repository.payload.contentVersion != "missing" {
            state.contentVersion = repository.payload.contentVersion
        }
        return state
    }

    enum BackupError: LocalizedError {
        case wrongApp
        var errorDescription: String? { "このバックアップは不動産鑑定士試験・短答式用ではありません。" }
    }
}
