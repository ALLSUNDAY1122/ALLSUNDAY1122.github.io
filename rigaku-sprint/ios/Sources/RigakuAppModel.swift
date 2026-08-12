import Combine
import Foundation
import LearningSprintCore

@MainActor
final class RigakuAppModel: ObservableObject {
    @Published private(set) var state: LearningState
    @Published private(set) var questions: [LearningQuestion] = []
    @Published var lastError: String?

    private let store: LearningStateStore?

    init(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.state = LearningState(contentVersion: RigakuAppConfiguration.contentVersion)

        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            let store = LearningStateStore(
                bundleID: bundleIdentifier,
                contentVersion: RigakuAppConfiguration.contentVersion
            )
            self.store = store
            do {
                self.state = try store.load()
            } catch {
                self.lastError = "学習データを読み込めませんでした。"
            }
        } else {
            self.store = nil
            self.lastError = "Bundle IDが未確定のため、学習データ保存は開発ゲート中です。"
        }

        do {
            self.questions = try RigakuQuestionRepository.loadBundled()
        } catch {
            self.questions = []
            if self.lastError == nil {
                self.lastError = "監査済み問題データを読み込めませんでした。"
            }
        }
    }

    var todayAnsweredCount: Int {
        LearningEngine.todayAnsweredCount(state: state)
    }

    var dailyProgress: Double {
        guard state.dailyTarget > 0 else { return 0 }
        return min(1, Double(todayAnsweredCount) / Double(state.dailyTarget))
    }

    var weakCount: Int {
        state.weakQuestions.count
    }

    var accuracy: Double? {
        guard !state.attempts.isEmpty else { return nil }
        return Double(state.attempts.filter(\.isCorrect).count) / Double(state.attempts.count)
    }

    var heatmap: [Date: Int] {
        LearningEngine.heatmap35Days(state: state)
    }

    var uniqueAnsweredCount: Int {
        Set(state.attempts.map(\.questionID)).count
    }

    var requiredDailyPace: Int? {
        LearningEngine.requiredDailyPace(
            totalQuestionCount: questions.count,
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

    func exportBackup() throws -> Data {
        guard let store else {
            throw CocoaError(.fileWriteUnknown, userInfo: [
                NSLocalizedDescriptionKey: "Bundle ID確定後にバックアップを利用できます。"
            ])
        }
        return try store.exportBackup(state)
    }

    func importBackup(_ data: Data) throws {
        guard let store else {
            throw CocoaError(.fileReadUnknown, userInfo: [
                NSLocalizedDescriptionKey: "Bundle ID確定後にバックアップを利用できます。"
            ])
        }
        state = try store.importBackup(data)
        lastError = nil
    }

    func clearError() {
        lastError = nil
    }

    private func persist() {
        guard let store else { return }
        do {
            try store.save(state)
            lastError = nil
        } catch {
            lastError = "学習データを保存できませんでした。"
        }
    }
}

enum RigakuQuestionRepository {
    static func loadBundled(bundle: Bundle = .main) throws -> [LearningQuestion] {
        guard let url = bundle.url(forResource: "questions", withExtension: "json") else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([LearningQuestion].self, from: data)
    }
}
