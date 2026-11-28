import Foundation

/// 学習記録：問題ごとの正誤・苦手・日別集計・セッション履歴を
/// UserDefaults に JSON で保存する。
/// 苦手の規則はシリーズ共通：不正解で登録（streak 0）、正解で streak+1、
/// 3回連続正解で解除。
@MainActor
final class StudyRecordStore: ObservableObject {
    static let storageKey = "hokenshi-study-record-v1"
    static let weakMasteryStreak = 3
    static let historyLimit = 20

    struct QuestionRecord: Codable {
        var attempts: Int = 0
        var correct: Int = 0
        var lastCorrect: Bool? = nil
        var lastAt: Date? = nil
    }

    struct WeakEntry: Codable {
        var streak: Int = 0
    }

    struct DayStat: Codable {
        var answered: Int = 0
        var correct: Int = 0
    }

    struct SessionRecord: Codable, Identifiable {
        var id: UUID = UUID()
        var date: Date = Date()
        var title: String = ""
        var score: Int = 0
        var total: Int = 0
    }

    struct SavedState: Codable {
        var records: [String: QuestionRecord] = [:]
        var weak: [String: WeakEntry] = [:]
        var days: [String: DayStat] = [:]
        var history: [SessionRecord] = []
    }

    @Published private(set) var state = SavedState()

    init() {
        load()
    }

    // MARK: - 集計

    var totalAnswered: Int {
        state.records.values.reduce(0) { $0 + $1.attempts }
    }

    var totalCorrect: Int {
        state.records.values.reduce(0) { $0 + $1.correct }
    }

    var studiedCount: Int {
        state.records.values.filter { $0.attempts > 0 }.count
    }

    var accuracy: Int {
        guard totalAnswered > 0 else { return 0 }
        return Int(Double(totalCorrect) / Double(totalAnswered) * 100)
    }

    var weakIDs: [String] {
        Array(state.weak.keys)
    }

    var weakCount: Int {
        state.weak.count
    }

    var todayAnswered: Int {
        state.days[Self.dayKey(Date())]?.answered ?? 0
    }

    func isWeak(_ questionID: String) -> Bool {
        state.weak[questionID] != nil
    }

    /// 苦手な問題をデータ順に返す。
    func weakQuestions() -> [Question] {
        let ids = Set(weakIDs)
        return QuestionStore.shared.questions.filter { ids.contains($0.id) }
    }

    struct SetStats {
        var total: Int = 0
        var studied: Int = 0
        var attempts: Int = 0
        var correct: Int = 0
        var weak: Int = 0

        var accuracy: Int {
            guard attempts > 0 else { return 0 }
            return Int(Double(correct) / Double(attempts) * 100)
        }
    }

    func stats(for questions: [Question]) -> SetStats {
        var stats = SetStats(total: questions.count)
        for question in questions {
            if let record = state.records[question.id], record.attempts > 0 {
                stats.studied += 1
                stats.attempts += record.attempts
                stats.correct += record.correct
            }
            if state.weak[question.id] != nil { stats.weak += 1 }
        }
        return stats
    }

    // MARK: - 記録

    func record(questionID: String, correct: Bool) {
        var record = state.records[questionID] ?? QuestionRecord()
        record.attempts += 1
        if correct {
            record.correct += 1
            record.lastCorrect = true
            if var weak = state.weak[questionID] {
                weak.streak += 1
                if weak.streak >= Self.weakMasteryStreak {
                    state.weak.removeValue(forKey: questionID)
                } else {
                    state.weak[questionID] = weak
                }
            }
        } else {
            record.lastCorrect = false
            state.weak[questionID] = WeakEntry(streak: 0)
        }
        record.lastAt = Date()
        state.records[questionID] = record

        let key = Self.dayKey(Date())
        var day = state.days[key] ?? DayStat()
        day.answered += 1
        if correct { day.correct += 1 }
        state.days[key] = day
        save()
    }

    func addSession(title: String, score: Int, total: Int) {
        var entry = SessionRecord()
        entry.title = title
        entry.score = score
        entry.total = total
        state.history.insert(entry, at: 0)
        if state.history.count > Self.historyLimit {
            state.history = Array(state.history.prefix(Self.historyLimit))
        }
        save()
    }

    func resetAll() {
        state = SavedState()
        save()
    }

    // MARK: - 永続化

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            state = try JSONDecoder().decode(SavedState.self, from: data)
        } catch {
            state = SavedState()
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // 保存に失敗しても学習は継続する。
        }
    }
}
