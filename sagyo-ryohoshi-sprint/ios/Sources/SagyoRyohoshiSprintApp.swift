import SwiftUI
import LearningSprintCore

private let otBundleID = "jp.allsunday1122.sagyoryouhoushi"
private let otContentVersion = "ot-600-v1"
private let otMonthlyProductID = "jp.allsunday1122.sagyoryouhoushi.monthly"

@main
struct SagyoRyohoshiSprintApp: App {
    @StateObject private var purchase = PurchaseController(productIDs: [otMonthlyProductID])

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchase)
                .preferredColorScheme(.light)
        }
    }
}

@MainActor
final class OTAppModel: ObservableObject {
    @Published private(set) var questions: [LearningQuestion] = []
    @Published private(set) var session: [LearningQuestion] = []
    @Published private(set) var index = 0
    @Published private(set) var correctCount = 0
    @Published private(set) var feedback: AnswerEvaluation?
    @Published var selectedIndices: Set<Int> = []
    @Published var loadError: String?
    @Published private(set) var finished = false
    @Published private(set) var state = LearningState(contentVersion: otContentVersion)
    @Published private(set) var sessionKind: SessionKind = .sprint

    private let store = LearningStateStore(bundleID: otBundleID, contentVersion: otContentVersion)

    var current: LearningQuestion? {
        guard session.indices.contains(index) else { return nil }
        return session[index]
    }

    var todayAnsweredCount: Int { LearningEngine.todayAnsweredCount(state: state) }
    var weakCount: Int { state.weakQuestions.count }
    var hasResumeSession: Bool { state.resumeSession != nil }
    var canStartWeak: Bool { weakCount > 0 }

    init() {
        load()
    }

