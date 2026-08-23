import SwiftUI
import UIKit

struct QuizView: View {
    @EnvironmentObject private var learning: LearningStore

    var body: some View {
        VStack(spacing: 0) {
            quizHeader
            ScrollViewReader { proxy in
                ScrollView {
                    if let q = learning.currentQuestion {
                        questionCard(q)
                            .id("top")
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: learning.state.inProgress?.index) { _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .background(Color.sprintPaper.ignoresSafeArea())
    }

    private var quizHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { learning.quitQuiz() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Color.sprintInk)
                }
                .accessibilityLabel("問題を閉じる")

                VStack(alignment: .leading, spacing: 2) {
                    Text(learning.state.inProgress?.title ?? "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.sprintInk)
                        .lineLimit(1)
                    Text(learning.state.inProgress?.field ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.sprintInk3)
                }
                Spacer()
                if let s = learning.state.inProgress {
                    if s.ids.count <= 16 {
                        HStack(spacing: 4) {
                            ForEach(s.ids.indices, id: \.self) { i in
                                Circle()
                                    .fill(pipColor(index: i, session: s))
                                    .frame(width: 7, height: 7)
                            }
                        }
                    } else {
                        Text("\(min(s.index + 1, s.ids.count)) / \(s.ids.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.sprintAi)
                    }
                }
            }

            GeometryReader { geo in
                let progress: Double = {
                    guard let s = learning.state.inProgress, !s.ids.isEmpty else { return 0 }
                    let completed = min(s.index + (learning.feedback == nil ? 0 : 1), s.ids.count)
                    return Double(completed) / Double(s.ids.count)
                }()
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.sprintLine)
                    Rectangle().fill(Color.sprintAi).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .background(Color.sprintCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.sprintLine).frame(height: 1) }
    }

    private func pipColor(index: Int, session: ActiveSession) -> Color {
        if let r = session.answers.first(where: { $0.questionID == session.ids[index] }) {
            return r.correct ? .sprintMidori : .sprintShu
        }
        if index == session.index { return .sprintAi }
        return .sprintLine
    }

    private func questionCard(_ q: Question) -> some View {
        SprintCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("第\(q.exam)回・\(q.section)・\(q.field)・問\(q.questionNo)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.sprintAi)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.sprintAiSoft)
                    .clipShape(Capsule())

                if !q.sharedStem.isEmpty {
                    Text(q.sharedStem)
                        .font(.system(size: CGFloat(learning.state.fontSize - 1)))
                        .foregroundStyle(Color.sprintInk2)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.55))
                        .overlay(alignment: .leading) { Rectangle().fill(Color.sprintAi).frame(width: 3) }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if q.isMediaQuestion {
                    Text(q.question)
                        .font(.system(size: 1))
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .accessibilityHidden(false)
                    Label("図版はタップで全画面表示・ピンチで拡大できます", systemImage: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.sprintAi)
                    VStack(spacing: 10) {
                        ForEach(q.mediaAssets, id: \.self) { path in
                            BundledMediaImage(path: path, accessibilityText: q.question)
                        }
                    }
                } else {
                    Text(q.question)
                        .font(.system(size: CGFloat(learning.state.fontSize + 1), weight: .regular, design: .serif))
                        .lineSpacing(6)
                        .foregroundStyle(Color.sprintInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if q.selectionCount > 1 && learning.feedback == nil {
                    Text("正しいものを\(q.selectionCount)つ選んでください。選択 \(learning.selectedAnswers.count) / \(q.selectionCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.sprintInk3)
                }

                choices(q)

                if learning.feedback == nil {
                    Button("わからない（答えを見る）") { learning.revealUnknown() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.sprintInk2)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.sprintPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sprintLine))
                        .accessibilityIdentifier("unknownButton")
                }

                if let feedback = learning.feedback { feedbackView(feedback) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func choices(_ q: Question) -> some View {
        let order = learning.state.inProgress?.choiceOrders[q.id] ?? Array(q.availableChoices.indices)
        let candidates = Set(q.acceptedAnswers.flatMap { $0 } + q.answer)
        return VStack(spacing: 10) {
            ForEach(Array(order.enumerated()), id: \.element) { displayOffset, originalIndex in
                let displayText = q.availableChoices.indices.contains(originalIndex) ? q.availableChoices[originalIndex] : "選択肢 \(displayOffset + 1)"
                let isSelected = learning.selectedAnswers.contains(originalIndex) || (learning.feedback?.selected.contains(originalIndex) ?? false)
                let graded = learning.feedback != nil
                let isCorrectCandidate = candidates.contains(originalIndex)

                Button {
                    learning.toggleSelection(originalIndex)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(displayOffset + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(graded && isCorrectCandidate ? Color.sprintMidori : Color.sprintAi)
                            .frame(width: 28, height: 28)
                            .background(graded && isCorrectCandidate ? Color.sprintMidoriSoft : Color.sprintAiSoft)
                            .clipShape(Circle())
                        Text(displayText)
                            .font(.system(size: CGFloat(learning.state.fontSize)))
                            .foregroundStyle(Color.sprintInk)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !graded && isSelected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.sprintAi)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(choiceBackground(graded: graded, isCorrect: isCorrectCandidate, isSelected: isSelected))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(choiceBorder(graded: graded, isCorrect: isCorrectCandidate, isSelected: isSelected), lineWidth: 1.2))
                    .overlay(alignment: .trailing) {
                        if graded && isSelected {
                            Text(isCorrectCandidate ? "○" : "×")
                                .font(.system(size: 37, weight: .regular, design: .serif))
                                .foregroundStyle(Color.sprintShu)
                                .rotationEffect(.degrees(isCorrectCandidate ? -7 : 4))
                                .padding(.trailing, 12)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(graded)
                .accessibilityIdentifier("choice_\(originalIndex)")
            }
        }
    }

    private func choiceBackground(graded: Bool, isCorrect: Bool, isSelected: Bool) -> Color {
        if graded && isCorrect { return .sprintMidoriSoft }
        if graded && isSelected { return .sprintShuSoft }
        if isSelected { return .sprintAiSoft }
        return .sprintCard
    }

    private func choiceBorder(graded: Bool, isCorrect: Bool, isSelected: Bool) -> Color {
        if graded && isCorrect { return .sprintMidori }
        if graded && isSelected { return .sprintShu }
        if isSelected { return .sprintAi }
        return .sprintLine
    }

    private func feedbackView(_ f: AnswerFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(f.correct ? "正解" : "惜しい")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(f.correct ? Color.sprintMidori : Color.sprintShu)

            VStack(alignment: .leading, spacing: 7) {
                Text("ここだけ覚える")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.sprintKin)
                Text(f.question.memoryPoint)
                    .font(.system(size: CGFloat(learning.state.fontSize), weight: .semibold, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(Color.sprintInk)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1, green: 0.984, blue: 0.918))
            .overlay(alignment: .leading) { Rectangle().fill(Color.sprintKin).frame(width: 4) }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(f.question.explanation)
                .font(.system(size: CGFloat(learning.state.fontSize - 1)))
                .lineSpacing(4)
                .foregroundStyle(Color.sprintInk2)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("もう少し詳しく") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(f.question.attribution)
                    Text(f.question.modificationDisclosure)
                    if f.question.scoringStatus == "excluded" {
                        Text("公式正答が『解なし』のため採点対象外です。")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.sprintInk3)
                .padding(.top, 8)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.sprintAi)

            Text(f.weakMessage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.sprintInk3)

            Button(learning.state.inProgress.map { $0.index + 1 >= $0.ids.count ? "結果を見る" : "次の問題へ" } ?? "次へ") {
                learning.nextQuestion()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("nextButton")
        }
        .padding(.top, 6)
    }
}

struct BundledMediaImage: View {
    let path: String
    let accessibilityText: String
    @State private var image: UIImage?
    @State private var zoomPresented = false

    var body: some View {
        Group {
            if let image {
                Button {
                    zoomPresented = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                        Label("拡大", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                            .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sprintLine))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("問題画像を拡大表示")
                .accessibilityHint(accessibilityText)
                .fullScreenCover(isPresented: $zoomPresented) {
                    MediaZoomView(image: image, accessibilityText: accessibilityText)
                }
            } else {
                HStack {
                    ProgressView()
                    Text("図版を読み込み中")
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .task { image = loadImage() }
    }

    private func loadImage() -> UIImage? {
        let components = path.split(separator: "/").map(String.init)
        guard let file = components.last else { return nil }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        let subdir = components.dropLast().joined(separator: "/")
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir.isEmpty ? nil : subdir) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct MediaZoomView: View {
    let image: UIImage
    let accessibilityText: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .contentShape(Rectangle())
                    .gesture(zoomGesture.simultaneously(with: panGesture))
                    .onTapGesture(count: 2) { toggleDoubleTapZoom() }
                    .accessibilityLabel(accessibilityText)
            }

            VStack {
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Color.white)
                            .background(Color.black.opacity(0.62))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("拡大表示を閉じる")

                    Spacer()

                    Text("ピンチで拡大・ドラッグで移動")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.62))
                        .clipShape(Capsule())

                    Button("リセット") { resetZoom() }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(Color.black.opacity(0.62))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(6, max(1, settledScale * value))
                if scale <= 1 {
                    offset = .zero
                }
            }
            .onEnded { _ in
                settledScale = scale
                if scale <= 1 {
                    resetZoom()
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else {
                    resetZoom()
                    return
                }
                settledOffset = offset
            }
    }

    private func toggleDoubleTapZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = 2.5
                settledScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = 1
        settledScale = 1
        offset = .zero
        settledOffset = .zero
    }
}

struct ResultView: View {
    @EnvironmentObject private var learning: LearningStore

    private var answers: [SessionAnswer] { learning.state.inProgress?.answers ?? [] }
    private var score: Int { answers.filter(\.correct).count }
    private var total: Int { learning.state.inProgress?.ids.count ?? max(1, answers.count) }
    private var wrongCount: Int { answers.filter { !$0.correct }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenTitle(brand: "学びスプリント", title: "結果", tagline: "短い反復を、次の一歩へ。")
                SprintCard {
                    VStack(spacing: 18) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(score)")
                                .font(.system(size: 62, weight: .bold, design: .serif))
                                .foregroundStyle(Color.sprintInk)
                            Text("/ \(total)")
                                .font(.system(size: 24, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.sprintInk3)
                        }
                        Text(resultMessage)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.sprintInk)
                        Text("正答率 \(total > 0 ? Int((Double(score) / Double(total) * 100).rounded()) : 0)%・苦手 \(learning.weakCount)問")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.sprintInk3)

                        if wrongCount > 0 {
                            Button("間違えた問題をすぐ復習（\(wrongCount)問）") { learning.reviewWrongCurrent() }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.sprintShu)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Color.sprintShuSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                        Button("もう一度\(total)問") { learning.repeatCurrentSession() }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("ホームへ戻る") {
                            learning.clearCompletedSession()
                            learning.selectedTab = .home
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.sprintAi)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.sprintAi))
                    }
                }
            }
            .sprintScreenMargins()
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(PaperBackground())
    }

    private var resultMessage: String {
        guard total > 0 else { return "今日の学習を記録しました。" }
        let rate = Double(score) / Double(total)
        if rate >= 0.85 { return "よく整理できています。次は苦手だけ軽く確認しましょう。" }
        if rate >= 0.6 { return "積み上がっています。間違えた論点を戻せば十分です。" }
        return "今日は苦手が見えました。要点だけ戻して終えましょう。"
    }
}
