import SwiftUI
import LearningSprintCore

struct RigakuStudySessionView: View {
    @ObservedObject var model: RigakuAppModel
    let kind: SessionKind
    let questions: [LearningQuestion]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var selectedIndices: Set<Int> = []
    @State private var evaluation: AnswerEvaluation?
    @State private var correctness: [String: Bool] = [:]
    @State private var completed = false
    @State private var errorMessage: String?

    init(
        model: RigakuAppModel,
        kind: SessionKind,
        questions: [LearningQuestion],
        resumeIndex: Int = 0
    ) {
        self.model = model
        self.kind = kind
        self.questions = questions
        let safeIndex = questions.isEmpty ? 0 : min(max(0, resumeIndex), questions.count - 1)
        _currentIndex = State(initialValue: safeIndex)
    }

    var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            if questions.isEmpty {
                emptyState
            } else if completed {
                resultView
            } else {
                studyBody
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(sessionTitle)
        .onAppear {
            if correctness.isEmpty {
                correctness = model.resumeCorrectness()
            }
            if model.state.resumeSession == nil && !questions.isEmpty {
                model.beginSession(kind: kind, questions: questions)
            }
        }
        .alert("学習を続けられません", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var studyBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sessionHeader
                questionCard(question: currentQuestion)
                choices(for: currentQuestion)
                if currentQuestion.answerType == .multiChoice && evaluation == nil {
                    Button("回答する") {
                        submitSelectedAnswer()
                    }
                    .buttonStyle(PrimaryStudyButtonStyle())
                    .disabled(selectedIndices.isEmpty)
                    .opacity(selectedIndices.isEmpty ? 0.45 : 1)
                }
                if evaluation == nil {
                    Button("わからない") {
                        submit(.unknown)
                    }
                    .buttonStyle(UnknownStudyButtonStyle())
                }
                if let evaluation {
                    feedback(evaluation: evaluation, question: currentQuestion)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var sessionHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sessionTitle)
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.indigo)
                Text("\(currentIndex + 1) / \(questions.count)")
                    .font(LearningSprintTheme.sans(12, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink2)
            }
            Spacer()
            ProgressView(value: Double(currentIndex + 1), total: Double(max(1, questions.count)))
                .tint(LearningSprintTheme.indigo)
                .frame(maxWidth: 150)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sessionTitle)、\(currentIndex + 1)問目、全\(questions.count)問")
    }

    private func questionCard(question: LearningQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(question.subject)
                    .font(LearningSprintTheme.sans(12, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.indigo)
                Spacer()
                if case .mock = kind, let points = model.officialPoints(for: question.id) {
                    Text(points == 0 ? "採点除外" : "\(points)点")
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                        .foregroundStyle(points == 0 ? LearningSprintTheme.vermilion : LearningSprintTheme.ink2)
                }
            }
            Text(question.prompt)
                .font(LearningSprintTheme.serif(questionFontSize, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("問題。\(question.prompt)")
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LearningSprintTheme.line, lineWidth: 1)
        )
    }

    private func choices(for question: LearningQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    guard evaluation == nil else { return }
                    if question.answerType == .multiChoice {
                        if selectedIndices.contains(index) {
                            selectedIndices.remove(index)
                        } else {
                            selectedIndices.insert(index)
                        }
                    } else {
                        selectedIndices = [index]
                        submitSelectedAnswer()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(index + 1))
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(choiceNumberForeground(index: index, question: question))
                            .background(choiceNumberBackground(index: index, question: question))
                            .clipShape(Circle())
                        Text(choice)
                            .font(LearningSprintTheme.sans(choiceFontSize, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(choiceBackground(index: index, question: question))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(choiceBorder(index: index, question: question), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(evaluation != nil)
                .accessibilityLabel("選択肢\(index + 1)、\(choice)")
                .accessibilityAddTraits(selectedIndices.contains(index) ? .isSelected : [])
            }
        }
    }

    private func feedback(evaluation: AnswerEvaluation, question: LearningQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(evaluation.isCorrect ? "○" : "×")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(evaluation.isCorrect ? LearningSprintTheme.vermilion : LearningSprintTheme.vermilion)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(evaluation.isUnknown ? "わからない" : (evaluation.isCorrect ? "正解" : "不正解"))
                        .font(LearningSprintTheme.serif(22, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    if !evaluation.isCorrect {
                        Text(correctAnswerText(for: question))
                            .font(LearningSprintTheme.sans(13, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                }
            }

            Text(question.explanation)
                .font(LearningSprintTheme.serif(questionFontSize))
                .foregroundStyle(LearningSprintTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            LearningSprintMemoryBlock(question.memoryPoint)

            Button(currentIndex + 1 < questions.count ? "次の問題" : "結果を見る") {
                advance()
            }
            .buttonStyle(PrimaryStudyButtonStyle())
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 38))
                .foregroundStyle(LearningSprintTheme.indigo)
            Text("監査済み問題を準備中です")
                .font(LearningSprintTheme.serif(20, weight: .bold))
            Text("問題・正答・解説・根拠・権利の監査を通過した問題だけを表示します。")
                .font(LearningSprintTheme.sans(14))
                .foregroundStyle(LearningSprintTheme.ink2)
                .multilineTextAlignment(.center)
            Button("戻る") { dismiss() }
                .buttonStyle(PrimaryStudyButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: 420)
    }

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("結果")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)

                if case .mock(let round) = kind,
                   let score = model.mockScore(round: round, questions: questions, correctness: correctness) {
                    VStack(spacing: 8) {
                        Text("\(score.totalPoints) / \(score.totalMax) 点")
                            .font(LearningSprintTheme.serif(32, weight: .bold))
                        Text("実地 \(score.practicalPoints) / \(score.practicalMax) 点")
                            .font(LearningSprintTheme.sans(15, weight: .bold))
                        Text("一般 \(score.generalPoints) / \(score.generalMax) 点")
                            .font(LearningSprintTheme.sans(15, weight: .bold))
                        Text(score.passed ? "合格基準到達" : "合格基準未到達")
                            .font(LearningSprintTheme.sans(15, weight: .bold))
                            .foregroundStyle(score.passed ? LearningSprintTheme.green : LearningSprintTheme.vermilion)
                        Text("合格基準：総得点\(score.passTotal)点以上かつ実地\(score.passPractical)点以上")
                            .font(LearningSprintTheme.sans(12))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    let correct = correctness.values.filter { $0 }.count
                    Text("\(correct) / \(questions.count) 問正解")
                        .font(LearningSprintTheme.serif(30, weight: .bold))
                    Text(resultMessage(correct: correct, total: questions.count))
                        .font(LearningSprintTheme.serif(18, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Button("ホームへ戻る") { dismiss() }
                    .buttonStyle(PrimaryStudyButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var currentQuestion: LearningQuestion {
        questions[currentIndex]
    }

    private var questionFontSize: CGFloat {
        switch model.state.textSizeStep {
        case 0: return 15
        case 2: return 20
        default: return 17
        }
    }

    private var choiceFontSize: CGFloat {
        switch model.state.textSizeStep {
        case 0: return 14
        case 2: return 18
        default: return 16
        }
    }

    private var sessionTitle: String {
        switch kind {
        case .sprint: return "今日のスプリント"
        case .weak: return "苦手をつぶす"
        case .subject(let subject): return subject
        case .mock(let round): return "第\(round)回ベース模試"
        }
    }

    private func submitSelectedAnswer() {
        submit(AnswerPayload(selectedIndices: selectedIndices.sorted()))
    }

    private func submit(_ answer: AnswerPayload) {
        guard evaluation == nil else { return }
        do {
            let result = try model.recordAnswer(
                question: currentQuestion,
                answer: answer,
                advanceTo: min(currentIndex + 1, questions.count)
            )
            correctness[currentQuestion.id] = result.isCorrect
            evaluation = result
        } catch {
            errorMessage = "回答を採点できませんでした。"
        }
    }

    private func advance() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            selectedIndices = []
            evaluation = nil
        } else {
            model.finishSession()
            completed = true
        }
    }

    private func correctAnswerText(for question: LearningQuestion) -> String {
        let sets = question.acceptedIndexSets?.isEmpty == false
            ? question.acceptedIndexSets!
            : [question.correctIndices]
        let labels = sets.map { pattern in
            pattern.sorted().map { String($0 + 1) }.joined(separator: "・")
        }
        return "正答：" + labels.joined(separator: " または ")
    }

    private func choiceBackground(index: Int, question: LearningQuestion) -> Color {
        guard let evaluation else {
            return selectedIndices.contains(index) ? LearningSprintTheme.indigoSoft : LearningSprintTheme.card
        }
        if isCorrectIndex(index, question: question) {
            return LearningSprintTheme.greenSoft
        }
        if selectedIndices.contains(index) && !evaluation.isCorrect {
            return LearningSprintTheme.vermilionSoft
        }
        return LearningSprintTheme.card
    }

    private func choiceBorder(index: Int, question: LearningQuestion) -> Color {
        guard evaluation != nil else {
            return selectedIndices.contains(index) ? LearningSprintTheme.indigo : LearningSprintTheme.line
        }
        if isCorrectIndex(index, question: question) { return LearningSprintTheme.green }
        if selectedIndices.contains(index) { return LearningSprintTheme.vermilion }
        return LearningSprintTheme.line
    }

    private func choiceNumberBackground(index: Int, question: LearningQuestion) -> Color {
        if evaluation != nil && isCorrectIndex(index, question: question) { return LearningSprintTheme.green }
        if evaluation != nil && selectedIndices.contains(index) { return LearningSprintTheme.vermilion }
        if selectedIndices.contains(index) { return LearningSprintTheme.indigo }
        return LearningSprintTheme.indigoSoft
    }

    private func choiceNumberForeground(index: Int, question: LearningQuestion) -> Color {
        if evaluation != nil && (isCorrectIndex(index, question: question) || selectedIndices.contains(index)) { return .white }
        if selectedIndices.contains(index) { return .white }
        return LearningSprintTheme.indigo
    }

    private func isCorrectIndex(_ index: Int, question: LearningQuestion) -> Bool {
        let alternatives = question.acceptedIndexSets?.isEmpty == false
            ? question.acceptedIndexSets!
            : [question.correctIndices]
        return alternatives.contains { $0.contains(index) }
    }

    private func resultMessage(correct: Int, total: Int) -> String {
        guard total > 0 else { return "" }
        let rate = Double(correct) / Double(total)
        if rate >= 0.9 { return "かなり仕上がっています。" }
        if rate >= 0.7 { return "苦手をもう一度つぶしましょう。" }
        return "解説を使って論点を積み直しましょう。"
    }
}

private struct PrimaryStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LearningSprintTheme.sans(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(LearningSprintTheme.indigo.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct UnknownStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LearningSprintTheme.sans(15, weight: .bold))
            .foregroundStyle(LearningSprintTheme.vermilion)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(LearningSprintTheme.vermilionSoft.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LearningSprintTheme.vermilion.opacity(0.35), lineWidth: 1)
            )
    }
}
