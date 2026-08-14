import SwiftUI
import UIKit
import LearningSprintCore

struct QuizFlowView: View {
    @EnvironmentObject var model: KangoshiAppModel
    var body: some View {
        Group {
            if let s = model.session, s.finished { ResultView(session: s) }
            else if let q = model.currentQuestion { QuizQuestionView(question: q) }
            else { ProgressView().tint(KSTheme.ai) }
        }
        .background(KSTheme.paper.ignoresSafeArea())
    }
}

struct QuizQuestionView: View {
    @EnvironmentObject var model: KangoshiAppModel
    let question: NativeQuestion
    @State private var selected: Set<Int> = []
    @State private var numericText = ""
    @State private var showDetail = false

    private var session: StudySession { model.session! }
    private var result: AnswerResult? { session.answered ? session.results.last : nil }
    private var choices: [String] { question.choices.isEmpty && !question.isNumeric ? ["①","②","③","④"] : question.choices }
    private var questionFont: Font {
        switch model.learning.fontScale {
        case "large": return .system(size: 20, weight: .semibold, design: .serif)
        case "xlarge": return .system(size: 23, weight: .semibold, design: .serif)
        default: return .system(size: 18, weight: .semibold, design: .serif)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) { tag(question.category); tag(question.subject) }
                    if !question.scenario.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("状況設定 \(question.scenarioIndex + 1)/\(max(1, question.scenarioTotal))").font(.caption.bold()).foregroundStyle(KSTheme.green)
                            Text(question.scenario).font(.subheadline).foregroundStyle(Color(hex: "2D5746"))
                        }
                        .padding(13).background(KSTheme.greenSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(question.question).font(questionFont).lineSpacing(6).foregroundStyle(KSTheme.ink)
                    if !question.mediaAssets.isEmpty { NativeMediaView(question: question) }
                    answerArea
                    if let result { feedback(result) }
                }
                .padding(16)
            }
        }
        .onChange(of: question.id) { _ in selected = []; numericText = ""; showDetail = false }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: { model.closeSession() }) {
                    Image(systemName: "xmark").font(.headline).frame(width: 42, height: 42)
                        .background(KSTheme.card).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line))
                }
                .foregroundStyle(KSTheme.ink)
                .accessibilityLabel("閉じる")
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title).font(.subheadline.bold())
                    Text(question.majorSubject).font(.caption2).foregroundStyle(KSTheme.tertiary)
                }
                Spacer()
                Text("\(session.index + 1)/\(session.questionIds.count)").font(.caption.bold()).foregroundStyle(KSTheme.ai)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(KSTheme.line)
                    Capsule().fill(KSTheme.ai).frame(width: g.size.width * CGFloat(session.index + (session.answered ? 1 : 0)) / CGFloat(max(1, session.questionIds.count)))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        .background(KSTheme.paper.opacity(0.97))
    }

    @ViewBuilder private var answerArea: some View {
        if question.isNumeric {
            if !session.answered {
                HStack {
                    TextField("数値を入力", text: $numericText).keyboardType(.decimalPad).padding(14).background(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line)).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(question.unit).font(.subheadline.bold()).foregroundStyle(KSTheme.secondary)
                }
                Button("採点する") { model.submitNumeric(Double(numericText)) }.buttonStyle(PrimaryButtonStyle()).disabled(Double(numericText) == nil)
                unknownButton
            }
        } else {
            if question.isMultiChoice && !session.answered {
                Text("\(selected.count) / \(question.requiredSelectionCount) 選択中").font(.caption.bold()).foregroundStyle(KSTheme.ai)
            }
            ForEach(Array(choices.enumerated()), id: \.offset) { i, text in
                Button {
                    guard !session.answered else { return }
                    if question.isMultiChoice {
                        if selected.contains(i) { selected.remove(i) }
                        else if selected.count < question.requiredSelectionCount { selected.insert(i) }
                    } else {
                        selected = [i]; model.submitChoices([i])
                    }
                } label: { choiceRow(index: i, text: text) }
                .buttonStyle(.plain)
            }
            if question.isMultiChoice && !session.answered {
                Button("採点する") { model.submitChoices(Array(selected)) }.buttonStyle(PrimaryButtonStyle()).disabled(selected.count != question.requiredSelectionCount)
            }
            if !session.answered { unknownButton }
        }
    }

    private var unknownButton: some View {
        Button("わからない（答えを見る）") {
            if question.isNumeric { model.submitNumeric(nil, unknown: true) }
            else { model.submitChoices([], unknown: true) }
        }
        .font(.subheadline.bold()).foregroundStyle(KSTheme.tertiary).frame(maxWidth: .infinity).padding(.vertical, 13)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.tertiary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
    }

    private func choiceRow(index: Int, text: String) -> some View {
        let answerIndices = Set(question.acceptedChoiceSets.flatMap { $0 })
        let chosen = result?.responseChoices.contains(index) ?? selected.contains(index)
        let correctAnswer = answerIndices.contains(index) && question.scoringMode != "excluded"
        let bg: Color = session.answered ? (correctAnswer ? KSTheme.greenSoft : (chosen ? KSTheme.shuSoft : .white)) : (chosen ? KSTheme.aiSoft : .white)
        let border: Color = session.answered ? (correctAnswer ? KSTheme.green : (chosen ? KSTheme.shu : KSTheme.line)) : (chosen ? KSTheme.ai : KSTheme.line)
        return HStack(spacing: 12) {
            Text("\(index + 1)").font(.subheadline.bold()).frame(width: 30, height: 30).background(KSTheme.paper).clipShape(RoundedRectangle(cornerRadius: 8))
            Text(text).font(.subheadline).foregroundStyle(KSTheme.ink).frame(maxWidth: .infinity, alignment: .leading)
            if session.answered && correctAnswer { Image(systemName: "circle").font(.title2).foregroundStyle(KSTheme.green) }
            else if session.answered && chosen { Image(systemName: "xmark").font(.title3.bold()).foregroundStyle(KSTheme.shu) }
        }
        .padding(12).background(bg).overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1.5)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func feedback(_ r: AnswerResult) -> some View {
        VStack(spacing: 0) {
            Text(question.scoringMode == "excluded" ? "採点対象外" : (r.correct ? "正解" : "惜しい"))
                .font(.subheadline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(question.scoringMode == "excluded" ? KSTheme.ai : (r.correct ? KSTheme.green : KSTheme.shu))
            VStack(alignment: .leading, spacing: 10) {
                Text("ここだけ覚える").font(.caption2.bold()).tracking(1.5).foregroundStyle(KSTheme.gold)
                Text(question.point).font(.system(size: 16, weight: .semibold, design: .serif)).lineSpacing(5).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "FFFBEA")).overlay(Rectangle().fill(KSTheme.gold).frame(width: 4), alignment: .leading)
                if question.scoringMode == "include_if_correct_exclude_if_wrong" { Text("公式採点：正解時のみ得点に算入し、不正解時は採点対象から除外します。").font(.caption).foregroundStyle(KSTheme.secondary) }
                if question.scoringMode == "excluded" { Text("公式に採点対象外とされた問題です。独自の正解を追加せず、学習解説のみ表示します。").font(.caption).foregroundStyle(KSTheme.secondary) }
                DisclosureGroup("もう少し詳しく", isExpanded: $showDetail) { Text(question.detail).font(.caption).lineSpacing(4).foregroundStyle(KSTheme.secondary).padding(.top, 6) }.tint(KSTheme.ai)
                Button(session.index + 1 == session.questionIds.count ? "結果を見る" : "次の問題へ") { model.advance() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(14).background(.white)
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.caption2.bold()).foregroundStyle(KSTheme.ai).padding(.horizontal, 9).padding(.vertical, 5).background(KSTheme.aiSoft).clipShape(Capsule())
    }
}

