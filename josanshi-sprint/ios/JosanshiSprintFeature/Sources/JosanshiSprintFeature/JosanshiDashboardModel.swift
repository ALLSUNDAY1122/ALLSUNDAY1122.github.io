import Foundation
import SwiftUI
import Combine
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
    @Published public var isPaywallPresented = false
    @Published public private(set) var isPremium: Bool
    @Published public private(set) var contentErrorDescription: String?

    public let coordinator: JosanshiLearningCoordinator
    public private(set) var questionBank: JosanshiQuestionBankDocument?
    public private(set) var purchaseController: PurchaseController?

    private var purchaseCancellables = Set<AnyCancellable>()

    public init(
        questionBank: JosanshiQuestionBankDocument? = nil,
        coordinator injectedCoordinator: JosanshiLearningCoordinator? = nil,
        usePersistentStore: Bool = true,
        enableStoreKit: Bool = false,
        premiumEntitlementOverride: Bool? = nil
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
        self.isPremium = premiumEntitlementOverride ?? false
        self.purchaseController = nil

        if premiumEntitlementOverride == nil,
           enableStoreKit,
           let productID = JosanshiExamConfiguration.productionIdentifiers.productID,
           !productID.isEmpty {
            let controller = PurchaseController(productID: productID)
            self.purchaseController = controller
            self.isPremium = controller.isPremium

            controller.$isPremium
                .removeDuplicates()
                .sink { [weak self] entitled in
                    guard let self else { return }
                    self.isPremium = entitled
                    if entitled {
                        self.isPaywallPresented = false
                    }
                }
                .store(in: &purchaseCancellables)

            controller.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &purchaseCancellables)
        }
    }

    public func setDailyTarget(_ value: Int) {
        guard JosanshiExamConfiguration.selectableDailyTargets.contains(value) else { return }
        dailyTarget = value
        coordinator.setDailyTarget(value)
        objectWillChange.send()
    }

    public func setExamDate(_ value: Date?) {
        coordinator.setExamDate(value)
        objectWillChange.send()
    }

    public func setTextSizeStep(_ value: Int) {
        coordinator.setTextSizeStep(value)
        objectWillChange.send()
    }

    public func setShuffleQuestions(_ value: Bool) {
        coordinator.setShuffleQuestions(value)
        objectWillChange.send()
    }

    public func setShuffleChoices(_ value: Bool) {
        coordinator.setShuffleChoices(value)
        objectWillChange.send()
    }

    public func requestStandardSprint() {
        selectedSubject = nil
        startSession {
            _ = try coordinator.startStandardSprint(isPremium: isPremium)
        }
    }

    public func requestSubjectPractice(_ subject: String) {
        guard JosanshiExamConfiguration.subjects.contains(subject) else { return }
        guard requirePremium() else { return }
        selectedSubject = subject
        startSession {
            _ = try coordinator.startSubject(subject, isPremium: true)
        }
    }

    public func requestWeakReview() {
        guard requirePremium() else { return }
        startSession {
            _ = try coordinator.startWeakReview(isPremium: true)
        }
    }

    public func requestMock(_ round: Int) {
        guard (1...JosanshiExamConfiguration.originalMockSetCount).contains(round) else { return }
        guard requirePremium() else { return }
        startSession {
            _ = try coordinator.startMock(round, isPremium: true)
        }
    }

    public func showMockTab() {
        selectedTab = .mock
    }

    public func presentPaywall() {
        isPaywallPresented = true
    }

    public func dismissPaywall() {
        isPaywallPresented = false
    }

    public func purchasePremium() async {
        guard let purchaseController else {
            contentErrorDescription = "App Storeの商品情報を読み込めません。通信状態を確認してもう一度お試しください。"
            isContentGatePresented = true
            return
        }
        await purchaseController.purchase()
        isPremium = purchaseController.isPremium
        if isPremium { isPaywallPresented = false }
        objectWillChange.send()
    }

    public func restorePremium() async {
        guard let purchaseController else {
            contentErrorDescription = "購入情報を復元できません。App Storeへ接続できる状態でお試しください。"
            isContentGatePresented = true
            return
        }
        await purchaseController.restore()
        isPremium = purchaseController.isPremium
        if isPremium { isPaywallPresented = false }
        objectWillChange.send()
    }

    public func resumePreviousSession() {
        let persisted = coordinator.activeSession ?? coordinator.state.resumeSession
        if !isPremium,
           let persisted,
           sessionContainsPremiumQuestion(persisted) {
            isPaywallPresented = true
            return
        }

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

    public func resetLearningHistory() {
        coordinator.resetLearningHistory()
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
        coordinator.activeSession != nil || coordinator.state.resumeSession != nil
    }

    public var freeQuestionCount: Int {
        coordinator.questions.filter { !$0.premium }.count
    }

    public var premiumQuestionCount: Int {
        coordinator.questions.filter(\.premium).count
    }

    public var purchaseState: PurchaseController.PurchaseState? {
        purchaseController?.state
    }

    public var purchasePriceText: String? {
        purchaseController?.displayPrice
    }

    public var todayAnsweredCount: Int { coordinator.todayAnsweredCount }
    public var weakQuestionCount: Int { coordinator.weakQuestionCount }
    public var totalAnsweredCount: Int { coordinator.totalAnsweredCount }
    public var totalCorrectCount: Int { coordinator.totalCorrectCount }
    public var uniqueAnsweredCount: Int { coordinator.uniqueAnsweredCount }
    public var examDate: Date? { coordinator.state.examDate }
    public var textSizeStep: Int { coordinator.preferences.resolvedTextSizeStep }
    public var shuffleQuestions: Bool { coordinator.preferences.shuffleQuestions }
    public var shuffleChoices: Bool { coordinator.preferences.shuffleChoices }
    public var requiredDailyPace: Int? { coordinator.requiredDailyPace }

    public var todayProgress: Double {
        guard dailyTarget > 0 else { return 0 }
        return min(1, Double(todayAnsweredCount) / Double(dailyTarget))
    }

    public var overallAccuracy: Double {
        guard totalAnsweredCount > 0 else { return 0 }
        return Double(totalCorrectCount) / Double(totalAnsweredCount)
    }

    public var remainingQuestionCount: Int {
        max(0, JosanshiExamConfiguration.originalProductionQuestionTarget - uniqueAnsweredCount)
    }

    public var remainingDays: Int? {
        guard let examDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: examDate)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
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

    private func requirePremium() -> Bool {
        guard isPremium else {
            isPaywallPresented = true
            return false
        }
        return true
    }

    private func sessionContainsPremiumQuestion(_ session: LearningSessionSnapshot) -> Bool {
        let premiumIDs = Set(coordinator.questions.filter(\.premium).map(\.id))
        return session.questionIDs.contains(where: premiumIDs.contains)
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
