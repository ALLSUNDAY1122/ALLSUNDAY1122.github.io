#if canImport(SwiftUI)
import SwiftUI
import LearningSprintCore

public struct HokenshiQuizView: View {
    private let questions: [LearningQuestion]
    private let title: String
    private let onFinish: ([AnswerEvaluation]) -> Void
    private let onClose: () -> Void

    @State private var currentIndex = 0
    @State private var selectedIndices: Set<Int> = []
    @State private var numericText = ""
    @State private var evaluation: AnswerEvaluation?
    @State private var evaluations: [AnswerEvaluation] = []
    @State private var errorMessage: String?

    public init(
        questions: [LearningQuestion],
        title: String = "学習",
        onFinish: @escaping ([AnswerEvaluation]) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.questions = questions
        self.title = title
        self.onFinish = onFinish
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            if questions.isEmpty {
                emptyState
            } else {
                quizBody
            }
        }
        .foregroundStyle(LearningSprintTheme.ink)
    }

    private var quizBody: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    questionMetadata
                    questionCard
                    answerArea
                    if let evaluation {
                        feedbackCard(evaluation)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(LearningSprintTheme.sans(13, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.vermilion)
                            .accessibilityIdentifier("hokenshi.quiz.error")
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .accessibilityIdentifier("hokenshi.quiz")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("学習を閉じる")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LearningSprintTheme.sans(13, weight: .bold))
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
        .overlay(alignment: .bottom) {
            Rectangle().fill(LearningSprintTheme.line).frame(height: 1)
        }
    }

    private var questionMetadata: some View {
        HStack(spacing: 8) {
            Text(currentQuestion.subject)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.indigo)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(LearningSprintTheme.indigoSoft)
                .clipShape(Capsule())
            Text(currentQuestion.topic)
                .font(LearningSprintTheme.sans(11, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink2)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentQuestion.prompt)
                .font(LearningSprintTheme.serif(20, weight: .semibold))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("hokenshi.quiz.prompt")

            if currentQuestion.answerType == .multiChoice {
                Label("複数選択", systemImage: "checklist")
                    .font(LearningSprintTheme.sans(11, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.gold)
            } else if currentQuestion.answerType == .numeric {
                Label("数値で回答", systemImage: "number")
                    .font(LearningSprintTheme.sans(11, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.gold)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LearningSprintTheme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LearningSprintTheme.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var answerArea: some View {
        if evaluation == nil {
            switch currentQuestion.answerType {
            case .singleChoice:
                choiceButtons(allowsMultiple: false)
            case .multiChoice:
                choiceButtons(allowsMultiple: true)
                primaryAnswerButton
            case .numeric:
                numericAnswer
            case .blankSelect, .declaration:
                unsupportedAnswerNotice
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
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LearningSprintTheme.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("hokenshi.quiz.unknown")
        }
    }

    private func choiceButtons(allowsMultiple: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(currentQuestion.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    if allowsMultiple {
                        if selectedIndices.contains(index) {
                            selectedIndices.remove(index)
                        } else {
                            selectedIndices.insert(index)
                        }
                    } else {
                        selectedIndices = [index]
                        submit(AnswerPayload(selectedIndices: [index]))
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(choiceLabel(index))
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                            .foregroundStyle(selectedIndices.contains(index) ? Color.white : LearningSprintTheme.indigo)
                            .frame(width: 30, height: 30)
                            .background(selectedIndices.contains(index) ? LearningSprintTheme.indigo : LearningSprintTheme.indigoSoft)
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
                .background(selectedIndices.contains(index) ? LearningSprintTheme.indigoSoft.opacity(0.65) : LearningSprintTheme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selectedIndices.contains(index) ? LearningSprintTheme.indigo : LearningSprintTheme.line, lineWidth: selectedIndices.contains(index) ? 2 : 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("hokenshi.quiz.choice.\(index)")
            }
        }
    }

    private var primaryAnswerButton: some View {
        Button {
            submit(AnswerPayload(selectedIndices: selectedIndices.sorted()))
        } label: {
            Text("回答する")
                .font(LearningSprintTheme.sans(15, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(selectedIndices.isEmpty ? LearningSprintTheme.ink3 : LearningSprintTheme.indigo)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(selectedIndices.isEmpty)
        .accessibilityIdentifier("hokenshi.quiz.submit")
    }

    private var numericAnswer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("数値を入力", text: $numericText)
                    .textFieldStyle(.plain)
                    .font(LearningSprintTheme.sans(18, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(LearningSprintTheme.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(LearningSprintTheme.line, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("hokenshi.quiz.numeric")
                if let unit = currentQuestion.unit, !unit.isEmpty {
                    Text(unit)
                        .font(LearningSprintTheme.sans(14, weight: .bold))
                }
            }
            Button {
                let normalized = numericText.replacingOccurrences(of: ",", with: "")
                guard let value = Double(normalized) else {
                    errorMessage = "数値を入力してください。"
                    return
                }
                submit(AnswerPayload(numberValue: value))
            } label: {
                Text("回答する")
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(LearningSprintTheme.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var unsupportedAnswerNotice: some View {
        Text("この回答形式は保健師国家試験の初期版では使用しません。")
            .font(LearningSprintTheme.sans(13, weight: .semibold))
            .foregroundStyle(LearningSprintTheme.vermilion)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LearningSprintTheme.vermilionSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func feedbackCard(_ evaluation: AnswerEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: evaluation.isCorrect ? "checkmark.circle.fill" : (evaluation.isUnknown ? "questionmark.circle.fill" : "xmark.circle.fill"))
                    .font(.title2)
                    .foregroundStyle(evaluation.isCorrect ? LearningSprintTheme.green : LearningSprintTheme.vermilion)
                Text(evaluation.isCorrect ? "正解" : (evaluation.isUnknown ? "わからない" : "不正解"))
                    .font(LearningSprintTheme.serif(22, weight: .bold))
            }

            Text(currentQuestion.explanation)
                .font(LearningSprintTheme.sans(14))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            LearningSprintMemoryBlock(currentQuestion.memoryPoint)

            if let sourceTitle = currentQuestion.sourceTitle, !sourceTitle.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("一次根拠")
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink3)
                    Text(sourceTitle)
                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
            }

            Button(action: advance) {
                Text(currentIndex + 1 == questions.count ? "結果を見る" : "次の問題")
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(LearningSprintTheme.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hokenshi.quiz.next")
        }
        .padding(16)
        .background(evaluation.isCorrect ? LearningSprintTheme.greenSoft : LearningSprintTheme.vermilionSoft)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(evaluation.isCorrect ? LearningSprintTheme.green.opacity(0.35) : LearningSprintTheme.vermilion.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("hokenshi.quiz.feedback")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(LearningSprintTheme.gold)
            Text("監査済みの問題はまだありません")
                .font(LearningSprintTheme.serif(20, weight: .semibold))
            Text("一次根拠・正答・権利監査が完了した問題だけを表示します。")
                .font(LearningSprintTheme.sans(13))
                .foregroundStyle(LearningSprintTheme.ink2)
                .multilineTextAlignment(.center)
            Button("閉じる", action: onClose)
                .font(LearningSprintTheme.sans(14, weight: .bold))
                .frame(minWidth: 120, minHeight: 44)
        }
        .padding(24)
        .accessibilityIdentifier("hokenshi.quiz.empty")
    }

    private var currentQuestion: LearningQuestion {
        questions[currentIndex]
    }

    private func submit(_ answer: AnswerPayload) {
        errorMessage = nil
        do {
            evaluation = try LearningEngine.evaluate(currentQuestion, answer: answer)
        } catch LearningEngineError.missingAnswer {
            errorMessage = "回答を選択してください。"
        } catch {
            errorMessage = "この問題を採点できません。問題データ監査が必要です。"
        }
    }

    private func advance() {
        guard let evaluation else { return }
        var updated = evaluations
        updated.append(evaluation)
        evaluations = updated

        if currentIndex + 1 >= questions.count {
            onFinish(updated)
            return
        }

        currentIndex += 1
        selectedIndices = []
        numericText = ""
        self.evaluation = nil
        errorMessage = nil
    }

    private func choiceLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E", "F"]
        return index < labels.count ? labels[index] : "\(index + 1)"
    }
}
#endif
