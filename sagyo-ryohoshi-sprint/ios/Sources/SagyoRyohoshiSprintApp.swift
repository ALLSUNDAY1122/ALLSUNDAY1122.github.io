import SwiftUI
import LearningSprintCore

private let otBundleID = "jp.allsunday1122.sagyoryouhoushi"
private let otContentVersion = "ot-600-v1"

@main
struct SagyoRyohoshiSprintApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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

    func start(target: Int = 8) {
        let selected = LearningEngine.selectSprint(from: questions, target: target, isPremium: false)
        begin(selected, kind: .sprint)
    }

    func startWeak(target: Int = 8) {
        let selected = LearningEngine.selectWeak(from: questions, state: state, target: target, isPremium: false)
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
                    model.start(target: 8)
                } label: {
                    Text("8問スプリントを始める")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.questions.isEmpty)
                .accessibilityHint("無料問題から8問を選んで学習を開始します")

                Button {
                    model.startWeak(target: 8)
                } label: {
                    Label("苦手を8問復習", systemImage: "repeat")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canStartWeak)
                .accessibilityHint("これまで間違えた問題を優先して復習します")

                Text("収録600問・無料200問")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("学習の流れ")
                    .font(.headline)
                Text("開始 → 回答 → 正誤確認 → 解説 → 苦手記録 → 復習 → 再挑戦")
                    .font(.subheadline)
            }
            .padding()
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

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("スプリント完了")
                    .font(.largeTitle.bold())
                Text("\(model.correctCount) / \(model.session.count)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .accessibilityLabel("正解数 \(model.correctCount)問、全\(model.session.count)問")
                Text("間違えた問題は苦手として保存しました。3回連続で正解すると苦手から外れます。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("もう8問") { model.start(target: 8) }
                    .buttonStyle(.borderedProminent)
                if model.canStartWeak {
                    Button("苦手を復習") { model.startWeak(target: 8) }
                        .buttonStyle(.bordered)
                }
                Button("ホームへ") { model.goHome() }
                    .buttonStyle(.bordered)
            }
            .padding()
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