    func load() {
        do {
            guard let url = Bundle.main.url(forResource: "questions.generated", withExtension: "json") else {
                throw NSError(domain: "OTPayload", code: 1, userInfo: [NSLocalizedDescriptionKey: "問題データが見つかりません"])
            }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([LearningQuestion].self, from: data)
            guard decoded.count == 600 else {
                throw NSError(domain: "OTPayload", code: 2, userInfo: [NSLocalizedDescriptionKey: "問題数が600問ではありません"])
            }
            guard decoded.allSatisfy({ $0.contentVersion == otContentVersion }) else {
                throw NSError(domain: "OTPayload", code: 3, userInfo: [NSLocalizedDescriptionKey: "問題データの版が一致しません"])
            }
            questions = decoded
            state = try store.load()
            if state.contentVersion != otContentVersion {
                state = LearningState(contentVersion: otContentVersion)
                try store.save(state)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func start(target: Int = 8, isPremium: Bool) {
        let selected = LearningEngine.selectSprint(from: questions, target: target, isPremium: isPremium)
        begin(selected, kind: .sprint)
    }

    func startWeak(target: Int = 8, isPremium: Bool) {
        let selected = LearningEngine.selectWeak(from: questions, state: state, target: target, isPremium: isPremium)
        guard !selected.isEmpty else { return }
        begin(selected, kind: .weak)
    }

    func resume() {
        guard let snapshot = state.resumeSession else { return }
        let byID = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        let restored = snapshot.questionIDs.compactMap { byID[$0] }
        guard restored.count == snapshot.questionIDs.count, restored.indices.contains(snapshot.currentIndex) else {
            state.resumeSession = nil
            persistState()
            return
        }

        var restoredCorrectCount = 0
        for question in restored {
            guard let savedAnswer = snapshot.answers[question.id] else { continue }
            if let evaluation = try? LearningEngine.evaluate(question, answer: savedAnswer), evaluation.isCorrect {
                restoredCorrectCount += 1
            }
        }

        session = restored
        sessionKind = snapshot.kind
        index = snapshot.currentIndex
        correctCount = restoredCorrectCount
        finished = false

        let currentQuestion = restored[snapshot.currentIndex]
        if let savedAnswer = snapshot.answers[currentQuestion.id],
           let savedEvaluation = try? LearningEngine.evaluate(currentQuestion, answer: savedAnswer) {
            selectedIndices = Set(savedAnswer.selectedIndices)
            feedback = savedEvaluation
        } else {
            selectedIndices = []
            feedback = nil
        }
    }

    private func begin(_ selected: [LearningQuestion], kind: SessionKind) {
        guard !selected.isEmpty else { return }
        session = selected
        sessionKind = kind
        index = 0
        correctCount = 0
        feedback = nil
        selectedIndices = []
        finished = false
        state.resumeSession = LearningSessionSnapshot(
            kind: kind,
            questionIDs: selected.map(\.id),
            currentIndex: 0
        )
        persistState()
    }

    func goHome() {
        session = []
        index = 0
        correctCount = 0
        feedback = nil
        selectedIndices = []
        finished = false
    }

    func toggle(_ choice: Int) {
        guard let question = current, feedback == nil else { return }
        switch question.answerType {
        case .singleChoice:
            selectedIndices = [choice]
        case .multiChoice:
            if selectedIndices.contains(choice) { selectedIndices.remove(choice) }
            else { selectedIndices.insert(choice) }
        default:
            break
        }
    }

    func answerUnknown() {
        evaluate(.unknown)
    }

    func submit() {
        evaluate(AnswerPayload(selectedIndices: selectedIndices.sorted()))
    }

    private func evaluate(_ payload: AnswerPayload) {
        guard let question = current, feedback == nil else { return }
        do {
            let result = try LearningEngine.evaluate(question, answer: payload)
            feedback = result
            if result.isCorrect { correctCount += 1 }
            LearningEngine.record(question: question, evaluation: result, state: &state)
            if var snapshot = state.resumeSession {
                snapshot.answers[question.id] = payload
                state.resumeSession = snapshot
            }
            persistState()
        } catch {
            loadError = "採点できませんでした: \(error)"
        }
    }

    func next() {
        guard feedback != nil else { return }
        if index + 1 >= session.count {
            state.recordCompletion(for: sessionKind)
            state.resumeSession = nil
            persistState()
            finished = true
        } else {
            index += 1
            selectedIndices = []
            feedback = nil
            if var snapshot = state.resumeSession {
                snapshot.currentIndex = index
                state.resumeSession = snapshot
            }
            persistState()
        }
    }

    private func persistState() {
        do {
            try store.save(state)
        } catch {
            loadError = "学習履歴を保存できませんでした: \(error.localizedDescription)"
        }
    }
}

struct RootView: View {
    @StateObject private var model = OTAppModel()

    var body: some View {
        NavigationStack {
            Group {
                if let error = model.loadError {
                    ErrorView(message: error)
                } else if model.finished {
                    ResultView(model: model)
                } else if model.current != nil {
                    QuizView(model: model)
                } else {
                    HomeView(model: model)
                }
            }
            .navigationTitle("作業療法士 国試")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HomeView: View {
    @ObservedObject var model: OTAppModel
    @EnvironmentObject private var purchase: PurchaseController
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("今日の学習")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("短時間で解いて、正誤と理由をその場で確認します。")
                    .foregroundStyle(.secondary)

                HStack {
                    StatCard(value: "\(model.todayAnsweredCount)", label: "今日解いた")
                    StatCard(value: "\(model.weakCount)", label: "苦手問題")
                }

                if model.hasResumeSession {
                    Button {
                        model.resume()
                    } label: {
                        Label("前回の続きから", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("中断した学習の続きに戻ります")
                }

                Button {
                    model.start(target: 8, isPremium: purchase.isPremium)
                } label: {
                    Text("8問スプリントを始める")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.questions.isEmpty)
                .accessibilityHint(purchase.isPremium ? "全600問から8問を選んで学習を開始します" : "無料200問から8問を選んで学習を開始します")

                Button {
                    model.startWeak(target: 8, isPremium: purchase.isPremium)
                } label: {
                    Label("苦手を8問復習", systemImage: "repeat")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canStartWeak)
                .accessibilityHint("これまで間違えた問題を優先して復習します")

                if purchase.isPremium {
                    Label("プレミアム利用中・全600問", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .accessibilityLabel("プレミアム利用中。全600問を利用できます")
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("プレミアムで全600問")
                                    .font(.headline)
                                Text("無料200問＋プレミアム400問")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "lock.open")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("App Storeの月額プランと購入の復元を確認します")
                }

                Text(purchase.isPremium ? "収録600問・全問利用可能" : "収録600問・無料200問")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("学習の流れ")
                    .font(.headline)
                Text("開始 → 回答 → 正誤確認 → 解説 → 苦手記録 → 復習 → 再挑戦")
                    .font(.subheadline)
            }
            .padding()
        }
        .sheet(isPresented: $showPaywall) {
            OTPaywallView()
                .environmentObject(purchase)
        }
    }
}

struct QuizView: View {
    @ObservedObject var model: OTAppModel

    var body: some View {
        if let q = model.current {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("\(model.index + 1) / \(model.session.count)")
                            .font(.headline)
                        Spacer()
                        Text(q.subject)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                    }

                    ProgressView(value: Double(model.index + 1), total: Double(max(model.session.count, 1)))
                        .accessibilityLabel("学習進捗")
                        .accessibilityValue("\(model.index + 1)問目、全\(model.session.count)問")

                    Text(q.prompt)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)

                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                        Button {
                            model.toggle(i)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: model.selectedIndices.contains(i) ? "checkmark.circle.fill" : "circle")
                                Text(choice)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.feedback != nil)
                        .accessibilityLabel("選択肢\(i + 1)、\(choice)")
                        .accessibilityValue(model.selectedIndices.contains(i) ? "選択中" : "未選択")
                    }

                    if let feedback = model.feedback {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(feedback.message)
                                .font(.headline)
                            Text(q.explanation)
                            Text("ここだけ覚える")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(q.memoryPoint)
                                .font(.subheadline.bold())
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityElement(children: .combine)

                        Button(model.index + 1 == model.session.count ? "結果を見る" : "次の問題へ") {
                            model.next()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Button("わからない") { model.answerUnknown() }
                                .buttonStyle(.bordered)
                            Spacer()
                            Button("回答する") { model.submit() }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.selectedIndices.isEmpty)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct ResultView: View {
    @ObservedObject var model: OTAppModel
    @EnvironmentObject private var purchase: PurchaseController

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("スプリント完了")
                    .font(.largeTitle.bold())
                Text("\(model.correctCount) / \(model.session.count)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .accessibilityLabel("正解数 \(model.correctCount)問、全\(model.session.count)問")
                Text("間違えた問題は苦手として保存しました。3回連続で正解すると苦手から外れます。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("もう8問") { model.start(target: 8, isPremium: purchase.isPremium) }
                    .buttonStyle(.borderedProminent)
                if model.canStartWeak {
                    Button("苦手を復習") { model.startWeak(target: 8, isPremium: purchase.isPremium) }
                        .buttonStyle(.bordered)
                }
                Button("ホームへ") { model.goHome() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

struct OTPaywallView: View {
    @EnvironmentObject private var purchase: PurchaseController
    @Environment(\.dismiss) private var dismiss

    private var stateMessage: String? {
        switch purchase.state {
        case .pending:
            return "購入承認を待っています。"
        case .cancelled:
            return "購入はキャンセルされました。"
        case .unavailable(let text), .failed(let text):
            return text
        default:
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("学びスプリント プレミアム")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("無料200問に加えてプレミアム400問を解放し、全600問からスプリントと苦手復習を行えます。")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("全600問から8問スプリント", systemImage: "books.vertical.fill")
                        Label("プレミアム問題も苦手復習の対象", systemImage: "repeat.circle.fill")
                        Label("購入状態はApple IDで復元", systemImage: "arrow.clockwise.icloud")
                    }
                    .font(.subheadline)

                    if purchase.isPremium {
                        Label("プレミアム利用中", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                    } else {
                        Button {
                            Task { await purchase.purchase(productID: otMonthlyProductID) }
                        } label: {
                            VStack(spacing: 3) {
                                Text(purchase.state == .purchasing ? "購入処理中…" : "月額プラン")
                                    .font(.headline)
                                Text(purchase.displayPrice(for: otMonthlyProductID).map { "月額 \($0)" } ?? "価格を取得中")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(purchase.product(for: otMonthlyProductID) == nil || purchase.state == .purchasing)
                    }

                    Button("購入を復元") {
                        Task { await purchase.restore() }
                    }
                    .font(.subheadline.bold())

                    if let stateMessage {
                        Text(stateMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("表示価格はApp Storeから取得します。月額プランは自動更新です。購入・更新・解約・復元はApple IDの設定に従います。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("起動できません")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
