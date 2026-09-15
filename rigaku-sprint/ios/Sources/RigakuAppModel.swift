import Combine
import Foundation
import LearningSprintCore

@MainActor
final class RigakuAppModel: ObservableObject {
    @Published private(set) var state: LearningState
    @Published private(set) var questions: [LearningQuestion] = []
    @Published private(set) var mediaByQuestionID: [String: RigakuQuestionMedia] = [:]
    @Published private(set) var premiumAccess = false
    @Published private(set) var purchaseDisplayPrice: String?
    @Published private(set) var purchaseStateLabel: String?
    @Published var lastError: String?

    private let store: LearningStateStore?
    private var examScoringRepository: RigakuExamScoringRepository?
    private var purchaseController: PurchaseController?
    private var purchaseCancellables: Set<AnyCancellable> = []

    init(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.state = LearningState(contentVersion: RigakuAppConfiguration.contentVersion)

        if let bundleIdentifier = RigakuAppConfiguration.normalizedExternalIdentifier(bundleIdentifier) {
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
            self.lastError = "Bundle IDを確認できないため、学習データ保存を開始できません。"
        }

        do {
            self.questions = try RigakuQuestionRepository.loadBundled()
            self.mediaByQuestionID = try RigakuQuestionMediaRepository.loadBundled()
        } catch {
            self.questions = []
            self.mediaByQuestionID = [:]
            if self.lastError == nil {
                self.lastError = "監査済み問題データを読み込めませんでした。"
            }
        }

        do {
            self.examScoringRepository = try RigakuExamScoringRepository.loadBundled()
        } catch {
            self.examScoringRepository = nil
            if self.lastError == nil {
                self.lastError = "模試採点正本を読み込めませんでした。"
            }
        }

        configurePurchaseIfAvailable()
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

    var subjectAccuracy: [String: Double] {
        LearningEngine.subjectAccuracy(state: state)
    }

    var uniqueAnsweredCount: Int {
        Set(state.attempts.map(\.questionID)).count
    }

    var requiredDailyPace: Int? {
        LearningEngine.requiredDailyPace(
            totalQuestionCount: availableQuestionCount,
            uniqueAnsweredCount: uniqueAnsweredCount,
            examDate: state.examDate
        )
    }

    var canStudy: Bool {
        !accessibleQuestions.isEmpty
    }

    var purchaseConfigured: Bool {
        purchaseController != nil
    }

    var freeQuestionCount: Int {
        RigakuAccessPolicy.freeQuestionIDs(from: questions).count
    }

    var availableQuestionCount: Int {
        accessibleQuestions.count
    }

    var canAccessBaseMocks: Bool {
        RigakuAccessPolicy.canAccessMock(isPremium: premiumAccess)
    }

    var canAccessFullWeakReview: Bool {
        RigakuAccessPolicy.canAccessFullWeakReview(isPremium: premiumAccess)
    }

    var accessibleQuestions: [LearningQuestion] {
        RigakuAccessPolicy.accessibleQuestions(from: questions, isPremium: premiumAccess)
    }

    func media(for questionID: String) -> RigakuQuestionMedia? {
        mediaByQuestionID[questionID]
    }

    func officialPoints(for questionID: String) -> Int? {
        examScoringRepository?.points(for: questionID)
    }

    func mockScore(
        round: String,
        questions: [LearningQuestion],
        correctness: [String: Bool]
    ) -> RigakuMockScore? {
        examScoringRepository?.score(
            round: round,
            questions: questions,
            correctness: correctness
        )
    }

    func questions(for kind: SessionKind) -> [LearningQuestion] {
        switch kind {
        case .sprint:
            return LearningEngine.selectSprint(
                from: accessibleQuestions,
                target: state.dailyTarget,
                isPremium: premiumAccess
            )
        case .weak:
            guard canAccessFullWeakReview else { return [] }
            return LearningEngine.selectWeak(
                from: questions,
                state: state,
                target: state.dailyTarget,
                isPremium: true
            )
        case .subject(let subject):
            return LearningEngine.selectSprint(
                from: accessibleQuestions.filter { $0.subject == subject },
                target: state.dailyTarget,
                isPremium: premiumAccess
            )
        case .mock(let round):
            guard canAccessBaseMocks else { return [] }
            return questions
                .filter { $0.examRound == round }
                .sorted(by: Self.examQuestionOrder)
        }
    }

    func beginSession(kind: SessionKind, questions: [LearningQuestion]) {
        state.resumeSession = LearningSessionSnapshot(
            kind: kind,
            questionIDs: questions.map(\.id)
        )
        persist()
    }

    func resumeQuestions() -> [LearningQuestion] {
        guard let snapshot = state.resumeSession else { return [] }
        let accessibleByID = Dictionary(uniqueKeysWithValues: accessibleQuestions.map { ($0.id, $0) })
        if case .mock = snapshot.kind, !canAccessBaseMocks { return [] }
        if case .weak = snapshot.kind, !canAccessFullWeakReview { return [] }
        let allByID = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        let byID = premiumAccess ? allByID : accessibleByID
        return snapshot.questionIDs.compactMap { byID[$0] }
    }

    func resumeCorrectness() -> [String: Bool] {
        guard let snapshot = state.resumeSession else { return [:] }
        let byID = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        var result: [String: Bool] = [:]
        for (questionID, answer) in snapshot.answers {
            guard let question = byID[questionID],
                  let evaluation = try? LearningEngine.evaluate(question, answer: answer) else { continue }
            result[questionID] = evaluation.isCorrect
        }
        return result
    }

    @discardableResult
    func recordAnswer(
        question: LearningQuestion,
        answer: AnswerPayload,
        advanceTo nextIndex: Int
    ) throws -> AnswerEvaluation {
        let evaluation = try LearningEngine.evaluate(question, answer: answer)
        LearningEngine.record(question: question, evaluation: evaluation, state: &state)

        if var snapshot = state.resumeSession {
            snapshot.answers[question.id] = answer
            snapshot.currentIndex = nextIndex
            state.resumeSession = snapshot
        }
        persist()
        return evaluation
    }

    func finishSession() {
        state.resumeSession = nil
        persist()
    }

    func discardResumeSession() {
        state.resumeSession = nil
        persist()
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
                NSLocalizedDescriptionKey: "Bundle ID確認後にバックアップを利用できます。"
            ])
        }
        return try store.exportBackup(state)
    }

    func importBackup(_ data: Data) throws {
        guard let store else {
            throw CocoaError(.fileReadUnknown, userInfo: [
                NSLocalizedDescriptionKey: "Bundle ID確認後にバックアップを利用できます。"
            ])
        }
        state = try store.importBackup(data)
        lastError = nil
    }

    func purchasePremium() async {
        guard let purchaseController else { return }
        await purchaseController.purchase()
    }

    func restorePurchases() async {
        guard let purchaseController else { return }
        await purchaseController.restore()
    }

    func refreshPurchase() async {
        guard let purchaseController else { return }
        await purchaseController.refresh()
    }

    func clearError() {
        lastError = nil
    }

    private func configurePurchaseIfAvailable() {
        guard let productID = RigakuAppConfiguration.runtimePremiumProductID else {
            purchaseStateLabel = "月額商品を確認できません"
            return
        }

        let controller = PurchaseController(productID: productID)
        purchaseController = controller
        purchaseStateLabel = "StoreKit確認中"

        controller.$isPremium
            .removeDuplicates()
            .sink { [weak self] value in
                self?.premiumAccess = value
            }
            .store(in: &purchaseCancellables)

        controller.$product
            .sink { [weak self] product in
                self?.purchaseDisplayPrice = product?.displayPrice
            }
            .store(in: &purchaseCancellables)

        controller.$state
            .sink { [weak self] state in
                self?.purchaseStateLabel = Self.purchaseStateLabel(for: state)
            }
            .store(in: &purchaseCancellables)
    }

    private static func purchaseStateLabel(for state: PurchaseController.PurchaseState) -> String {
        switch state {
        case .loading: return "StoreKit確認中"
        case .ready: return "月額プランを開始できます"
        case .purchasing: return "購入処理中"
        case .pending: return "承認待ち"
        case .purchased: return "月額プラン利用中"
        case .cancelled: return "購入をキャンセルしました"
        case .unavailable(let message), .failed(let message): return message
        }
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

    private static func examQuestionOrder(_ lhs: LearningQuestion, _ rhs: LearningQuestion) -> Bool {
        let lhsKey = examOrderKey(lhs)
        let rhsKey = examOrderKey(rhs)
        if lhsKey != rhsKey { return lhsKey < rhsKey }
        return lhs.id < rhs.id
    }

    private static func examOrderKey(_ question: LearningQuestion) -> Int {
        let components = question.id.split(separator: "-")
        if components.count >= 4 {
            let sessionOffset = components[2] == "PM" ? 100 : 0
            if let number = Int(components[3]) {
                return sessionOffset + number
            }
        }
        return Int(question.questionNumber ?? "") ?? .max
    }
}

enum RigakuQuestionRepository {
    static func loadBundled(bundle: Bundle = .main) throws -> [LearningQuestion] {
        let decoder = JSONDecoder()
        var result: [LearningQuestion] = []
        var loadedURLs = Set<URL>()

        if let mainURL = bundle.url(forResource: "questions", withExtension: "json") {
            let data = try Data(contentsOf: mainURL)
            result.append(contentsOf: try decoder.decode([LearningQuestion].self, from: data))
            loadedURLs.insert(mainURL)
        }

        let candidateURLs = (bundle.urls(forResourcesWithExtension: "json", subdirectory: "question-batches") ?? [])
            + (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])

        for url in candidateURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.lastPathComponent.hasPrefix("questions-") else { continue }
            guard !loadedURLs.contains(url) else { continue }
            let data = try Data(contentsOf: url)
            result.append(contentsOf: try decoder.decode([LearningQuestion].self, from: data))
            loadedURLs.insert(url)
        }

        let ids = result.map(\.id)
        guard ids.count == Set(ids).count else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "問題IDが重複しています。"
            ])
        }
        return result
    }
}
