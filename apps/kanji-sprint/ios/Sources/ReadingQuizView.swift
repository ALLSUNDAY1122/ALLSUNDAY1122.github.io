import SwiftUI

/// 読みクイズ（10問セット）。
/// 2モード: 漢字を見て読みを選ぶ／読みを見て漢字を選ぶ（mixed は問題ごとに切替）。
/// 選択肢は同じ学年のプールから生成し、正解と重複する読みは誤答に入れない。
struct ReadingQuizView: View {
    let title: String
    let mode: QuizMode
    @Binding var path: NavigationPath
    @EnvironmentObject private var records: StudyRecordStore

    @State private var items: [QuizItem]
    @State private var index = 0
    @State private var selected: Int?
    @State private var correctCount = 0
    @State private var wrongKanji: [KanjiEntry] = []
    @State private var finished = false
    @State private var sessionLogged = false

    init(title: String, entries: [KanjiEntry], mode: QuizMode, path: Binding<NavigationPath>) {
        self.title = title
        self.mode = mode
        _path = path
        _items = State(initialValue: Self.makeItems(entries: entries, mode: mode))
    }

    struct QuizItem: Identifiable {
        let id = UUID()
        let entry: KanjiEntry
        let isReadingToKanji: Bool
        /// readingToKanji のときの問題文（読み）。kanjiToReading のときは正解の読み。
        let promptReading: String
        let choices: [String]
        let correctIndex: Int
    }

    static func makeItems(entries: [KanjiEntry], mode: QuizMode) -> [QuizItem] {
        let store = KanjiStore.shared
        var result: [QuizItem] = []
        for entry in entries {
            let readings = entry.allReadings
            guard let target = readings.randomElement() else { continue }
            let readingToKanji: Bool
            switch mode {
            case .kanjiToReading: readingToKanji = false
            case .readingToKanji: readingToKanji = true
            case .mixed: readingToKanji = Bool.random()
            }
            let pool = store.byGrade[entry.grade] ?? []
            if readingToKanji {
                // その読みを持つ字は誤答にしない（正解が複数にならないように）。
                let distractors = pool
                    .filter { $0.kanji != entry.kanji && !$0.allReadings.contains(target) }
                    .shuffled()
                    .prefix(3)
                    .map(\.kanji)
                guard distractors.count == 3 else { continue }
                var choices = distractors + [entry.kanji]
                choices.shuffle()
                result.append(QuizItem(
                    entry: entry,
                    isReadingToKanji: true,
                    promptReading: target,
                    choices: choices,
                    correctIndex: choices.firstIndex(of: entry.kanji) ?? 0
                ))
            } else {
                let own = Set(readings)
                var distractorPool: [String] = []
                for other in pool where other.kanji != entry.kanji {
                    for reading in other.allReadings where !own.contains(reading) && !distractorPool.contains(reading) {
                        distractorPool.append(reading)
                    }
                }
                let distractors = Array(distractorPool.shuffled().prefix(3))
                guard distractors.count == 3 else { continue }
                var choices = distractors + [target]
                choices.shuffle()
                result.append(QuizItem(
                    entry: entry,
                    isReadingToKanji: false,
                    promptReading: target,
                    choices: choices,
                    correctIndex: choices.firstIndex(of: target) ?? 0
                ))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if finished {
                    resultView
                } else if items.isEmpty {
                    Text("問題を作れませんでした。")
                        .foregroundStyle(Palette.sub)
                } else {
                    quizView(items[index])
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func quizView(_ item: QuizItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(verbatim: "\(index + 1) / \(items.count) 問")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.sub)
                Spacer()
                Text(item.isReadingToKanji ? "読みを見て 漢字を選ぼう" : "漢字を見て 読みを選ぼう")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.navy)
            }
            questionCard(item)
            choicesView(item)
            if selected == nil {
                Button("わからない") { answer(-1, item: item) }
                    .buttonStyle(.bordered)
                    .tint(Palette.sub)
                    .frame(maxWidth: .infinity)
            } else {
                feedbackView(item)
                Button(index + 1 < items.count ? "次の問題へ" : "結果を見る") { next() }
                    .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
            }
        }
        .padding(.top, 8)
    }

