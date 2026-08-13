#if canImport(SwiftUI)
import Foundation
import SwiftUI
import Combine
import LearningSprintCore

public struct HokenshiSessionPresentation: Identifiable {
    public let id = UUID()
    public let kind: SessionKind
    public let title: String
    public let questions: [LearningQuestion]
    public let startIndex: Int

    public init(kind: SessionKind, title: String, questions: [LearningQuestion], startIndex: Int = 0) {
        self.kind = kind
        self.title = title
        self.questions = questions
        self.startIndex = startIndex
    }
}

public enum HokenshiMockSegment: String, CaseIterable, Sendable {
    case morning = "午前55"
    case afternoon = "午後55"
    case full = "通し110"
}

@MainActor
public final class HokenshiProductModel: ObservableObject {
    @Published public private(set) var contentStore: HokenshiContentStore?
    @Published public var state: LearningState
    @Published public var activeSession: HokenshiSessionPresentation?
    @Published public var showPaywall = false
    @Published public private(set) var loadError: String?
    @Published public private(set) var lastSessionCorrect = 0
    @Published public private(set) var lastSessionUnknown = 0
    @Published public private(set) var lastSessionTotal = 0

    public let purchaseController: PurchaseController
    private let stateStore: LearningStateStore
    private var purchaseObserver: AnyCancellable?

