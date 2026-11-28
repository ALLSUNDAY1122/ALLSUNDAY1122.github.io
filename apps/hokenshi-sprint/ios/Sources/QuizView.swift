import SwiftUI

/// 演習画面。4択・5択（single）、2つ選べ（multi）、数値入力（numeric）に対応。
/// 数値入力は本試験の解答欄と同じく、答えの形式どおりの桁ボックスに
/// 1桁ずつ入力する。
struct QuizView: View {
    let title: String
    let questions: [Question]

    @EnvironmentObject private var records: StudyRecordStore
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var selected: Set<Int> = []
    @State private var digits: [String] = []
    @State private var answered = false
    @State private var lastCorrect = false
    @State private var gaveUp = false
    @State private var score = 0
    @State private var finished = false
    @State private var showFigureFull = false

    private var question: Question { questions[index] }

    private var digitTemplate: [Character] {
        Array(question.numericAnswer)
    }

    private var digitSlots: Int {
        digitTemplate.filter { $0 != "." }.count
    }

    private var enteredNumeric: String {
        var result = ""
        var digitIndex = 0
        for ch in digitTemplate {
            if ch == "." {
                result.append(".")
            } else {
                result.append(digitIndex < digits.count ? digits[digitIndex] : "")
                digitIndex += 1
            }
        }
        return result
    }

    private var canAnswer: Bool {
        if question.isNumeric {
            return digits.count == digitSlots
        }
        if question.isMulti {
            return selected.count == 2
        }
        return selected.count == 1
    }

    var body: some View {
        Group {
            if finished {
                resultView
            } else if questions.isEmpty {
                ContentUnavailableView("問題がありません", systemImage: "tray")
            } else {
                quizBody
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Palette.paper)
        .onAppear { resetInput() }
    }

    // MARK: - 問題表示

    private var quizBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                progressHeader
                if !question.context.isEmpty {
                    Text(question.context)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.tealSoft, in: RoundedRectangle(cornerRadius: 12))
                }
                Text(question.stem)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if question.figure {
                    figureView
                }
                if question.isNumeric {
                    numericInputView
                } else {
                    choicesView
                }
                if answered {
                    answerResultView
                } else {
                    HStack(spacing: 12) {
                        if !question.isNumeric {
                            Button("わからない") { answer(gaveUp: true) }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.sub)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
                        }
                        Button("回答する") { answer(gaveUp: false) }
                            .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
                            .disabled(!canAnswer)
                            .opacity(canAnswer ? 1 : 0.45)
                    }
                }
            }
            .padding(16)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(question.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.teal)
                Spacer()
                Text("\(index + 1) / \(questions.count) 問")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.sub)
                if records.isWeak(question.id) {
                    Text("復習中")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.accent, in: Capsule())
                }
            }
            ProgressView(value: Double(index + 1), total: Double(questions.count))
                .tint(Palette.teal)
        }
    }

    private var figureView: some View {
        Group {
            if let image = FigureStore.shared.image(for: question.id) {
                Button { showFigureFull = true } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showFigureFull) {
                    NavigationStack {
                        ScrollView {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .padding(12)
                        }
                        .navigationTitle("図表")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("閉じる") { showFigureFull = false }
                            }
                        }
                    }
                }
            }
        }
    }

    private var choicesView: some View {
        VStack(spacing: 10) {
            if question.isMulti {
                Text("2つ選んでください")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(question.choices.indices, id: \.self) { i in
                choiceRow(i)
            }
        }
    }

    private func choiceRow(_ i: Int) -> some View {
        let isSelected = selected.contains(i + 1)
        let isCorrectChoice = question.correctChoices.contains(i + 1)
        var background = Palette.card
        var border = Palette.line
        if answered {
            if isCorrectChoice {
                background = Palette.good.opacity(0.12)
                border = Palette.good
            } else if isSelected {
                background = Palette.bad.opacity(0.10)
                border = Palette.bad
            }
        } else if isSelected {
            background = Palette.tealSoft
            border = Palette.teal
        }
        return Button {
            guard !answered else { return }
            if question.isMulti {
                if isSelected {
                    selected.remove(i + 1)
                } else if selected.count < 2 {
                    selected.insert(i + 1)
                }
            } else {
                selected = [i + 1]
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text("\(i + 1)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected || (answered && isCorrectChoice) ? Palette.teal : Palette.sub)
                    .frame(width: 26, height: 26)
                    .background(Circle().stroke(border, lineWidth: 1.5))
                Text(question.choices[i])
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                if answered && isCorrectChoice {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.good)
                }
            }
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数値入力

    private var numericInputView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                let digitCount = digitSlots
                ForEach(digitTemplate.indices, id: \.self) { i in
                    if digitTemplate[i] == "." {
                        Text(".")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 14)
                    } else {
                        let slot = digitTemplate[..<i].filter { $0 != "." }.count
                        Text(slot < digits.count ? digits[slot] : " ")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 56)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(slot == digits.count && !answered ? Palette.teal : Palette.line,
                                            lineWidth: slot == digits.count && !answered ? 2 : 1.2))
                    }
                }
                if digitCount == 0 { EmptyView() }
            }
            .frame(maxWidth: .infinity)
            if !answered {
                keypad
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["C", "0", "⌫"]], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tapKey(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func tapKey(_ key: String) {
        if key == "C" {
            digits = []
        } else if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
        } else if digits.count < digitSlots {
            digits.append(key)
        }
    }

    // MARK: - 回答・解説

    private var answerResultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(lastCorrect ? Palette.good : Palette.bad)
                    .font(.system(size: 22))
                Text(gaveUp ? "正解はこちら" : (lastCorrect ? "正解！" : "不正解"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("正解: \(correctAnswerText)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.teal)
            }
            if !question.explanation.isEmpty {
                Text(question.explanation)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !question.note.isEmpty {
                Text(question.note)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(index + 1 < questions.count ? "次の問題へ" : "結果を見る") { next() }
                .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
    }

    private var correctAnswerText: String {
        if question.isNumeric { return question.numericAnswer }
        return question.correctChoices.map(String.init).joined(separator: " と ")
    }

    private func answer(gaveUp: Bool) {
        self.gaveUp = gaveUp
        let correct: Bool
        if gaveUp {
            correct = false
        } else if question.isNumeric {
            correct = enteredNumeric == question.numericAnswer
        } else {
            correct = Set(question.correctChoices) == selected
        }
        lastCorrect = correct
        if correct { score += 1 }
        answered = true
        records.record(questionID: question.id, correct: correct)
    }

    private func next() {
        if index + 1 < questions.count {
            index += 1
            resetInput()
        } else {
            finished = true
            records.addSession(title: title, score: score, total: questions.count)
        }
    }

    private func resetInput() {
        selected = []
        digits = []
        answered = false
        lastCorrect = false
        gaveUp = false
    }

    // MARK: - 結果

    private var resultView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 52))
                .foregroundStyle(Palette.teal)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.sub)
            Text("\(score) / \(questions.count) 問正解")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.ink)
            if !questions.isEmpty {
                Text("正答率 \(Int(Double(score) / Double(questions.count) * 100))%")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.ink)
            }
            VStack(spacing: 10) {
                Button("もう一度解く") {
                    index = 0
                    score = 0
                    finished = false
                    resetInput()
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
                Button("ホームへ戻る") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.teal)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
    }
}