    private func questionCard(_ item: QuizItem) -> some View {
        VStack(spacing: 8) {
            if item.isReadingToKanji {
                Text(item.promptReading)
                    .font(.maru(44))
                    .foregroundStyle(Palette.ink)
                Text(verbatim: "\(item.entry.grade)年生の漢字")
                    .font(.caption)
                    .foregroundStyle(Palette.sub)
            } else {
                Text(item.entry.kanji)
                    .font(.maru(84))
                    .foregroundStyle(Palette.ink)
                Text(verbatim: "\(item.entry.grade)年生・\(item.entry.strokeCount)画")
                    .font(.caption)
                    .foregroundStyle(Palette.sub)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func choicesView(_ item: QuizItem) -> some View {
        VStack(spacing: 10) {
            ForEach(item.choices.indices, id: \.self) { i in
                Button {
                    answer(i, item: item)
                } label: {
                    HStack {
                        Text(item.choices[i])
                            .font(item.isReadingToKanji
                                ? .maru(30)
                                : .title3.bold())
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        if let selected {
                            if i == item.correctIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Palette.good)
                            } else if i == selected {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Palette.bad)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(choiceBackground(item: item, choice: i), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
                }
                .buttonStyle(.plain)
                .disabled(selected != nil)
            }
        }
    }

    private func choiceBackground(item: QuizItem, choice: Int) -> Color {
        guard let selected else { return Palette.card }
        if choice == item.correctIndex { return Palette.good.opacity(0.16) }
        if choice == selected { return Palette.bad.opacity(0.14) }
        return Palette.card
    }

    private func feedbackView(_ item: QuizItem) -> some View {
        let isCorrect = selected == item.correctIndex
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(isCorrect ? "やったね！" : (selected == -1 ? "答えを見てみよう" : "おしい！"))
                    .font(.maru(17))
                    .foregroundStyle(isCorrect ? Palette.good : Palette.bad)
                if isCorrect {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Palette.good)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if !item.entry.onReadings.isEmpty {
                    Text(verbatim: "音読み：\(item.entry.onReadings.joined(separator: "・"))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                }
                if !item.entry.kunReadings.isEmpty {
                    Text(verbatim: "訓読み：\(item.entry.kunReadings.map(\.plain).joined(separator: "・"))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                }
            }
            Button("この字を見る") {
                path.append(KanjiRoute.detail(item.entry.kanji))
            }
            .font(.subheadline.bold())
            .tint(Palette.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Text("結果")
                    .font(.maru(21))
                    .foregroundStyle(Palette.ink)
                Text(verbatim: "\(items.count)問中 \(correctCount)問正解")
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                Text(verbatim: "正答率 \(items.isEmpty ? 0 : Int(Double(correctCount) / Double(items.count) * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            if !wrongKanji.isEmpty {
                Button {
                    restart(with: wrongKanji)
                } label: {
                    Text(verbatim: "苦手だけ復習する　\(wrongKanji.count)字")
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
            }
            Button("ホームへ戻る") { path = NavigationPath() }
                .buttonStyle(PrimaryButtonStyle(background: Palette.sub))
        }
        .padding(.top, 8)
    }

    private func answer(_ choice: Int, item: QuizItem) {
        guard selected == nil else { return }
        selected = choice
        let correct = choice == item.correctIndex
        if correct {
            correctCount += 1
        } else if !wrongKanji.contains(item.entry) {
            wrongKanji.append(item.entry)
        }
        records.record(kanji: item.entry.kanji, correct: correct)
    }

    private func next() {
        if index + 1 < items.count {
            index += 1
            selected = nil
        } else {
            finished = true
            if !sessionLogged {
                records.addSession(title: title, score: correctCount, total: items.count)
                sessionLogged = true
            }
        }
    }

    private func restart(with entries: [KanjiEntry]) {
        items = Self.makeItems(entries: entries, mode: mode)
        index = 0
        selected = nil
        correctCount = 0
        wrongKanji = []
        finished = false
        sessionLogged = false
    }
}