    public init() {
        let persistence = LearningStateStore(
            bundleID: HokenshiReleaseContentStore.stateNamespace,
            contentVersion: HokenshiReleaseContentStore.contentVersion
        )
        stateStore = persistence
        purchaseController = PurchaseController(productID: HokenshiMonetization.productID)
        state = (try? persistence.load()) ?? LearningState(contentVersion: HokenshiReleaseContentStore.contentVersion)
        do {
            contentStore = try HokenshiReleaseContentStore.load()
        } catch {
            contentStore = nil
            loadError = "監査済み問題データを読み込めませんでした。"
        }
        purchaseObserver = purchaseController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    public var allQuestions: [LearningQuestion] {
        contentStore?.allRecords.map(\.displayQuestion) ?? []
    }

    public var isPremium: Bool { purchaseController.isPremium }
    public var freeQuestionCount: Int { allQuestions.filter { !$0.premium }.count }
    public var premiumQuestionCount: Int { allQuestions.filter(\.premium).count }
    public var todayAnsweredCount: Int { LearningEngine.todayAnsweredCount(state: state) }

    public var accuracy: Double? {
        guard !state.attempts.isEmpty else { return nil }
        return Double(state.attempts.filter(\.isCorrect).count) / Double(state.attempts.count)
    }

    public var uniqueAnsweredCount: Int { Set(state.attempts.map(\.questionID)).count }

    public var requiredDailyPace: Int? {
        LearningEngine.requiredDailyPace(
            totalQuestionCount: allQuestions.count,
            uniqueAnsweredCount: uniqueAnsweredCount,
            examDate: state.examDate
        )
    }

    public var canResume: Bool {
        guard let snapshot = state.resumeSession else { return false }
        return snapshot.currentIndex >= 0 && snapshot.currentIndex < snapshot.questionIDs.count
    }

    public var heatmap: [Date: Int] { LearningEngine.heatmap35Days(state: state) }
    public var subjectAccuracy: [String: Double] { LearningEngine.subjectAccuracy(state: state) }

    public func startSprint() {
        begin(
            kind: .sprint,
            title: "今日のスプリント",
            questions: LearningEngine.selectSprint(
                from: allQuestions,
                target: state.dailyTarget,
                isPremium: purchaseController.isPremium
            )
        )
    }

    public func startWeak() {
        begin(
            kind: .weak,
            title: "苦手復習",
            questions: LearningEngine.selectWeak(
                from: allQuestions,
                state: state,
                target: state.dailyTarget,
                isPremium: purchaseController.isPremium
            )
        )
    }

    public func startSubject(_ subject: String) {
        let pool = contentStore?.questions(subject: subject).map(\.displayQuestion) ?? []
        begin(
            kind: .subject(subject),
            title: subject,
            questions: LearningEngine.selectSprint(
                from: pool,
                target: state.dailyTarget,
                isPremium: purchaseController.isPremium
            )
        )
    }

    public func startMock(round: Int, segment: HokenshiMockSegment) {
        guard purchaseController.isPremium else {
            showPaywall = true
            return
        }
        guard let rows = contentStore?.questions(round: round), rows.count == 110 else { return }
        let selected: [HokenshiQuestionRecord]
        switch segment {
        case .morning: selected = Array(rows.prefix(55))
        case .afternoon: selected = Array(rows.suffix(55))
        case .full: selected = rows
        }
        begin(
            kind: .mock("R\(round)-\(segment.rawValue)"),
            title: "独自模試 第\(round)回・\(segment.rawValue)",
            questions: selected.map(\.displayQuestion)
        )
    }

    public func requestPremium() {
        showPaywall = true
    }

    public func resume() {
        guard let snapshot = state.resumeSession else { return }
        let byID = Dictionary(uniqueKeysWithValues: allQuestions.map { ($0.id, $0) })
        let questions = snapshot.questionIDs.compactMap { byID[$0] }
        guard questions.count == snapshot.questionIDs.count,
              !questions.isEmpty,
              snapshot.currentIndex < questions.count
        else {
            state.resumeSession = nil
            persist()
            return
        }
        if !purchaseController.isPremium && questions.contains(where: \.premium) {
            showPaywall = true
            return
        }
        activeSession = HokenshiSessionPresentation(
            kind: snapshot.kind,
            title: title(for: snapshot.kind),
            questions: questions,
            startIndex: snapshot.currentIndex
        )
    }

    public func commitAdvance(
        question: LearningQuestion,
        answer: AnswerPayload,
        evaluation: AnswerEvaluation,
        nextIndex: Int,
        total: Int
    ) -> [AnswerEvaluation]? {
        guard var snapshot = state.resumeSession,
              snapshot.questionIDs.contains(question.id)
        else { return nil }

        LearningEngine.record(question: question, evaluation: evaluation, state: &state)
        snapshot.answers[question.id] = answer
        snapshot.currentIndex = min(nextIndex, total)

        if nextIndex >= total {
            let byID = Dictionary(uniqueKeysWithValues: allQuestions.map { ($0.id, $0) })
            let results: [AnswerEvaluation] = snapshot.questionIDs.compactMap { id in
                guard let q = byID[id], let saved = snapshot.answers[id] else { return nil }
                return try? LearningEngine.evaluate(q, answer: saved)
            }
            guard results.count == snapshot.questionIDs.count else {
                loadError = "学習結果の集計に失敗しました。"
                state.resumeSession = snapshot
                persist()
                return nil
            }
            state.recordCompletion(for: snapshot.kind)
            state.resumeSession = nil
            lastSessionCorrect = results.filter(\.isCorrect).count
            lastSessionUnknown = results.filter(\.isUnknown).count
            lastSessionTotal = results.count
            persist()
            return results
        }

        state.resumeSession = snapshot
        persist()
        return nil
    }

    public func closeActiveSession(keepForResume: Bool) {
        if !keepForResume {
            state.resumeSession = nil
            persist()
        }
        activeSession = nil
    }

    public func setDailyTarget(_ target: Int) {
        guard LearningState.validTarget(target) else { return }
        state.dailyTarget = target
        persist()
    }

    public func setExamDate(_ date: Date?) {
        state.examDate = date
        persist()
    }

    public func setTextSizeStep(_ step: Int) {
        state.textSizeStep = min(2, max(0, step))
        persist()
    }

    public func exportBackup() throws -> Data { try stateStore.exportBackup(state) }

    public func importBackup(_ data: Data) throws {
        state = try stateStore.importBackup(data, allowContentVersionMigration: true)
    }

    private func begin(kind: SessionKind, title: String, questions: [LearningQuestion]) {
        guard !questions.isEmpty else {
            if !purchaseController.isPremium { showPaywall = true }
            return
        }
        state.resumeSession = LearningSessionSnapshot(kind: kind, questionIDs: questions.map(\.id))
        persist()
        activeSession = HokenshiSessionPresentation(kind: kind, title: title, questions: questions)
    }

    private func title(for kind: SessionKind) -> String {
        switch kind {
        case .sprint: return "今日のスプリント"
        case .weak: return "苦手復習"
        case .subject(let subject): return subject
        case .mock(let name): return "独自模試 \(name)"
        }
    }

    private func persist() {
        do { try stateStore.save(state) }
        catch { loadError = "学習記録を保存できませんでした。" }
    }
}
#endif
