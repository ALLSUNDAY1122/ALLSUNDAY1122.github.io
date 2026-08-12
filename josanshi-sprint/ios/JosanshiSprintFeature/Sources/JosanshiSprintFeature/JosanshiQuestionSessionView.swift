import SwiftUI
import LearningSprintCore

@MainActor
public struct JosanshiQuestionSessionView: View {
    @ObservedObject private var coordinator: JosanshiLearningCoordinator
    private let questionBank: JosanshiQuestionBankDocument?
    private let onFinish: () -> Void

    @State private var selectedIndices: Set<Int> = []
    @State private var submittedQuestion: LearningQuestion?
    @State private var submittedEvaluation: AnswerEvaluation?
    @State private var isFeedbackPresented = false
    @State private var errorMessage: String?

    public init(
        coordinator: JosanshiLearningCoordinator,
        questionBank: JosanshiQuestionBankDocument? = nil,
        onFinish: @escaping () -> Void = {}
    ) {
        self.coordinator = coordinator
        self.questionBank = questionBank
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            if isFeedbackPresented, let question = submittedQuestion, let evaluation = submittedEvaluation {
                feedback(question: question, evaluation: evaluation)
            } else if let question = coordinator.currentQuestion {
                questionBody(question)
            } else {
                completionBody
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("処理できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func questionBody(_ question: LearningQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(sessionTitle)
                        .font(LearningSprintTheme.sans(13, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.indigo)
                    Spacer()
                    Text(coordinator.sessionProgressText)
                        .font(LearningSprintTheme.sans(13, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                ProgressView(value: progressValue)
                    .tint(LearningSprintTheme.indigo)

                if let scenario = scenario(for: question) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("状況設定", systemImage: "person.text.rectangle")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.vermilion)
                        Text(scenario.scenarioText)
                            .font(LearningSprintTheme.sans(15))
                            .foregroundStyle(LearningSprintTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("scenario-text")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(question.subject)
                        .font(LearningSprintTheme.sans(12, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink3)
                    Text(question.prompt)
                        .font(LearningSprintTheme.serif(20, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        choiceButton(index: index, choice: choice, question: question)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        submitUnknown(question)
                    } label: {
                        Label("わからない", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(LearningSprintTheme.ink2)
                    .accessibilityIdentifier("answer-unknown")

                    Button {
                        submitSelection(question)
                    } label: {
                        Text("回答する")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                    .disabled(selectedIndices.isEmpty)
                    .accessibilityIdentifier("submit-answer")
                }
            }
            .padding(18)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private func choiceButton(index: Int, choice: String, question: LearningQuestion) -> some View {
        Button {
            if question.answerType == .singleChoice {
                selectedIndices = [index]
            } else if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(choiceLabel(index))
                    .font(LearningSprintTheme.sans(14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(selectedIndices.contains(index) ? LearningSprintTheme.indigo : LearningSprintTheme.paper2)
                    .foregroundStyle(selectedIndices.contains(index) ? Color.white : LearningSprintTheme.ink2)
                    .clipShape(Circle())

                Text(choice)
                    .font(LearningSprintTheme.sans(15))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(LearningSprintTheme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        selectedIndices.contains(index) ? LearningSprintTheme.indigo : LearningSprintTheme.rule,
                        lineWidth: selectedIndices.contains(index) ? 2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("choice-\(index)")
    }

    private func feedback(question: LearningQuestion, evaluation: AnswerEvaluation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: feedbackIcon(evaluation))
                        .font(.system(size: 34, weight: .semibold))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feedbackTitle(evaluation))
                            .font(LearningSprintTheme.serif(25, weight: .bold))
                        Text(evaluation.isUnknown ? "苦手復習へ登録しました" : "正答と根拠を確認してから次へ")
                            .font(LearningSprintTheme.sans(13))
                    }
                }
                .foregroundStyle(evaluation.isCorrect ? LearningSprintTheme.indigo : LearningSprintTheme.vermilion)

                if !evaluation.isUnknown {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("正答")
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink3)
                        Text(correctAnswerText(question))
                            .font(LearningSprintTheme.sans(16, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("解説")
                        .font(LearningSprintTheme.serif(20, weight: .bold))
                    Text(question.explanation)
                        .font(LearningSprintTheme.sans(15))
                        .foregroundStyle(LearningSprintTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LearningSprintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                LearningSprintMemoryBlock(question.memoryPoint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("根拠確認日: \(question.sourceCheckedAt)")
                    if let baseline = question.lawBaselineDate, !baseline.isEmpty {
                        Text("法令・制度基準日: \(baseline)")
                    }
                }
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink3)

                Button {
                    advanceAfterFeedback()
                } label: {
                    Text(coordinator.activeSession == nil ? "結果へ" : "次の問題")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(LearningSprintTheme.indigo)
                .accessibilityIdentifier("next-question")
            }
            .padding(18)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var completionBody: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(LearningSprintTheme.indigo)
            Text("セッション完了")
                .font(LearningSprintTheme.serif(26, weight: .bold))
            Text("記録は端末内に保存されました。")
                .font(LearningSprintTheme.sans(14))
                .foregroundStyle(LearningSprintTheme.ink2)
            Button("戻る", action: onFinish)
                .buttonStyle(.borderedProminent)
                .tint(LearningSprintTheme.indigo)
        }
        .padding(24)
    }

    private var sessionTitle: String {
        guard let kind = coordinator.activeSession?.kind else { return "演習" }
        switch kind {
        case .sprint: return "標準スプリント"
        case .subject(let subject): return subject
        case .weak: return "苦手復習"
        case .mock(let round): return "独自模試 \(round)"
        }
    }

    private var progressValue: Double {
        guard let session = coordinator.activeSession, !session.questionIDs.isEmpty else { return 0 }
        return Double(session.currentIndex + 1) / Double(session.questionIDs.count)
    }

    private func scenario(for question: LearningQuestion) -> JosanshiScenarioRecord? {
        guard let bank = questionBank,
              let production = bank.questions.first(where: { $0.id == question.id }) else { return nil }
        return bank.scenario(for: production)
    }

    private func submitSelection(_ question: LearningQuestion) {
        let payload = AnswerPayload(selectedIndices: selectedIndices.sorted())
        submit(question: question, payload: payload)
    }

    private func submitUnknown(_ question: LearningQuestion) {
        do {
            submittedQuestion = question
            submittedEvaluation = try coordinator.markUnknown()
            selectedIndices.removeAll()
            isFeedbackPresented = true
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func submit(question: LearningQuestion, payload: AnswerPayload) {
        do {
            submittedQuestion = question
            submittedEvaluation = try coordinator.submit(payload)
            selectedIndices.removeAll()
            isFeedbackPresented = true
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func advanceAfterFeedback() {
        isFeedbackPresented = false
        submittedQuestion = nil
        submittedEvaluation = nil
        selectedIndices.removeAll()
        if coordinator.activeSession == nil {
            onFinish()
        }
    }

    private func feedbackTitle(_ evaluation: AnswerEvaluation) -> String {
        if evaluation.isUnknown { return "わからない" }
        return evaluation.isCorrect ? "正解" : "不正解"
    }

    private func feedbackIcon(_ evaluation: AnswerEvaluation) -> String {
        if evaluation.isUnknown { return "questionmark.circle.fill" }
        return evaluation.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private func correctAnswerText(_ question: LearningQuestion) -> String {
        question.correctIndices
            .filter { question.choices.indices.contains($0) }
            .map { "\(choiceLabel($0)) \(question.choices[$0])" }
            .joined(separator: " / ")
    }

    private func choiceLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E"]
        return labels.indices.contains(index) ? labels[index] : String(index + 1)
    }
}
