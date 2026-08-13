import Foundation
import SwiftUI
import LearningSprintCore

public enum JosanshiFeatureTab: Hashable, Sendable {
    case home
    case mock
    case history
    case settings
}

@MainActor
public final class JosanshiDashboardModel: ObservableObject {
    @Published public var selectedTab: JosanshiFeatureTab = .home
    @Published public private(set) var dailyTarget: Int
    @Published public var selectedSubject: String?
    @Published public var isContentGatePresented = false
    @Published public var isSessionPresented = false
    @Published public private(set) var contentErrorDescription: String?

    public let coordinator: JosanshiLearningCoordinator
    public private(set) var questionBank: JosanshiQuestionBankDocument?

    public init(
        questionBank: JosanshiQuestionBankDocument? = nil,
        coordinator injectedCoordinator: JosanshiLearningCoordinator? = nil,
        usePersistentStore: Bool = true
    ) {
        var resolvedBank = questionBank
        var loadError: String?
        if resolvedBank == nil {
            do {
                resolvedBank = try JosanshiQuestionBankLoader.bundled()
            } catch {
                loadError = error.localizedDescription
            }
        }

        let learningQuestions: [LearningQuestion]
        do {
            learningQuestions = try resolvedBank?.learningQuestions() ?? []
        } catch {
            learningQuestions = []
            loadError = error.localizedDescription
            resolvedBank = nil
        }

        if let injectedCoordinator {
            self.coordinator = injectedCoordinator
            injectedCoordinator.replaceQuestions(learningQuestions)
        } else {
            let store = usePersistentStore
                ? JosanshiLearningCoordinator.defaultPersistentStore()
                : nil
            self.coordinator = JosanshiLearningCoordinator(
                questions: learningQuestions,
                store: store,
                loadPersistedState: usePersistentStore
            )
        }

        self.questionBank = resolvedBank
        self.dailyTarget = self.coordinator.state.dailyTarget
        self.contentErrorDescription = loadError
        self.isContentGatePresented = loadError != nil
    }

    public func setDailyTarget(_ value: Int) {
        guard JosanshiExamConfiguration.selectableDailyTargets.contains(value) else { return }
        dailyTarget = value
        coordinator.setDailyTarget(value)
        objectWillChange.send()
    }

    public func requestStandardSprint() {
        selectedSubject = nil
        startSession {
            _ = try coordinator.startStandardSprint()
        }
    }

    public func requestSubjectPractice(_ subject: String) {
        guard JosanshiExamConfiguration.subjects.contains(subject) else { return }
        selectedSubject = subject
        startSession {
            _ = try coordinator.startSubject(subject)
        }
    }

    public func requestWeakReview() {
        startSession {
            _ = try coordinator.startWeakReview()
        }
    }

    public func requestMock(_ round: Int) {
        guard (1...JosanshiExamConfiguration.originalMockSetCount).contains(round) else { return }
        startSession {
            _ = try coordinator.startMock(round)
        }
    }

    public func resumePreviousSession() {
        if coordinator.activeSession != nil || coordinator.resumePersistedSession() {
            contentErrorDescription = nil
            isContentGatePresented = false
            isSessionPresented = true
        }
    }

    public func finishSession() {
        isSessionPresented = false
        dailyTarget = coordinator.state.dailyTarget
        objectWillChange.send()
    }

    public func dismissContentError() {
        isContentGatePresented = false
    }

    public var hasReadyContent: Bool {
        questionBank?.questions.count == JosanshiExamConfiguration.originalProductionQuestionTarget
            && questionBank?.scenarios.count == JosanshiExamConfiguration.originalScenarioCaseTarget
    }

    public var hasResumableSession: Bool {
        coordinator.activeSession != nil
    }

    public var todayAnsweredCount: Int {
        coordinator.todayAnsweredCount
    }

    public var weakQuestionCount: Int {
        coordinator.weakQuestionCount
    }

    public var todayProgress: Double {
        guard dailyTarget > 0 else { return 0 }
        return min(1, Double(todayAnsweredCount) / Double(dailyTarget))
    }

    public var productionQuestionTargetText: String {
        "全\(JosanshiExamConfiguration.originalProductionQuestionTarget)問（独自模試3回分）"
    }

    public var contentStatusText: String {
        hasReadyContent ? "330問・36症例 FULL監査済み" : "問題データ要確認"
    }

    public func exportBackup() throws -> Data {
        try coordinator.exportBackup()
    }

    public func importBackup(_ data: Data) throws {
        try coordinator.importBackup(data)
        dailyTarget = coordinator.state.dailyTarget
        objectWillChange.send()
    }

    private func startSession(_ action: () throws -> Void) {
        guard hasReadyContent else {
            contentErrorDescription = contentErrorDescription ?? "330問のFULL監査済み問題データを読み込めません。"
            isContentGatePresented = true
            return
        }
        do {
            try action()
            contentErrorDescription = nil
            isContentGatePresented = false
            isSessionPresented = true
        } catch {
            contentErrorDescription = error.localizedDescription
            isContentGatePresented = true
        }
    }
}
