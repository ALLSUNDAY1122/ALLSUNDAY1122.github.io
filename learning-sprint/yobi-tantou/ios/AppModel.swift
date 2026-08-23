import Foundation

@MainActor
final class AppModel: ObservableObject {
    struct ActiveSession: Equatable {
        let ids: [String]
        var index: Int
        var correct: Int
        let title: String
        let consumesFreeSprint: Bool
        let requiresPremium: Bool
    }

    @Published private(set) var questions: [StudyQuestion] = []
    @Published private(set) var officialScoringCanonical: OfficialScoringCanonical?
    @Published var state = PersistentState()
    @Published var activeSession: ActiveSession?
    @Published var lastResult: SessionResult?
    @Published var startupError: String?

    static let officialSubjects = ["憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法", "一般教養"]

    private let defaultsKey = "yobi_tantou_sprint_state_v1"

    init(bundle: Bundle = .main) {
        loadState()
        loadQuestions(bundle: bundle)
        loadOfficialScoring(bundle: bundle)
    }

    var currentQuestion: StudyQuestion? {
        guard let session = activeSession, session.index < session.ids.count else { return nil }
        return questions.first { $0.id == session.ids[session.index] }
    }

    var currentIndex: Int { activeSession?.index ?? 0 }
    var sessionCount: Int { activeSession?.ids.count ?? 0 }
    var weakCount: Int { state.attempts.values.filter(\.weak).count }
    var unknownCount: Int { state.attempts.values.filter(\.unknown).count }
    var overallAccuracy: Double {
        guard state.totalAnswered > 0 else { return 0 }
        return Double(state.totalCorrect) / Double(state.totalAnswered)
    }
    var todayAnswered: Int { dayStat(Date()).answered }
    var isPreviewBank: Bool { !questions.contains(where: \.releaseEligible) }
    var officialScoringYears: [Int] {
        guard let canonical = officialScoringCanonical else { return [] }
        return canonical.years.keys.compactMap(Int.init).sorted(by: >)
    }

    func subjects() -> [String] { Self.officialSubjects }

    func questionCount(subject: String) -> Int {
        questions.filter { $0.subject == subject && $0.releaseEligible && $0.isPracticeQuestion }.count
    }

    func mockSelectionSummary(year: Int) -> MockSelectionSummary {
        let yearQuestions = questions.filter {
            $0.releaseEligible && $0.isOfficialMockQuestion && $0.examYear == year
        }
        return MockSelectionPolicy.summary(for: yearQuestions)
    }

    func officialScoring(year: Int) -> OfficialYearScoring? {
        guard let canonical = officialScoringCanonical else { return nil }
        return try? OfficialScoringRepository.scoring(for: year, canonical: canonical)
    }

    func subjectAccuracy(_ subject: String) -> Double {
        let ids = Set(questions.filter { $0.subject == subject }.map(\.id))
        let attempts = state.attempts.filter { ids.contains($0.key) }.map(\.value)
        let answered = attempts.reduce(0) { $0 + $1.answered }
        guard answered > 0 else { return 0 }
        return Double(attempts.reduce(0) { $0 + $1.correct }) / Double(answered)
    }

    func dayStat(_ date: Date) -> DayStat {
        state.dailyStats[DateFormatter.sprintDayKey.string(from: date)] ?? DayStat()
    }

    @discardableResult
    func start(_ descriptor: SessionDescriptor, premium: Bool) -> Bool {
        lastResult = nil
        let eligible = learningEligibleQuestions()
        let chosen: [StudyQuestion]
        let title: String
        let consumesFreeSprint: Bool
        let requiresPremium: Bool

        switch descriptor {
        case .daily:
            guard premium || !state.freeSprintConsumed else { return false }
            chosen = Array(eligible.shuffled().prefix(min(state.dailyGoal, eligible.count)))
            title = isPreviewBank ? "開発プレビュー" : "今日のスプリント"
            consumesFreeSprint = !premium
            requiresPremium = false
        case .weak:
            guard premium else { return false }
            chosen = eligible.filter { state.attempts[$0.id]?.weak == true }
            title = "苦手をつぶす"
            consumesFreeSprint = false
            requiresPremium = true
        case .subject(let subject):
            guard premium else { return false }
            chosen = eligible.filter { $0.subject == subject }
            title = subject
            consumesFreeSprint = false
            requiresPremium = true
        case .mock(let year):
            guard premium else { return false }
            let yearQuestions = questions.filter {
                $0.releaseEligible && $0.isOfficialMockQuestion && $0.examYear == year
            }
            chosen = MockSelectionPolicy.select(from: yearQuestions)
            title = "令和\(year - 2018)年 模擬試験"
            consumesFreeSprint = false
            requiresPremium = true
        }

        guard !chosen.isEmpty else { return false }
        activeSession = ActiveSession(
            ids: chosen.map(\.id),
            index: 0,
            correct: 0,
            title: title,
            consumesFreeSprint: consumesFreeSprint,
            requiresPremium: requiresPremium
        )
        if consumesFreeSprint {
            state.freeSprintConsumed = true
        }
        persistResume()
        return true
    }