struct NativeMediaView: View {
    let question: NativeQuestion
    var body: some View {
        VStack(spacing: 8) {
            ForEach(question.mediaAssets, id: \.self) { asset in
                if let image = load(asset) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 430).frame(maxWidth: .infinity).background(.white) }
            }
            if !question.mediaAttribution.isEmpty { Text(question.mediaAttribution).font(.caption2).foregroundStyle(KSTheme.tertiary).frame(maxWidth: .infinity, alignment: .leading) }
        }
        .padding(8).background(.white).overlay(RoundedRectangle(cornerRadius: 14).stroke(KSTheme.line)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func load(_ asset: String) -> UIImage? {
        let ns = asset as NSString, name = (ns.deletingPathExtension as NSString).lastPathComponent, ext = ns.pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Media") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct ResultView: View {
    @EnvironmentObject var model: KangoshiAppModel
    let session: StudySession
    private var rate: Int { session.scoredTotal > 0 ? Int((Double(session.correct) / Double(session.scoredTotal) * 100).rounded()) : 0 }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PageHeader(eyebrow: "学びスプリント", title: "今回の結果", tagline: "短い反復を、そのまま次につなげます。")
                KSCard(content: VStack(spacing: 14) {
                    Text("\(session.correct) / \(session.scoredTotal)").font(.system(size: 48, weight: .bold, design: .serif)).foregroundStyle(KSTheme.ink)
                    Text(message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(KSTheme.secondary)
                    HStack { metric("\(rate)%", "正答率"); metric("\(session.attempted)", "回答数"); metric("\(model.weakQuestions.count)", "苦手") }
                }).padding(.horizontal, 18)
                VStack(spacing: 10) {
                    if !model.weakQuestions.isEmpty { Button("間違えた問題をすぐ復習") { model.closeSession(); model.startWeak() }.buttonStyle(PrimaryButtonStyle()) }
                    Button("ホームへ戻る") { model.closeSession() }.buttonStyle(.bordered).tint(KSTheme.ai)
                }.padding(.horizontal, 18)
            }.padding(.bottom, 30)
        }.background(KSTheme.paper.ignoresSafeArea())
    }
    private var message: String {
        if rate >= 90 { return "かなり定着しています。この調子で短く積み上げましょう。" }
        if rate >= 70 { return "よく取れています。間違えたところだけ整えれば十分です。" }
        if rate >= 50 { return "土台はできています。苦手だけもう一度確認しましょう。" }
        return "今は覚える場所が見えた段階です。要点だけ拾って次へ進みましょう。"
    }
    private func metric(_ v: String, _ l: String) -> some View { VStack { Text(v).font(.title3.bold()).foregroundStyle(KSTheme.ai); Text(l).font(.caption2).foregroundStyle(KSTheme.tertiary) }.frame(maxWidth: .infinity) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(KSTheme.ai.opacity(configuration.isPressed ? 0.78 : 1.0)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
