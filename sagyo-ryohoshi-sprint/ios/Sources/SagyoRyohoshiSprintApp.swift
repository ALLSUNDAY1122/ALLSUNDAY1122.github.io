import SwiftUI
import LearningSprintCore

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

    var current: LearningQuestion? {
        guard session.indices.contains(index) else { return nil }
        return session[index]
    }

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
            questions = decoded
        } catch {
            loadError = error.localizedDescription
        }
    }

    func start(target: Int = 8) {
        session = LearningEngine.selectSprint(from: questions, target: target, isPremium: false)
        index = 0
        correctCount = 0
        feedback = nil
        selectedIndices = []
        finished = false
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
        } catch {
            loadError = "採点できませんでした: \(error)"
        }
    }

    func next() {
        guard feedback != nil else { return }
        if index + 1 >= session.count {
            finished = true
        } else {
            index += 1
            selectedIndices = []
            feedback = nil
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
                Text("短時間で解いて、正誤と理由をその場で確認します。")
                    .foregroundStyle(.secondary)

                HStack {
                    StatCard(value: "\(model.questions.count)", label: "収録問題")
                    StatCard(value: "8", label: "今日の目安")
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

                Text("学習の流れ")
                    .font(.headline)
                Text("開始 → 回答 → 正誤確認 → 解説 → 次の問題 → 結果")
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
        VStack(spacing: 18) {
            Text("スプリント完了")
                .font(.largeTitle.bold())
            Text("\(model.correctCount) / \(model.session.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            Text("解説を確認した問題は、次回もう一度解いて定着させます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("もう8問") { model.start(target: 8) }
                .buttonStyle(.borderedProminent)
            Button("ホームへ") { model.goHome() }
                .buttonStyle(.bordered)
        }
        .padding()
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
