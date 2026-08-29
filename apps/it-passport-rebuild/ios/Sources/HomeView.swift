import SwiftUI

private struct StudyDomain: Identifiable, Hashable {
    let id: String
    let title: String
}

private struct QuestionSet: Identifiable, Hashable {
    let id: Int
    let start: Int
    let end: Int

    var title: String { "セット \(id)" }
    var subtitle: String { "問題 \(start)〜\(end)" }
}

private enum Palette {
    static let paper = Color(red: 247/255, green: 243/255, blue: 234/255)
    static let card = Color(red: 1.0, green: 253/255, blue: 249/255)
    static let navy = Color(red: 47/255, green: 74/255, blue: 109/255)
    static let line = Color(red: 232/255, green: 223/255, blue: 207/255)
}

struct HomeView: View {
    private let domains = [
        StudyDomain(id: "strategy", title: "ストラテジ系"),
        StudyDomain(id: "management", title: "マネジメント系"),
        StudyDomain(id: "technology", title: "テクノロジ系")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayCard
                    Text("分野から解く")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    domainGrid
                    sourceNotice
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.navy)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("学びスプリント")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("ITパスポート")
                .font(.system(size: 31, weight: .bold, design: .serif))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("今日も1問、力に変える。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    private var todayCard: some View {
        let daily = QuestionStore.daily(limit: 8)
        return VStack(alignment: .leading, spacing: 10) {
            Text("今日の学習")
                .font(.system(size: 21, weight: .bold, design: .serif))
            Text("3分野を交互に8問。まずは短い1セットから。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NavigationLink {
                QuizView(title: "今日のスプリント", questions: daily)
            } label: {
                Text("今日のスプリントを始める　\(daily.count)問")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
            .disabled(daily.isEmpty)
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private var domainGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(domains) { domain in
                let count = QuestionStore.questions(domain: domain.id).count
                NavigationLink {
                    DomainSetView(domain: domain)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(domain.title)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        Text("\(count)問")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        HStack {
                            Text("10問ずつ選ぶ")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Palette.navy)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
                }
                .buttonStyle(.plain)
                .gridCellColumns(domain.id == "technology" ? 2 : 1)
            }
        }
    }

    private var sourceNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("問題品質を優先して段階追加中", systemImage: "checkmark.shield")
                .font(.subheadline.bold())
            Text("現在はシラバスVer.6.5準拠の独自問題スターター30問を接続。監査済み問題だけを追加します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
    }
}

private struct DomainSetView: View {
    let domain: StudyDomain

    private var questions: [StudyQuestion] { QuestionStore.questions(domain: domain.id) }
    private var sets: [QuestionSet] {
        stride(from: 0, to: questions.count, by: 10).enumerated().map { offset, start in
            QuestionSet(id: offset + 1, start: start + 1, end: min(start + 10, questions.count))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(domain.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Text("全\(questions.count)問を10問ずつのセットに分割")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(sets) { set in
                    let slice = Array(questions[(set.start - 1)..<set.end])
                    NavigationLink {
                        QuizView(title: "\(domain.title)・\(set.title)", questions: slice)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.title).font(.headline)
                                Text("\(set.subtitle)・\(slice.count)問")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.navy)
                        }
                        .padding(16)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(domain.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuizView: View {
    let title: String
    let questions: [StudyQuestion]

    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var correctCount = 0
    @State private var finished = false

    private var current: StudyQuestion? {
        guard questions.indices.contains(index) else { return nil }
        return questions[index]
    }

    var body: some View {
        ScrollView {
            if finished {
                resultView
            } else if let q = current {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(q.category).font(.caption.bold()).foregroundStyle(Palette.navy)
                        Spacer()
                        Text("\(index + 1) / \(questions.count)").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(index), total: Double(max(questions.count, 1)))
                        .tint(Palette.navy)
                    Text(q.question)
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .lineSpacing(5)

                    ForEach(q.choices.indices, id: \.self) { choiceIndex in
                        Button {
                            answer(choiceIndex, question: q)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(["ア", "イ", "ウ", "エ"][choiceIndex]).font(.headline)
                                Text(q.choices[choiceIndex]).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(15)
                            .foregroundStyle(choiceForeground(choiceIndex, q: q))
                            .background(choiceBackground(choiceIndex, q: q), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(choiceBorder(choiceIndex, q: q), lineWidth: 1.4))
                        }
                        .buttonStyle(.plain)
                        .disabled(selected != nil)
                    }

                    if selected != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selected == q.correctIndex ? "正解" : "不正解")
                                .font(.headline)
                            Text(q.explanation).font(.subheadline)
                            Text("出典根拠：\(q.primaryEvidence)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(index + 1 == questions.count ? "結果を見る" : "次の問題") {
                                advance()
                            }
                            .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
                        }
                        .padding(16)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
                    }
                }
                .padding(18)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(Palette.navy)
                    Text("問題がありません")
                        .font(.headline)
                    Text("問題データの読み込み状態を確認してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered").font(.system(size: 42)).foregroundStyle(Palette.navy)
            Text("セット完了").font(.system(size: 28, weight: .bold, design: .serif))
            Text("\(questions.count)問中 \(correctCount)問正解")
                .font(.title3.bold())
            Text("正答率 \(questions.isEmpty ? 0 : Int(Double(correctCount) / Double(questions.count) * 100))%")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .padding(18)
    }

    private func answer(_ choice: Int, question: StudyQuestion) {
        guard selected == nil else { return }
        selected = choice
        if choice == question.correctIndex { correctCount += 1 }
    }

    private func advance() {
        if index + 1 >= questions.count {
            finished = true
        } else {
            index += 1
            selected = nil
        }
    }

    private func choiceBackground(_ choice: Int, q: StudyQuestion) -> Color {
        guard let selected else { return Palette.card }
        if choice == q.correctIndex { return Color.green.opacity(0.13) }
        if choice == selected { return Color.red.opacity(0.10) }
        return Palette.card
    }

    private func choiceBorder(_ choice: Int, q: StudyQuestion) -> Color {
        guard let selected else { return Palette.line }
        if choice == q.correctIndex { return .green }
        if choice == selected { return .red }
        return Palette.line
    }

    private func choiceForeground(_ choice: Int, q: StudyQuestion) -> Color {
        guard let selected else { return .primary }
        if choice == q.correctIndex { return .green }
        if choice == selected { return .red }
        return .primary
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
