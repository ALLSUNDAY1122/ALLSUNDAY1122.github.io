#if canImport(SwiftUI)
import SwiftUI
import LearningSprintCore

public struct HokenshiProductQuizView: View {
    private let questions: [LearningQuestion]
    private let title: String
    private let startIndex: Int
    private let onAdvance: (LearningQuestion, AnswerPayload, AnswerEvaluation, Int, Int) -> [AnswerEvaluation]?
    private let onFinish: ([AnswerEvaluation]) -> Void
    private let onClose: () -> Void

    @State private var currentIndex: Int
    @State private var selectedIndices: Set<Int> = []
    @State private var numericText = ""
    @State private var submittedAnswer: AnswerPayload?
    @State private var evaluation: AnswerEvaluation?
    @State private var errorMessage: String?

    public init(
        questions: [LearningQuestion],
        title: String,
        startIndex: Int = 0,
        onAdvance: @escaping (LearningQuestion, AnswerPayload, AnswerEvaluation, Int, Int) -> [AnswerEvaluation]? = { _, _, _, _, _ in nil },
        onFinish: @escaping ([AnswerEvaluation]) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.questions = questions
        self.title = title
        self.startIndex = startIndex
        self.onAdvance = onAdvance
        self.onFinish = onFinish
        self.onClose = onClose
        let safeIndex = questions.isEmpty ? 0 : min(max(0, startIndex), questions.count - 1)
        _currentIndex = State(initialValue: safeIndex)
    }

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            if questions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            metadata
                            if let sourceText = currentQuestion.sourceText, !sourceText.isEmpty {
                                scenarioCard(sourceText)
                            }
                            questionCard
                            if evaluation == nil { answerArea }
                            if let evaluation { feedback(evaluation) }
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(LearningSprintTheme.sans(13, weight: .semibold))
                                    .foregroundStyle(LearningSprintTheme.vermilion)
                            }
                        }
                        .frame(maxWidth: 520, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .accessibilityIdentifier("hokenshi.product.quiz")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("学習を閉じる")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(LearningSprintTheme.sans(13, weight: .bold))
                Text("\(currentIndex + 1) / \(questions.count)")
                    .font(LearningSprintTheme.sans(11, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
            Spacer()
            ProgressView(value: Double(currentIndex + 1), total: Double(questions.count))
                .frame(maxWidth: 150)
                .tint(LearningSprintTheme.indigo)
                .accessibilityLabel("問題進捗")
                .accessibilityValue("\(currentIndex + 1)問目、全\(questions.count)問")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LearningSprintTheme.card.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(LearningSprintTheme.line).frame(height: 1) }
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            Text(currentQuestion.subject)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.indigo)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(LearningSprintTheme.indigoSoft).clipShape(Capsule())
            Text(currentQuestion.topic)
                .font(LearningSprintTheme.sans(11, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink2)
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }

    private func scenarioCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("状況設定", systemImage: "person.text.rectangle")
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.green)
            Text(text)
                .font(LearningSprintTheme.sans(14))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LearningSprintTheme.greenSoft)
        .overlay(alignment: .leading) { Rectangle().fill(LearningSprintTheme.green).frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("hokenshi.quiz.scenario")
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentQuestion.prompt)
                .font(LearningSprintTheme.serif(20, weight: .semibold))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            if currentQuestion.answerType == .multiChoice {
                Label("複数選択", systemImage: "checklist").formatHint()
            } else if currentQuestion.answerType == .numeric {
                Label("数値で回答", systemImage: "number").formatHint()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LearningSprintTheme.card)
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var answerArea: some View {
        switch currentQuestion.answerType {
        case .singleChoice:
            choices(allowsMultiple: false)
        case .multiChoice:
            choices(allowsMultiple: true)
            Button("回答する") {
                submit(AnswerPayload(selectedIndices: selectedIndices.sorted()))
            }
            .primaryAnswerStyle(enabled: !selectedIndices.isEmpty)
            .disabled(selectedIndices.isEmpty)
        case .numeric:
            numericAnswer
        case .blankSelect, .declaration:
            Text("この回答形式は初期版では使用しません。")
                .font(LearningSprintTheme.sans(13, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.vermilion)
        }

        Button {
            submit(.unknown)
        } label: {
            Label("わからない", systemImage: "questionmark.circle")
                .font(LearningSprintTheme.sans(14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(LearningSprintTheme.ink2)
        .background(LearningSprintTheme.card)
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(LearningSprintTheme.line) }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("hokenshi.quiz.unknown")
    }

    private func choices(allowsMultiple: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(currentQuestion.choices.enumerated()), id: \.offset) { index, choice in
                let selected = selectedIndices.contains(index)
                Button {
                    if allowsMultiple {
                        if selected { selectedIndices.remove(index) } else { selectedIndices.insert(index) }
                    } else {
                        selectedIndices = [index]
                        submit(AnswerPayload(selectedIndices: [index]))
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(choiceLabel(index))
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                            .foregroundStyle(selected ? Color.white : LearningSprintTheme.indigo)
                            .frame(width: 30, height: 30)
                            .background(selected ? LearningSprintTheme.indigo : LearningSprintTheme.indigoSoft)
                            .clipShape(Circle())
                        Text(choice)
                            .font(LearningSprintTheme.sans(15, weight: .medium))
                            .foregroundStyle(LearningSprintTheme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selected ? LearningSprintTheme.indigoSoft.opacity(0.65) : LearningSprintTheme.card)
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? LearningSprintTheme.indigo : LearningSprintTheme.line, lineWidth: selected ? 2 : 1) }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("選択肢 \(choiceLabel(index))、\(choice)")
                .accessibilityValue(selected ? "選択中" : "未選択")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private var numericAnswer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("数値を入力", text: $numericText)
                    .textFieldStyle(.plain)
                    .font(LearningSprintTheme.sans(18, weight: .semibold))
                    .padding(.horizontal, 14).frame(minHeight: 50)
                    .background(LearningSprintTheme.card)
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(LearningSprintTheme.line) }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if let unit = currentQuestion.unit, !unit.isEmpty { Text(unit).font(LearningSprintTheme.sans(14, weight: .bold)) }
            }
            Button("回答する") {
                guard let value = Double(numericText.replacingOccurrences(of: ",", with: "")) else {
                    errorMessage = "数値を入力してください。"; return
                }
                submit(AnswerPayload(numberValue: value))
            }
            .primaryAnswerStyle(enabled: true)
        }
    }

    private func feedback(_ result: AnswerEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : (result.isUnknown ? "questionmark.circle.fill" : "xmark.circle.fill"))
                    .font(.title2)
                    .foregroundStyle(result.isCorrect ? LearningSprintTheme.green : LearningSprintTheme.vermilion)
                Text(result.isCorrect ? "正解" : (result.isUnknown ? "わからない" : "不正解"))
                    .font(LearningSprintTheme.serif(22, weight: .bold))
            }
            Text(currentQuestion.explanation)
                .font(LearningSprintTheme.sans(14)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            LearningSprintMemoryBlock(currentQuestion.memoryPoint)
            if let title = currentQuestion.sourceTitle, !title.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("一次根拠").font(LearningSprintTheme.sans(11, weight: .bold)).foregroundStyle(LearningSprintTheme.ink3)
                    if let raw = currentQuestion.sourceURL, let url = URL(string: raw) {
                        Link(destination: url) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(title).multilineTextAlignment(.leading)
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(LearningSprintTheme.sans(12, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.indigo)
                        }
                        .accessibilityLabel("一次根拠を開く、\(title)")
                    } else {
                        Text(title).font(LearningSprintTheme.sans(12, weight: .semibold))
                    }
                    Text("確認基準日 \(currentQuestion.lawBaselineDate)")
                        .font(LearningSprintTheme.sans(10)).foregroundStyle(LearningSprintTheme.ink3)
                }
            }
            Button(currentIndex + 1 == questions.count ? "結果を見る" : "次の問題", action: advance)
                .primaryAnswerStyle(enabled: true)
        }
        .padding(16)
        .background(result.isCorrect ? LearningSprintTheme.greenSoft : LearningSprintTheme.vermilionSoft)
        .overlay { RoundedRectangle(cornerRadius: 16).stroke((result.isCorrect ? LearningSprintTheme.green : LearningSprintTheme.vermilion).opacity(0.35)) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("hokenshi.quiz.feedback")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(LearningSprintTheme.gold)
            Text("監査済み問題を読み込めません").font(LearningSprintTheme.serif(20, weight: .semibold))
            Button("閉じる", action: onClose).frame(minWidth: 120, minHeight: 44)
        }.padding(24)
    }

    private var currentQuestion: LearningQuestion { questions[currentIndex] }

    private func submit(_ answer: AnswerPayload) {
        errorMessage = nil
        do {
            submittedAnswer = answer
            evaluation = try LearningEngine.evaluate(currentQuestion, answer: answer)
        } catch LearningEngineError.missingAnswer {
            errorMessage = "回答を選択してください。"
        } catch {
            errorMessage = "この問題を採点できません。問題データ監査が必要です。"
        }
    }

    private func advance() {
        guard let evaluation, let submittedAnswer else { return }
        let nextIndex = currentIndex + 1
        if let fullResult = onAdvance(currentQuestion, submittedAnswer, evaluation, nextIndex, questions.count) {
            onFinish(fullResult)
            return
        }
        guard nextIndex < questions.count else {
            onFinish([evaluation])
            return
        }
        currentIndex = nextIndex
        selectedIndices = []
        numericText = ""
        self.submittedAnswer = nil
        self.evaluation = nil
        errorMessage = nil
    }

    private func choiceLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E", "F"]
        return index < labels.count ? labels[index] : "\(index + 1)"
    }
}

private extension View {
    func formatHint() -> some View {
        self.font(LearningSprintTheme.sans(11, weight: .bold)).foregroundStyle(LearningSprintTheme.gold)
    }
    func primaryAnswerStyle(enabled: Bool) -> some View {
        self.font(LearningSprintTheme.sans(15, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color.white)
            .background(enabled ? LearningSprintTheme.indigo : LearningSprintTheme.ink3)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .buttonStyle(.plain)
    }
}
#endif
