import Foundation

/// 学習記録：読みクイズの正誤・書き完了・苦手・日別集計・セッション履歴を
/// UserDefaults に JSON で保存する。
/// 苦手の規則は ITパスポート版と同じ：不正解で登録（streak 0）、
/// 正解で streak+1、3回連続正解で解除。
@MainActor
final class StudyRecordStore: ObservableObject {
    static let storageKey = "kanji-study-record-v1"
    static let weakMasteryStreak = 3
    static let historyLimit = 20

    struct KanjiRecord: Codable {
        var attempts: Int = 0
        var correct: Int = 0
        var lastCorrect: Bool? = nil
        var lastAt: Date? = nil
    }

    struct WeakEntry: Codable {
        var streak: Int = 0
    }

    struct WritingRecord: Codable {
        var completions: Int = 0
        var lastAt: Date? = nil
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
        var records: [String: KanjiRecord] = [:]
        var weak: [String: WeakEntry] = [:]
        var writing: [String: WritingRecord] = [:]
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

    /// 書き練習を1回以上完了した字の数。
    var writingDoneCount: Int {
        state.writing.values.filter { $0.completions > 0 }.count
    }

    var todayAnswered: Int {
        state.days[Self.dayKey(Date())]?.answered ?? 0
    }

    /// 読み・書きのどちらかで学習済みの字か。
    func isStudied(_ kanji: String) -> Bool {
        (state.records[kanji]?.attempts ?? 0) > 0 || (state.writing[kanji]?.completions ?? 0) > 0
    }

    func isWeak(_ kanji: String) -> Bool {
        state.weak[kanji] != nil
    }

    func writingCompletions(_ kanji: String) -> Int {
        state.writing[kanji]?.completions ?? 0
    }

    /// 苦手な字をデータ順に返す。
    func weakKanji() -> [KanjiEntry] {
        let ids = Set(weakIDs)
        return KanjiStore.shared.entries.filter { ids.contains($0.kanji) }
    }

    /// 学年の集計：字数・学習済み数・試行数・正解試行数・苦手数・書き完了数。
    struct GradeStats {
        var total: Int = 0
        var studied: Int = 0
        var attempts: Int = 0
        var correct: Int = 0
        var weak: Int = 0
        var writingDone: Int = 0

        var accuracy: Int {
            guard attempts > 0 else { return 0 }
            return Int(Double(correct) / Double(attempts) * 100)
        }
    }

    func gradeStats(_ grade: Int) -> GradeStats {
        let list = KanjiStore.shared.byGrade[grade] ?? []
        var stats = GradeStats(total: list.count)
        for entry in list {
            if isStudied(entry.kanji) { stats.studied += 1 }
            if let record = state.records[entry.kanji] {
                stats.attempts += record.attempts
                stats.correct += record.correct
            }
            if state.weak[entry.kanji] != nil { stats.weak += 1 }
            if (state.writing[entry.kanji]?.completions ?? 0) > 0 { stats.writingDone += 1 }
        }
        return stats
    }

    // MARK: - 記録

    func record(kanji: String, correct: Bool) {
        var record = state.records[kanji] ?? KanjiRecord()
        record.attempts += 1
        if correct {
            record.correct += 1
            record.lastCorrect = true
            if var weak = state.weak[kanji] {
                weak.streak += 1
                if weak.streak >= Self.weakMasteryStreak {
                    state.weak.removeValue(forKey: kanji)
                } else {
                    state.weak[kanji] = weak
                }
            }
        } else {
            record.lastCorrect = false
            state.weak[kanji] = WeakEntry(streak: 0)
        }
        record.lastAt = Date()
        state.records[kanji] = record

        let key = Self.dayKey(Date())
        var day = state.days[key] ?? DayStat()
        day.answered += 1
        if correct { day.correct += 1 }
        state.days[key] = day
        save()
    }

    func recordWriting(kanji: String) {
        var writing = state.writing[kanji] ?? WritingRecord()
        writing.completions += 1
        writing.lastAt = Date()
        state.writing[kanji] = writing
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
            // 保存に失敗しても学習は継続する。次回起動時に読み込めない場合がある。
        }
    }
}
