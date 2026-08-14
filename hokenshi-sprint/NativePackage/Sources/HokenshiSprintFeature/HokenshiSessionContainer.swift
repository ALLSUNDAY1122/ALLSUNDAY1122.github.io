#if canImport(SwiftUI)
import SwiftUI
import LearningSprintCore

public struct HokenshiSessionContainer: View {
    private let questions: [LearningQuestion]
    private let title: String
    private let startIndex: Int
    private let onAdvance: (LearningQuestion, AnswerPayload, AnswerEvaluation, Int, Int) -> [AnswerEvaluation]?
    private let onClose: () -> Void
    @State private var result: [AnswerEvaluation]?

    public init(
        questions: [LearningQuestion],
        title: String,
        startIndex: Int = 0,
        onAdvance: @escaping (LearningQuestion, AnswerPayload, AnswerEvaluation, Int, Int) -> [AnswerEvaluation]?,
        onClose: @escaping () -> Void
    ) {
        self.questions = questions
        self.title = title
        self.startIndex = startIndex
        self.onAdvance = onAdvance
        self.onClose = onClose
    }

    public var body: some View {
        if let result {
            resultView(result)
        } else {
            HokenshiProductQuizView(
                questions: questions,
                title: title,
                startIndex: startIndex,
                onAdvance: onAdvance,
                onFinish: { result = $0 },
                onClose: onClose
            )
        }
    }

    private func resultView(_ evaluations: [AnswerEvaluation]) -> some View {
        let correct = evaluations.filter(\.isCorrect).count
        let unknown = evaluations.filter(\.isUnknown).count
        return ZStack {
            LearningSprintPaperBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: correct == evaluations.count ? "seal.fill" : "checkmark.seal")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text("SPRINT COMPLETE")
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(LearningSprintTheme.ink3)
                    Text(title)
                        .font(LearningSprintTheme.serif(28, weight: .bold))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 4) {
                        Text("\(correct) / \(evaluations.count)")
                            .font(LearningSprintTheme.serif(38, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.indigo)
                        Text("正解")
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    HStack(spacing: 10) {
                        metric("わからない", value: unknown)
                        metric("復習へ", value: evaluations.count - correct)
                    }
                    Text("間違えた問題と「わからない」は苦手へ入り、3回連続正解すると解除されます。")
                        .font(LearningSprintTheme.sans(13))
                        .foregroundStyle(LearningSprintTheme.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    Button(action: onClose) {
                        Text("ホームへ戻る")
                            .font(LearningSprintTheme.sans(15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(LearningSprintTheme.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 520)
                .padding(20)
            }
        }
        .accessibilityIdentifier("hokenshi.result")
    }

    private func metric(_ title: String, value: Int) -> some View {
        VStack(spacing: 5) {
            Text("\(value)").font(LearningSprintTheme.serif(23, weight: .bold))
            Text(title).font(LearningSprintTheme.sans(11, weight: .bold)).foregroundStyle(LearningSprintTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
#endif
