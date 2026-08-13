import SwiftUI

struct QuizScreen: View {
    @EnvironmentObject private var store: LearningStore
    @State private var markVisible = false

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()
            if let session = store.session, let question = store.currentQuestion() {
                let response = store.response(for: question)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        quizHeader(session)
                        HStack(spacing: 8) {
                            Text(question.subject).lineLimit(1)
                            Text("・"); Text(question.domain)
                        }.appSans(11, weight: .bold).foregroundStyle(AppTheme.ai).padding(.horizontal, 10).padding(.vertical, 6).background(AppTheme.aiSoft).clipShape(Capsule())
                        Text(question.question).appSerif(20, weight: .semibold).foregroundStyle(AppTheme.ink).frame(maxWidth: .infinity, alignment: .leading).padding(18).appCard().accessibilityIdentifier("quiz.questionText")
                        VStack(spacing: 10) {
                            ForEach(question.choices.indices, id: \.self) { index in choiceButton(question, index: index, response: response, mode: session.mode) }
                            Button { submit(nil) } label: {
                                HStack { Image(systemName: "questionmark.circle"); Text("わからない").appSans(15, weight: .bold); Spacer() }
                                    .foregroundStyle(AppTheme.ink2).padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 52).background(AppTheme.card)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, style: StrokeStyle(lineWidth: 1.4, dash: [5,4])))
                            }.buttonStyle(.plain).disabled(response != nil).accessibilityIdentifier("quiz.unknown")
                        }
                        if let response, session.mode == .practice { practiceFeedback(question, response: response).transition(.opacity.combined(with: .move(edge: .bottom))) }
                        if response != nil {
                            Button { markVisible = false; store.advanceSession() } label: {
                                HStack { Text(session.index + 1 == session.total ? "結果を見る" : "次の問題").appSans(16, weight: .bold); Spacer(); Image(systemName: "arrow.right") }
                                    .foregroundStyle(.white).padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 54).background(AppTheme.ai).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }.buttonStyle(.plain).accessibilityIdentifier("quiz.next")
                        }
                        Spacer(minLength: 20)
                    }.padding(.horizontal, 18).padding(.top, 10).frame(maxWidth: 520).frame(maxWidth: .infinity)
                }
                .overlay {
                    if markVisible, let response, session.mode == .practice {
                        Text(response.correct ? "○" : "×").font(.system(size: 112, weight: .regular, design: .rounded)).foregroundStyle(AppTheme.shu.opacity(0.82)).rotationEffect(.degrees(response.correct ? -7 : 6)).scaleEffect(markVisible ? 1 : 0.55).animation(.spring(response: 0.33, dampingFraction: 0.7), value: markVisible).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            } else { ProgressView().tint(AppTheme.ai) }
        }
    }

    private func quizHeader(_ session: SessionState) -> some View {
        HStack(spacing: 12) {
            Button { store.exitSessionToHome() } label: { Image(systemName: "house").font(.system(size: 18, weight: .bold)).foregroundStyle(AppTheme.ai).frame(width: 44, height: 44).background(AppTheme.aiSoft).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) }.accessibilityIdentifier("quiz.home")
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).appSans(13, weight: .bold).foregroundStyle(AppTheme.ink)
                Text("\(session.index + 1) / \(session.total)")
                    .appSans(11, weight: .bold)
                    .foregroundStyle(AppTheme.ink3)
                    .accessibilityIdentifier("quiz.progress")
            }
            Spacer(); Text(session.mode == .mock ? "模試" : "学習").appSans(10, weight: .bold).foregroundStyle(session.mode == .mock ? AppTheme.shu : AppTheme.midori).padding(.horizontal, 10).padding(.vertical, 6).background(session.mode == .mock ? AppTheme.shuSoft : AppTheme.midoriSoft).clipShape(Capsule())
        }
    }

    private func choiceButton(_ q: AppQuestion, index: Int, response: SessionResponse?, mode: SessionMode) -> some View {
        let selected = response?.selectedIndex == index && !(response?.isUnknown ?? false)
        let reveal = response != nil && mode == .practice
        let correctChoice = index == q.correctIndex
        let border = reveal && correctChoice ? AppTheme.midori : (selected ? AppTheme.ai : AppTheme.line)
        let background = reveal && correctChoice ? AppTheme.midoriSoft : (selected ? AppTheme.aiSoft : AppTheme.card)
        return Button { submit(index) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").appSans(12, weight: .bold).foregroundStyle(selected ? .white : AppTheme.ai).frame(width: 28, height: 28).background(selected ? AppTheme.ai : AppTheme.aiSoft).clipShape(Circle())
                Text(q.choices[index]).appSans(15, weight: .semibold).foregroundStyle(AppTheme.ink).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }.padding(14).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading).background(background).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: 1.4)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain).disabled(response != nil).accessibilityIdentifier("quiz.choice.\(index)")
    }

    private func submit(_ index: Int?) { withAnimation(.easeOut(duration: 0.2)) { store.submitAnswer(index); markVisible = true } }

    private func practiceFeedback(_ q: AppQuestion, response: SessionResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) { Image(systemName: response.correct ? "checkmark.circle.fill" : "xmark.circle.fill"); Text(response.correct ? "正解" : (response.isUnknown ? "わからないとして記録" : "不正解")).appSans(14, weight: .bold) }.foregroundStyle(response.correct ? AppTheme.midori : AppTheme.shu)
            VStack(alignment: .leading, spacing: 6) {
                Text("ここだけ覚える").appSans(11, weight: .bold).foregroundStyle(AppTheme.kin)
                Text(q.memoryLine).appSerif(17, weight: .semibold).foregroundStyle(AppTheme.ink)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color(hex: 0xFFF7DC)).overlay(alignment: .leading) { Rectangle().fill(AppTheme.kin).frame(width: 4) }.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(q.shortExplanation).appSans(14, weight: .semibold).foregroundStyle(AppTheme.ink)
            Text(q.detailExplanation).appSans(13).foregroundStyle(AppTheme.ink2)
            VStack(alignment: .leading, spacing: 5) {
                Text("根拠・基準日").appSans(10, weight: .bold).foregroundStyle(AppTheme.ink3)
                Text("基準日 \(q.referenceDate)／\(q.originType)").appSans(10).foregroundStyle(AppTheme.ink3)
                Text(q.rightsBasis).appSans(10).foregroundStyle(AppTheme.ink3)
                if let url = URL(string: q.sourceURL) { Link("国土交通省 一次資料", destination: url).appSans(11, weight: .bold).foregroundStyle(AppTheme.ai) }
            }
        }.padding(16).appCard()
    }
}

