import SwiftUI
import LearningSprintCore

struct TsukanshiStudyFlowView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject var session: TsukanshiStudySession
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                if session.isFinished {
                    resultView
                } else if let question = session.currentQuestion {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            header(question)
                            if session.isMock { mockTimer }
                            TsukanshiQuestionStepView(model: model, session: session, question: question)
                                .id(question.id)
                        }
                        .frame(maxWidth: 520, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .padding(.bottom, 24)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task(id: session.id) {
            guard session.isMock else { return }
            while !Task.isCancelled && !session.isFinished {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                now = Date()
                if mockRemainingSeconds <= 0 && !session.isFinished {
                    model.finishMock(session)
                }
            }
        }
    }

    private func header(_ question: LearningQuestion) -> some View {
        HStack(spacing: 10) {
            Button {
                model.closeSession(session)
            } label: {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("ホームへ戻る")
            VStack(alignment: .leading, spacing: 2) {
                Text(session.progressText)
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.indigo)
                Text("\(question.subject)・\(question.topic)")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink3)
                    .lineLimit(2)
            }
            Spacer()
            if question.premium {
                Label("Premium", systemImage: "lock.open.fill")
                    .font(LearningSprintTheme.sans(10, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.gold)
            }
        }
    }

    @ViewBuilder private var mockTimer: some View {
        let remaining = mockRemainingSeconds
        HStack {
            Label("模試", systemImage: "timer")
                .font(LearningSprintTheme.sans(12, weight: .bold))
            Spacer()
            Text(timeString(remaining))
                .font(LearningSprintTheme.serif(18, weight: .bold))
                .foregroundStyle(remaining < 300 ? LearningSprintTheme.vermilion : LearningSprintTheme.ink)
        }
        .padding(12)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("模擬試験の残り時間 \(timeString(remaining))")
    }

    private var mockDurationSeconds: Int {
        guard case .mock(let value) = session.kind else { return 0 }
        let subject = value.components(separatedBy: "|").last ?? ""
        switch subject {
        case "通関業法": return 50 * 60
        case "関税法等", "通関実務": return 100 * 60
        default: return 100 * 60
        }
    }

    private var mockRemainingSeconds: Int {
        max(0, mockDurationSeconds - Int(now.timeIntervalSince(session.startedAt)))
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var resultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(session.isMock ? "模試結果" : "スプリント結果")
                    .font(LearningSprintTheme.serif(32, weight: .bold))
                let total = session.questions.count
                let correct = session.correctCount
                let rate = total == 0 ? 0 : Double(correct) / Double(total)
                ZStack {
                    Circle().stroke(LearningSprintTheme.line, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: rate)
                        .stroke(LearningSprintTheme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(correct) / \(total)")
                            .font(LearningSprintTheme.serif(28, weight: .bold))
                        Text("\(Int((rate * 100).rounded()))%")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }
                }
                .frame(width: 150, height: 150)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("正答 \(correct)問、全\(total)問")

                LearningSprintMemoryBlock(
                    model.weakCount == 0
                    ? "現在の苦手登録はありません。"
                    : "苦手は\(model.weakCount)問。3連続正解で自動解除します。"
                )

                if session.isMock {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("解答確認")
                            .font(LearningSprintTheme.sans(15, weight: .bold))
                        ForEach(session.questions) { question in
                            HStack(alignment: .top) {
                                Image(systemName: session.evaluations[question.id]?.isCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(session.evaluations[question.id]?.isCorrect == true ? LearningSprintTheme.green : LearningSprintTheme.vermilion)
                                Text(question.topic)
                                    .font(LearningSprintTheme.sans(12, weight: .semibold))
                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    model.closeSession(session)
                } label: {
                    Text("ホームへ戻る")
                        .font(LearningSprintTheme.sans(16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(LearningSprintTheme.indigo)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(20)
        }
    }
}

struct TsukanshiQuestionStepView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject var session: TsukanshiStudySession
    let question: LearningQuestion

    @State private var selected = Set<Int>()
    @State private var numericText = ""
    @State private var blankValues: [String: String] = [:]
    @State private var declarationValues: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(question.prompt)
                .font(LearningSprintTheme.serif(19, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("問題。\(question.prompt)")

            if let sourceText = question.sourceText, !sourceText.isEmpty {
                Text(sourceText)
                    .font(LearningSprintTheme.serif(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .padding(12)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            answerInput

            if !session.isMock, let evaluation = session.currentEvaluation {
                feedback(evaluation)
            } else if session.isMock {
                mockNavigation
            }
        }
        .onAppear(perform: restoreDraft)
    }

    @ViewBuilder private var answerInput: some View {
        switch question.answerType {
        case .singleChoice:
            VStack(spacing: 9) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    choiceButton(index: index, text: choice, selected: selected.contains(index)) {
                        guard session.currentEvaluation == nil else { return }
                        selected = [index]
                        if session.isMock {
                            model.submit(AnswerPayload(selectedIndices: [index]), in: session)
                        } else {
                            model.submit(AnswerPayload(selectedIndices: [index]), in: session)
                        }
                    }
                }
            }

        case .multiChoice:
            VStack(alignment: .leading, spacing: 9) {
                Text("\(selected.count) / \(question.correctIndices.count) 選択")
                    .font(LearningSprintTheme.sans(12, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink3)
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    choiceButton(index: index, text: choice, selected: selected.contains(index)) {
                        guard session.currentEvaluation == nil else { return }
                        if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
                        if session.isMock {
                            model.submit(AnswerPayload(selectedIndices: selected.sorted()), in: session)
                        }
                    }
                }
                if !session.isMock {
                    gradingButton(title: "採点する", enabled: !selected.isEmpty) {
                        model.submit(AnswerPayload(selectedIndices: selected.sorted()), in: session)
                    }
                }
            }

        case .numeric:
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    TextField("数値を入力", text: $numericText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("解答数値")
                    if let unit = question.unit { Text(unit).font(LearningSprintTheme.sans(14, weight: .bold)) }
                }
                if session.isMock {
                    Button("入力を保存") {
                        model.submit(numericPayload(), in: session)
                    }
                    .disabled(Double(normalizedNumber(numericText)) == nil)
                } else {
                    gradingButton(title: "採点する", enabled: Double(normalizedNumber(numericText)) != nil) {
                        model.submit(numericPayload(), in: session)
                    }
                }
            }

        case .blankSelect:
            VStack(alignment: .leading, spacing: 10) {
                ForEach(question.blanks, id: \.key) { blank in
                    HStack {
                        Text(blank.label)
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Spacer()
                        Menu(blankValues[blank.key] ?? "選択") {
                            ForEach(blank.options, id: \.self) { option in
                                Button(option) {
                                    blankValues[blank.key] = option
                                    if session.isMock { model.submit(blankPayload(), in: session) }
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
                if !session.isMock {
                    gradingButton(title: "採点する", enabled: blankValues.count == question.blanks.count) {
                        model.submit(blankPayload(), in: session)
                    }
                }
            }

        case .declaration:
            VStack(alignment: .leading, spacing: 10) {
                Text("申告書入力")
                    .font(LearningSprintTheme.sans(14, weight: .bold))
                ForEach(question.declarationFields, id: \.key) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.label)
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                        TextField("入力", text: Binding(
                            get: { declarationValues[field.key, default: ""] },
                            set: { declarationValues[field.key] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(field.label)
                    }
                }
                if session.isMock {
                    Button("入力を保存") { model.submit(declarationPayload(), in: session) }
                        .disabled(!declarationReady)
                } else {
                    gradingButton(title: "採点する", enabled: declarationReady) {
                        model.submit(declarationPayload(), in: session)
                    }
                }
            }
        }

        if session.currentEvaluation == nil {
            Button {
                model.submit(.unknown, in: session)
                if session.isMock { model.advance(session) }
            } label: {
                Text("わからない")
                    .font(LearningSprintTheme.sans(14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(LearningSprintTheme.ink2)
            .accessibilityHint("この問題をわからないとして記録し、苦手に登録します")
        }
    }

    private func choiceButton(index: Int, text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(selected ? LearningSprintTheme.indigo : LearningSprintTheme.indigoSoft)
                    .foregroundStyle(selected ? Color.white : LearningSprintTheme.indigo)
                    .clipShape(Circle())
                Text(text)
                    .font(LearningSprintTheme.serif(16))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(selected ? LearningSprintTheme.indigoSoft : LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? LearningSprintTheme.indigo : LearningSprintTheme.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("選択肢\(index + 1)、\(text)")
        .accessibilityValue(selected ? "選択中" : "未選択")
    }

    private func gradingButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(LearningSprintTheme.sans(16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .tint(LearningSprintTheme.indigo)
        .disabled(!enabled || session.currentEvaluation != nil)
    }

    private func feedback(_ evaluation: AnswerEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(evaluation.isCorrect ? "○" : "×")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(evaluation.isCorrect ? LearningSprintTheme.vermilion : LearningSprintTheme.vermilion)
                    .rotationEffect(.degrees(evaluation.isCorrect ? -7 : 6))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(evaluation.isCorrect ? "正解" : evaluation.isUnknown ? "わからない" : "不正解")
                        .font(LearningSprintTheme.serif(24, weight: .bold))
                    Text(evaluation.isCorrect ? "この調子で進みます。" : "苦手に登録しました。")
                        .font(LearningSprintTheme.sans(12))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
            }
            .accessibilityElement(children: .combine)

            LearningSprintMemoryBlock(question.memoryPoint)

            VStack(alignment: .leading, spacing: 6) {
                Text("解説")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                Text(question.explanation)
                    .font(LearningSprintTheme.serif(15))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("根拠")
                    .font(LearningSprintTheme.sans(11, weight: .bold))
                if let title = question.sourceTitle { Text(title).font(LearningSprintTheme.sans(11)) }
                Text("確認日 \(question.sourceCheckedAt)／法令基準 \(question.lawBaselineDate)")
                    .font(LearningSprintTheme.sans(10))
                    .foregroundStyle(LearningSprintTheme.ink3)
                if let sourceURL = question.sourceURL, let url = URL(string: sourceURL) {
                    Link("一次資料を開く", destination: url)
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                }
            }

            Button {
                model.advance(session)
            } label: {
                Text(session.currentIndex + 1 == session.questions.count ? "結果を見る" : "次の問題")
                    .font(LearningSprintTheme.sans(16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(LearningSprintTheme.indigo)
        }
    }

    private var mockNavigation: some View {
        VStack(spacing: 9) {
            if session.answers[question.id] != nil {
                Button {
                    if session.currentIndex + 1 == session.questions.count {
                        model.finishMock(session)
                    } else {
                        model.advance(session)
                    }
                } label: {
                    Text(session.currentIndex + 1 == session.questions.count ? "採点する" : "次の問題")
                        .font(LearningSprintTheme.sans(16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(LearningSprintTheme.indigo)
            } else {
                Text("回答を選ぶか「わからない」を押してください。")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
        }
    }

    private func numericPayload() -> AnswerPayload {
        AnswerPayload(numberValue: Double(normalizedNumber(numericText)))
    }

    private func blankPayload() -> AnswerPayload {
        AnswerPayload(blankValues: blankValues)
    }

    private func declarationPayload() -> AnswerPayload {
        AnswerPayload(declarationValues: declarationValues)
    }

    private var declarationReady: Bool {
        question.declarationFields.allSatisfy { !(declarationValues[$0.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func normalizedNumber(_ value: String) -> String {
        value.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
    }

    private func restoreDraft() {
        guard let payload = session.answers[question.id] else { return }
        selected = Set(payload.selectedIndices)
        if let value = payload.numberValue { numericText = String(value) }
        blankValues = payload.blankValues
        declarationValues = payload.declarationValues
    }
}
