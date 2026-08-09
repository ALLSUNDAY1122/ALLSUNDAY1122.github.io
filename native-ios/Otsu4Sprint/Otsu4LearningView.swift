import SwiftUI

struct Otsu4NativeRootView: View {
    @StateObject private var purchaseStore = Otsu4PurchaseStore()
    @State private var contentStore: Otsu4ContentStore?
    @State private var loadError: String?
    @State private var activeSession: Otsu4StudySession?
    @State private var showingPaywall = false

    var body: some View {
        Group {
            if let contentStore {
                Otsu4HomeView(
                    contentStore: contentStore,
                    purchaseStore: purchaseStore,
                    startToday: { start(.today12, from: contentStore) },
                    startSubject: { start(.subject($0), from: contentStore) },
                    startMock: {
                        if purchaseStore.isPremium {
                            start(.mock35, from: contentStore)
                        } else {
                            showingPaywall = true
                        }
                    },
                    showPaywall: { showingPaywall = true }
                )
            } else if let loadError {
                ContentUnavailableView(
                    "問題データを読み込めません",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("360問を読み込み中")
            }
        }
        .task {
            guard contentStore == nil, loadError == nil else { return }
            do {
                contentStore = try Otsu4ContentStore()
            } catch {
                loadError = "questions.generated.json をアプリのCopy Bundle Resourcesへ追加してください。"
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            Otsu4StudyFlowView(session: session) {
                activeSession = nil
            }
        }
        .sheet(isPresented: $showingPaywall) {
            Otsu4PaywallView(purchaseStore: purchaseStore) {
                showingPaywall = false
            }
        }
    }

    private func start(_ kind: Otsu4StudyKind, from store: Otsu4ContentStore) {
        let questions: [Otsu4Question]
        switch kind {
        case .today12:
            questions = store.today12(isPremium: purchaseStore.isPremium)
        case .subject(let subject):
            questions = store.questions(subject: subject, isPremium: purchaseStore.isPremium).shuffled()
        case .mock35:
            questions = store.mockExamQuestions() ?? []
        }
        guard !questions.isEmpty else { return }
        activeSession = Otsu4StudySession(kind: kind, questions: questions)
    }
}

struct Otsu4HomeView: View {
    let contentStore: Otsu4ContentStore
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    let startToday: () -> Void
    let startSubject: (String) -> Void
    let startMock: () -> Void
    let showPaywall: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("学びスプリント")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("危険物 乙4")
                            .font(.largeTitle.bold())
                        Text("今日も12問、合格に近づく。")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: startToday) {
                        HStack(spacing: 14) {
                            Text("12")
                                .font(.title2.bold())
                                .frame(width: 48, height: 48)
                                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("今日の12問").font(.headline)
                                Text("法令5・物化3・性消4を短く一周")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("科目別").font(.headline)
                        ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                            Button {
                                startSubject(subject)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(subject).font(.headline)
                                        Text("\(contentStore.questions(subject: subject, isPremium: purchaseStore.isPremium).count)問")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding(15)
                                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("本番・プレミアム").font(.headline)
                        Button(action: startMock) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("本番35問").font(.headline)
                                    Text("120分・法令15／物化10／性消10")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if purchaseStore.isPremium {
                                    Image(systemName: "chevron.right")
                                } else {
                                    Text("PREMIUM")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(.orange.opacity(0.15), in: Capsule())
                                }
                            }
                            .padding(15)
                            .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        if !purchaseStore.isPremium {
                            Button("360問すべてを解放") {
                                showPaywall()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("無料版72問／プレミアム360問。問題データ監査日 \(contentStore.bank.lawAuditDate)。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

struct Otsu4StudyFlowView: View {
    @ObservedObject var session: Otsu4StudySession
    let close: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if session.isFinished {
                    resultView
                } else {
                    questionView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ホーム", action: close)
                }
                ToolbarItem(placement: .principal) {
                    Text(session.kind.title).font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(session.progressText)
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private var questionView: some View {
        let q = session.currentQuestion
        let answer = session.currentAnswer
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressView(value: Double(session.index + 1), total: Double(session.questions.count))
                    .tint(.orange)

                Text("\(q.subject) ・ \(q.topic)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(q.question)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            session.choose(index)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.bold())
                                    .frame(width: 28, height: 28)
                                    .background(choiceBackground(index, question: q, answer: answer), in: Circle())
                                Text(choice)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(.primary)
                            }
                            .padding(14)
                            .background(choiceCardBackground(index, question: q, answer: answer), in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        .disabled(!session.kind.isMock && answer != nil)
                    }
                }

                if !session.kind.isMock, answer == nil {
                    Button("わからない") {
                        session.choose(nil)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }

                if !session.kind.isMock, let answer {
                    feedback(question: q, answer: answer)
                    Button(session.isLast ? "結果を見る" : "次の問題へ") {
                        session.next()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }

                if session.kind.isMock {
                    HStack(spacing: 12) {
                        Button("前の問題") { session.previous() }
                            .buttonStyle(.bordered)
                            .disabled(!session.canGoBack)
                        Button(session.isLast ? "採点する" : "次の問題") { session.next() }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                    }
                    Text("本番35問では解答中に正誤を表示しません。未回答は不正解として採点します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func feedback(question: Otsu4Question, answer: Otsu4AnswerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(answer.correct ? "正解です" : "不正解です")
                .font(.headline)
                .foregroundStyle(answer.correct ? .green : .red)
            Text("この問題で覚える一文")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(question.point)
                .font(.headline)
            DisclosureGroup("詳しい解説を見る") {
                Text(question.detail)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(answer.correct ? Color.green.opacity(0.08) : Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(session.kind.isMock ? "MOCK EXAM" : "SPRINT COMPLETE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("\(session.correctCount) / \(session.questions.count)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("正答率 \(session.scoreRate)%")
                    .font(.title3.bold())

                if session.kind.isMock {
                    VStack(spacing: 10) {
                        ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                            if let r = session.subjectResults[subject] {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(subject).font(.headline)
                                        Text("\(r.correct) / \(r.total)・\(r.rate)%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(r.rate >= 60 ? "基準到達" : "60%未満")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(r.rate >= 60 ? .green : .red)
                                }
                                .padding(14)
                                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    Text(session.mockPassEstimate ? "3科目とも60%以上です。" : "本番基準を意識して60%未満の科目を復習してください。")
                        .font(.subheadline)
                }

                Button("ホームへ") { close() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func choiceCardBackground(_ index: Int, question: Otsu4Question, answer: Otsu4AnswerState?) -> Color {
        guard let answer else { return Color(uiColor: .secondarySystemGroupedBackground) }
        if session.kind.isMock {
            return answer.selectedIndex == index ? Color.orange.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground)
        }
        if index == question.answer { return Color.green.opacity(0.10) }
        if answer.selectedIndex == index { return Color.red.opacity(0.10) }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func choiceBackground(_ index: Int, question: Otsu4Question, answer: Otsu4AnswerState?) -> Color {
        guard let answer else { return .secondary.opacity(0.12) }
        if session.kind.isMock {
            return answer.selectedIndex == index ? .orange.opacity(0.25) : .secondary.opacity(0.12)
        }
        if index == question.answer { return .green.opacity(0.22) }
        if answer.selectedIndex == index { return .red.opacity(0.22) }
        return .secondary.opacity(0.12)
    }
}