    @discardableResult
    func resume(premium: Bool) -> Bool {
        guard let resume = state.resume else { return false }
        let requiresPremium = resume.resolvedRequiresPremium
        if requiresPremium && !premium { return false }

        let usesFreeAccess = !premium && !requiresPremium
        if usesFreeAccess && state.freeSprintConsumed && !resume.consumesFreeSprint {
            return false
        }

        let validIDs = resume.questionIDs.filter { id in questions.contains { $0.id == id } }
        guard validIDs.count == resume.questionIDs.count,
              !validIDs.isEmpty,
              resume.index >= 0,
              resume.index < validIDs.count,
              resume.correct >= 0,
              resume.correct <= resume.index else {
            state.resume = nil
            saveState()
            return false
        }

        activeSession = ActiveSession(
            ids: validIDs,
            index: resume.index,
            correct: resume.correct,
            title: resume.title,
            consumesFreeSprint: usesFreeAccess,
            requiresPremium: requiresPremium
        )
        if usesFreeAccess {
            state.freeSprintConsumed = true
        }
        persistResume()
        return true
    }

    func answer(selectedIndices: Set<Int>) {
        guard let question = currentQuestion, var session = activeSession else { return }
        let correct = selectedIndices == Set(question.correctIndices)

        var attempt = state.attempts[question.id] ?? AttemptState()
        attempt.answered += 1
        if correct {
            attempt.correct += 1
            attempt.consecutiveCorrect += 1
            if attempt.consecutiveCorrect >= 3 { attempt.weak = false }
            session.correct += 1
        } else {
            attempt.consecutiveCorrect = 0
            attempt.weak = true
        }
        state.attempts[question.id] = attempt
        state.totalAnswered += 1
        if correct { state.totalCorrect += 1 }

        let key = DateFormatter.sprintDayKey.string(from: Date())
        var day = state.dailyStats[key] ?? DayStat()
        day.answered += 1
        if correct { day.correct += 1 }
        state.dailyStats[key] = day

        session.index += 1
        if session.index >= session.ids.count {
            lastResult = SessionResult(title: session.title, answered: session.ids.count, correct: session.correct)
            activeSession = nil
            state.resume = nil
        } else {
            activeSession = session
            persistResume()
        }
        saveState()
    }

    func toggleUnknown() {
        guard let question = currentQuestion else { return }
        var attempt = state.attempts[question.id] ?? AttemptState()
        attempt.unknown.toggle()
        state.attempts[question.id] = attempt
        saveState()
    }

    func isUnknown(_ id: String) -> Bool { state.attempts[id]?.unknown == true }
    func dismissResult() { lastResult = nil }

    func setDailyGoal(_ goal: Int) {
        guard [4, 8, 16].contains(goal) else { return }
        state.dailyGoal = goal
        saveState()
    }

    func setTextSize(_ value: String) {
        guard ["small", "medium", "large"].contains(value) else { return }
        state.selectedTextSize = value
        saveState()
    }

    func setExamDate(_ date: Date?) {
        state.examDate = date
        saveState()
    }

    func backupData() throws -> Data {
        let payload = BackupPayload(schemaVersion: 1, exportedAt: Date(), state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    func importBackup(_ data: Data) throws {
        guard data.count <= 5 * 1024 * 1024 else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        guard payload.schemaVersion == 1,
              [4, 8, 16].contains(payload.state.dailyGoal),
              ["small", "medium", "large"].contains(payload.state.selectedTextSize),
              payload.state.totalCorrect <= payload.state.totalAnswered,
              payload.state.attempts.values.allSatisfy({ $0.correct <= $0.answered }),
              Self.isValidResume(payload.state.resume) else {
            throw BackupError.invalid
        }
        let paidGateState = state.freeSprintConsumed
        state = payload.state
        state.freeSprintConsumed = paidGateState || payload.state.freeSprintConsumed
        activeSession = nil
        lastResult = nil
        saveState()
    }

    func resetLearningData() {
        let paidGateState = state.freeSprintConsumed
        let goal = state.dailyGoal
        let size = state.selectedTextSize
        let date = state.examDate
        state = PersistentState()
        state.freeSprintConsumed = paidGateState
        state.dailyGoal = goal
        state.selectedTextSize = size
        state.examDate = date
        activeSession = nil
        lastResult = nil
        saveState()
    }

    private static func isValidResume(_ resume: ResumeState?) -> Bool {
        guard let resume else { return true }
        return !resume.questionIDs.isEmpty
            && Set(resume.questionIDs).count == resume.questionIDs.count
            && resume.index >= 0
            && resume.index < resume.questionIDs.count
            && resume.correct >= 0
            && resume.correct <= resume.index
            && !resume.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func learningEligibleQuestions() -> [StudyQuestion] {
        let releasedPractice = questions.filter { $0.releaseEligible && $0.isPracticeQuestion }
        return releasedPractice.isEmpty ? questions.filter { $0.originType == "original_preview" } : releasedPractice
    }

    private func persistResume() {
        guard let session = activeSession else { return }
        state.resume = ResumeState(
            questionIDs: session.ids,
            index: session.index,
            correct: session.correct,
            title: session.title,
            consumesFreeSprint: session.consumesFreeSprint,
            requiresPremium: session.requiresPremium
        )
        saveState()
    }

    private func loadQuestions(bundle: Bundle) {
        do {
            questions = try QuestionRepository().load(bundle: bundle)
        } catch {
            startupError = error.localizedDescription
        }
    }

    private func loadOfficialScoring(bundle: Bundle) {
        do {
            officialScoringCanonical = try OfficialScoringRepository.load(bundle: bundle)
        } catch {
            if startupError == nil {
                startupError = error.localizedDescription
            }
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            state = try decoder.decode(PersistentState.self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) { UserDefaults.standard.set(data, forKey: defaultsKey) }
    }
}

enum BackupError: LocalizedError {
    case tooLarge
    case invalid

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "バックアップは5MB以下にしてください。"
        case .invalid: return "このバックアップ形式は読み込めません。"
        }
    }
}
