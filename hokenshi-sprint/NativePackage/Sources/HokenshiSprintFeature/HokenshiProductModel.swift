#if canImport(SwiftUI)
import Foundation
import SwiftUI
import LearningSprintCore

public struct HokenshiSessionPresentation: Identifiable {
    public let id = UUID()
    public let kind: SessionKind
    public let title: String
    public let questions: [LearningQuestion]

    public init(kind: SessionKind, title: String, questions: [LearningQuestion]) {
        self.kind = kind
        self.title = title
        self.questions = questions
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
    @Published public private(set) var loadError: String?
    @Published public private(set) var lastSessionCorrect = 0
    @Published public private(set) var lastSessionTotal = 0

    private let stateStore: LearningStateStore

    public init() {
        let persistence = LearningStateStore(
            bundleID: HokenshiReleaseContentStore.stateNamespace,
            contentVersion: HokenshiReleaseContentStore.contentVersion
        )
        self.stateStore = persistence
        self.state = (try? persistence.load()) ?? LearningState(
            contentVersion: HokenshiReleaseContentStore.contentVersion
        )
        do {
            self.contentStore = try HokenshiReleaseContentStore.load()
        } catch {
            self.contentStore = nil
            self.loadError = "監査済み問題データを読み込めませんでした。"
        }
    }

    public var allQuestions: [LearningQuestion] {
        contentStore?.productQuestions ?? []
    }

    public var todayAnsweredCount: Int {
        LearningEngine.todayAnsweredCount(state: state)
    }

    public var accuracy: Double? {
        guard !state.attempts.isEmpty else { return nil }
        return Double(state.attempts.filter(\.isCorrect).count) / Double(state.attempts.count)
    }

    public var uniqueAnsweredCount: Int {
        Set(state.attempts.map(\.questionID)).count
    }

    public var requiredDailyPace: Int? {
        LearningEngine.requiredDailyPace(
            totalQuestionCount: allQuestions.count,
            uniqueAnsweredCount: uniqueAnsweredCount,
            examDate: state.examDate
        )
    }

    public var canResume: Bool {
        guard let snapshot = state.resumeSession else { return false }
        return !snapshot.questionIDs.isEmpty
    }

    public var heatmap: [Date: Int] {
        LearningEngine.heatmap35Days(state: state)
    }

    public var subjectAccuracy: [String: Double] {
        LearningEngine.subjectAccuracy(state: state)
    }

    public func startSprint() {
        let selected = LearningEngine.selectSprint(
            from: allQuestions,
            target: state.dailyTarget,
            isPremium: true
        )
        begin(kind: .sprint, title: "今日のスプリント", questions: selected)
    }

    public func startWeak() {
        let selected = LearningEngine.selectWeak(
            from: allQuestions,
            state: state,
            target: state.dailyTarget,
            isPremium: true
        )
        begin(kind: .weak, title: "苦手復習", questions: selected)
    }

    public func startSubject(_ subject: String) {
        let pool = contentStore?.questions(subject: subject).map(\.coreQuestion) ?? []
        let selected = LearningEngine.selectSprint(
            from: pool,
            target: state.dailyTarget,
            isPremium: true
        )
        begin(kind: .subject(subject), title: subject, questions: selected)
    }

    public func startMock(round: Int, segment: HokenshiMockSegment) {
        guard let rows = contentStore?.questions(round: round), rows.count == 110 else { return }
        let selected: [HokenshiQuestionRecord]
        switch segment {
        case .morning:
            selected = Array(rows.prefix(55))
        case .afternoon:
            selected = Array(rows.suffix(55))
        case .full:
            selected = rows
        }
        begin(
            kind: .mock("R\(round)-\(segment.rawValue)"),
            title: "独自模試 第\(round)回・\(segment.rawValue)",
            questions: selected.map(\.coreQuestion)
        )
    }

    public func resume() {
        guard let snapshot = state.resumeSession else { return }
        let byID = Dictionary(uniqueKeysWithValues: allQuestions.map { ($0.id, $0) })
        let questions = snapshot.questionIDs.compactMap { byID[$0] }
        guard questions.count == snapshot.questionIDs.count, !questions.isEmpty else {
            state.resumeSession = nil
            persist()
            return
        }
        activeSession = HokenshiSessionPresentation(
            kind: snapshot.kind,
            title: title(for: snapshot.kind),
            questions: questions
        )
    }

    public func finishActiveSession(_ evaluations: [AnswerEvaluation]) {
        guard let session = activeSession else { return }
        for (question, evaluation) in zip(session.questions, evaluations) {
            LearningEngine.record(question: question, evaluation: evaluation, state: &state)
        }
        state.recordCompletion(for: session.kind)
        state.resumeSession = nil
        lastSessionCorrect = evaluations.filter(\.isCorrect).count
        lastSessionTotal = evaluations.count
        persist()
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

    public func exportBackup() throws -> Data {
        try stateStore.exportBackup(state)
    }

    public func importBackup(_ data: Data) throws {
        state = try stateStore.importBackup(data, allowContentVersionMigration: true)
    }

    private func begin(kind: SessionKind, title: String, questions: [LearningQuestion]) {
        guard !questions.isEmpty else { return }
        state.resumeSession = LearningSessionSnapshot(
            kind: kind,
            questionIDs: questions.map(\.id)
        )
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
        do {
            try stateStore.save(state)
        } catch {
            loadError = "学習記録を保存できませんでした。"
        }
    }
}
#endif
