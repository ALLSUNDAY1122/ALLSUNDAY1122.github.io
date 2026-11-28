import AVFoundation
import Foundation
import StoreKit

struct Lesson: Codable, Identifiable, Hashable {
    struct Segment: Codable, Hashable { let en: String; let ja: String }
    struct Question: Codable, Hashable { let q: String; let choices: [String]; let answer: Int; let explain: String }
    struct Voice: Codable, Hashable, Identifiable {
        let id: String
        let name: String
        let azureVoice: String
        let gender: String?
        let genderKey: String
    }
    struct AudioFile: Codable, Hashable {
        let path: String
        let azureVoice: String
        let ssml: String
    }
    struct Short: Codable, Hashable {
        let en: String
        let ja: String
        let audio: [String: AudioFile]
    }

    let id: String
    let region: String
    let level: String
    let title: String
    let topic: String
    let en: String
    let ja: String
    let segments: [Segment]
    let questions: [Question]
    let voices: [Voice]
    let audio: [String: AudioFile]
    let short: Short

    func audioFile(voiceID: String, shortened: Bool) -> AudioFile? {
        (shortened ? short.audio : audio)[voiceID]
    }
}

enum LearningMode: String, CaseIterable, Identifiable {
    case translated = "訳あり"
    case quiz = "問題"
    case segments = "文節"
    var id: String { rawValue }
}

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var lessons: [Lesson] = []
    @Published var selectedLessonID: String?
    @Published var mode: LearningMode = .translated
    @Published var selectedQuestion = 0
    @Published var selectedAnswer: Int?
    @Published var rate: Float = 1.0
    @Published var isPlaying = false
    @Published var showTranslation = true
    @Published var completedLessonIDs: Set<String> = []
    @Published private(set) var completedLessonCounts: [String: Int] = [:]
    @Published var answerHistory: [String: Bool] = [:]
    @Published var selectedVoiceID = ""
    @Published var useShortAudio = false
    @Published var showPaywall = false
    @Published private(set) var isPremium = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var lifetimeProduct: Product?
    @Published var purchaseMessage: String?
    @Published var isPurchasing = false

    static let monthlyProductID = "jp.allsunday1122.englishlistening.premium.monthly"
    static let lifetimeProductID = "jp.allsunday1122.englishlistening.premium.lifetime"
    private var player: AVAudioPlayer?
    private var transactionListener: Task<Void, Never>?

    init() {
        lessons = Self.loadLessons()
        completedLessonIDs = Set(UserDefaults.standard.stringArray(forKey: "completedLessonIDs") ?? [])
        completedLessonCounts = UserDefaults.standard.dictionary(forKey: "completedLessonCounts") as? [String: Int] ?? [:]
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { transactionListener?.cancel() }

    func isFree(_ lesson: Lesson) -> Bool {
        let digits = lesson.id.filter(\.isNumber)
        guard let themeNumber = Int(digits) else { return false }
        return (1...6).contains(themeNumber)
    }

    var hasOneWeekFreeTrial: Bool {
        guard let offer = monthlyProduct?.subscription?.introductoryOffer else { return false }
        return offer.paymentMode == .freeTrial && offer.period.unit == .day && offer.period.value == 7
    }

    func canAccess(_ lesson: Lesson) -> Bool { isPremium || isFree(lesson) }

    func requestAccess(to lesson: Lesson) {
        if canAccess(lesson) {
            open(lesson)
            return
        }
        Task {
            await refreshEntitlements(retries: 4)
            if canAccess(lesson) {
                open(lesson)
            } else {
                showPaywall = true
            }
        }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyProductID, Self.lifetimeProductID])
            let monthly = products.first { $0.id == Self.monthlyProductID }
            let lifetime = products.first { $0.id == Self.lifetimeProductID }
            monthlyProduct = monthly?.type == .autoRenewable ? monthly : nil
            lifetimeProduct = lifetime?.type == .nonConsumable ? lifetime : nil
            if monthlyProduct == nil || lifetimeProduct == nil {
                purchaseMessage = "商品IDまたは商品種別を確認できません。App Store Connectの製品設定をご確認ください。"
            }
        } catch { purchaseMessage = "商品情報を取得できませんでした。通信環境を確認してください。" }
    }

    func purchase(_ product: Product?) async {
        guard let product else { purchaseMessage = "購入商品を読み込めません。"; return }
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements(retries: 6)
                    if isPremium { showPaywall = false }
                    else { purchaseMessage = "購入を確認中です。数秒後に再確認してください。" }
                case .unverified: purchaseMessage = "購入を検証できませんでした。"
                }
            case .pending: purchaseMessage = "購入承認待ちです。承認後に自動で反映されます。"
            case .userCancelled: break
            @unknown default: purchaseMessage = "購入結果を確認できませんでした。"
            }
        } catch { purchaseMessage = "購入に失敗しました: \(error.localizedDescription)" }
    }

    func restorePurchases() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements(retries: 6)
            if isPremium { showPaywall = false }
            else { purchaseMessage = "復元できる購入が見つかりませんでした。" }
        } catch { purchaseMessage = "購入の復元に失敗しました: \(error.localizedDescription)" }
    }

    func refreshEntitlements(retries: Int = 1) async {
        for attempt in 0..<max(1, retries) {
            var premium = false
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
                if transaction.productID == Self.monthlyProductID || transaction.productID == Self.lifetimeProductID { premium = true }
            }
            isPremium = premium
            if premium || attempt == max(1, retries) - 1 { break }
            try? await Task.sleep(for: .milliseconds(700))
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result { await transaction.finish() }
                await self.refreshEntitlements(retries: 4)
                if self.isPremium { self.showPaywall = false }
            }
        }
    }

    var currentLesson: Lesson? {
        guard let selectedLessonID else { return nil }
        return lessons.first { $0.id == selectedLessonID }
    }

    var selectedVoice: Lesson.Voice? {
        guard let lesson = currentLesson else { return nil }
        return lesson.voices.first { $0.id == selectedVoiceID } ?? lesson.voices.first
    }

    var question: Lesson.Question? {
        guard let lesson = currentLesson, lesson.questions.indices.contains(selectedQuestion) else { return nil }
        return lesson.questions[selectedQuestion]
    }

    private var navigationLessons: [Lesson] {
        var regionOrder: [String] = []
        for lesson in lessons where !regionOrder.contains(lesson.region) {
            regionOrder.append(lesson.region)
        }
        return regionOrder.flatMap { region in
            lessons.filter { $0.region == region }
        }
    }

    private var currentNavigationIndex: Int? {
        guard let currentLesson else { return nil }
        return navigationLessons.firstIndex { $0.id == currentLesson.id }
    }

    var hasPreviousLesson: Bool {
        guard let index = currentNavigationIndex else { return false }
        return index > 0
    }

    var hasNextLesson: Bool {
        guard let index = currentNavigationIndex else { return false }
        return index + 1 < navigationLessons.count
    }

    func moveToPreviousLesson() {
        moveLesson(by: -1)
    }

    func moveToNextLesson() {
        moveLesson(by: 1)
    }

    private func moveLesson(by offset: Int) {
        guard let index = currentNavigationIndex else { return }
        let destination = index + offset
        guard navigationLessons.indices.contains(destination) else { return }
        open(navigationLessons[destination])
    }

    func open(_ lesson: Lesson) {
        guard canAccess(lesson) else { showPaywall = true; return }
        stop()
        selectedLessonID = lesson.id
        selectedQuestion = 0
        selectedAnswer = nil
        mode = .translated
        useShortAudio = false
        selectedVoiceID = lesson.voices.first(where: { $0.genderKey == "female" })?.id ?? lesson.voices.first?.id ?? ""
    }

    func answer(_ choice: Int) {
        guard let question else { return }
        selectedAnswer = choice
        answerHistory["\(currentLesson?.id ?? "")-\(selectedQuestion)"] = choice == question.answer
    }

    func nextQuestion() {
        guard let lesson = currentLesson else { return }
        if selectedQuestion + 1 < lesson.questions.count {
            selectedQuestion += 1
            selectedAnswer = nil
        } else {
            completedLessonIDs.insert(lesson.id)
            completedLessonCounts[lesson.id, default: 0] += 1
            UserDefaults.standard.set(Array(completedLessonIDs), forKey: "completedLessonIDs")
            UserDefaults.standard.set(completedLessonCounts, forKey: "completedLessonCounts")
            selectedQuestion = 0
            selectedAnswer = nil
        }
    }

    func togglePlayback() {
        guard let lesson = currentLesson else { return }
        if isPlaying { stop(); return }
        guard let voice = selectedVoice,
              let audio = lesson.audioFile(voiceID: voice.id, shortened: useShortAudio),
              let url = Self.audioURL(for: audio.path) else {
            isPlaying = false
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = rate
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    private static func audioURL(for path: String) -> URL? {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/")
        guard let file = components.last else { return nil }
        let fileName = String(file)
        let ext = URL(fileURLWithPath: fileName).pathExtension
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let directory = components.dropLast().joined(separator: "/")
        if !directory.isEmpty,
           let nested = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: directory) {
            return nested
        }
        return Bundle.main.url(forResource: stem, withExtension: ext)
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        player?.rate = newRate
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    private static func loadLessons() -> [Lesson] {
        ["lessons-part1", "lessons-part2", "lessons-part3"].flatMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([Lesson].self, from: data) else { return [Lesson]() }
            return decoded
        }
    }
}