struct ResultScreen: View {
    @EnvironmentObject private var store: LearningStore
    let result: SessionResult
    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea(); PaperGridBackground()
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 7) { Text(result.title).appSans(12, weight: .bold).foregroundStyle(AppTheme.ai); Text("\(result.correct) / \(result.total)").appSerif(44, weight: .bold).foregroundStyle(AppTheme.ink); Text("正答率 \(result.accuracy)%").appSerif(20, weight: .bold).foregroundStyle(AppTheme.ai) }.padding(.top, 28).accessibilityIdentifier("result.score")
                    VStack(spacing: 12) { ForEach(store.resultDomainStats(result), id: \.domain) { s in HStack { Text(s.domain).appSans(13, weight: .bold).foregroundStyle(AppTheme.ink); Spacer(); Text("\(s.correct) / \(s.total)").appSans(12, weight: .bold).foregroundStyle(AppTheme.ai) } } }.padding(16).appCard()
                    let missed = store.missedQuestionIDs(in: result)
                    if !missed.isEmpty {
                        Button { store.retryQuestions(missed, title: "今回の誤答を復習") } label: { HStack { Image(systemName: "repeat"); Text("誤答・わからない \(missed.count)問を復習").appSans(15, weight: .bold); Spacer(); Image(systemName: "arrow.right") }.foregroundStyle(AppTheme.shu).padding(16).frame(maxWidth: .infinity, minHeight: 54).background(AppTheme.shuSoft).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)) }.buttonStyle(.plain)
                    }
                    if result.mode == .mock {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("見直し").appSerif(18, weight: .bold)
                            ForEach(result.questionIDs, id: \.self) { id in
                                if let q = store.repository.question(id: id), let response = result.responses[id], !response.correct {
                                    VStack(alignment: .leading, spacing: 5) { Text("\(q.subject)・\(q.topic)").appSans(12, weight: .bold).foregroundStyle(AppTheme.shu); Text("正答：\(q.choices[q.correctIndex])").appSans(12, weight: .semibold).foregroundStyle(AppTheme.ink); Text(q.memoryLine).appSerif(14).foregroundStyle(AppTheme.ink2) }.padding(.vertical, 8); Divider()
                                }
                            }
                        }.padding(16).appCard()
                    }
                    Button { store.result = nil; store.currentTab = .home } label: { Text("ホームへ").appSans(16, weight: .bold).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54).background(AppTheme.ai).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)) }.buttonStyle(.plain).accessibilityIdentifier("result.home")
                    Spacer(minLength: 20)
                }.padding(.horizontal, 18).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
        }
    }
}