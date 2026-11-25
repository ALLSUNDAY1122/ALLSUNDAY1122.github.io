import Foundation

/// 学習記録：回答履歴・苦手・日別集計・セッション履歴を UserDefaults に JSON で保存する。
/// 苦手は FP2 と同じ規則：不正解で登録（streak 0）、正解で streak+1、3回連続正解で解除。
@MainActor
final class StudyRecordStore: ObservableObject {
    static let storageKey = "itp-study-record-v1"
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

    var todayCorrect: Int {
        state.days[Self.dayKey(Date())]?.correct ?? 0
    }

    /// 苦手問題を問題バンク順に返す。
    func weakQuestions() -> [StudyQuestion] {
        let ids = Set(weakIDs)
        return QuestionStore.accessible(premium: true).filter { ids.contains($0.id) }
    }

    // MARK: - 記録

    func record(questionId: String, correct: Bool) {
        var record = state.records[questionId] ?? QuestionRecord()
        record.attempts += 1
        if correct {
            record.correct += 1
            record.lastCorrect = true
            if var weak = state.weak[questionId] {
                weak.streak += 1
                if weak.streak >= Self.weakMasteryStreak {
                    state.weak.removeValue(forKey: questionId)
                } else {
                    state.weak[questionId] = weak
                }
            }
        } else {
            record.lastCorrect = false
            state.weak[questionId] = WeakEntry(streak: 0)
        }
        record.lastAt = Date()
        state.records[questionId] = record

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
            // 保存に失敗しても学習は継続する。次回起動時に読み込めない場合がある。
        }
    }
}
