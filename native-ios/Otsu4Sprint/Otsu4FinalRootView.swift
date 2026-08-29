import SwiftUI

private enum Otsu4FinalTab: Hashable { case home, mock, history, settings }
private enum Otsu4PracticeMode: String, CaseIterable, Identifiable {
    case subject = "分野別"
    case round = "試験回別"
    var id: String { rawValue }
}

struct Otsu4FinalRootView: View {
    @StateObject private var purchaseStore = Otsu4PurchaseStore()
    @StateObject private var learningStore = Otsu4LearningStore()
    @State private var contentStore: Otsu4ContentStore?
    @State private var activeSession: Otsu4StudySession?
    @State private var showingPaywall = false
    @State private var selectedTab: Otsu4FinalTab = .home
    @State private var loadError: String?

    var body: some View {
        Group {
            if let store = contentStore {
                TabView(selection: $selectedTab) {
                    Otsu4FinalHomeView(
                        contentStore: store,
                        purchaseStore: purchaseStore,
                        learningStore: learningStore,
                        startSprint: { begin(.sprint(learningStore.goal), store.sprint(goal: learningStore.goal, isPremium: purchaseStore.isPremium)) },
                        startWeak: { begin(.weak, Array(learningStore.weakQuestions(from: store, isPremium: purchaseStore.isPremium).shuffled().prefix(learningStore.goal))) },
                        resume: { activeSession = learningStore.restoreSession(from: store) },
                        goMock: { selectedTab = .mock },
                        startSubject: { subject in
                            begin(.subject(subject), store.questions(subject: subject, isPremium: purchaseStore.isPremium))
                        },
                        startRound: { set in
                            guard let rows = store.practiceRoundQuestions(set: set, isPremium: purchaseStore.isPremium) else { showingPaywall = true; return }
                            begin(.subject("第\(set)回・試験回別演習"), rows)
                        },
                        showPaywall: { showingPaywall = true }
                    )
                    .tag(Otsu4FinalTab.home)
                    .tabItem { Label("ホーム", systemImage: "house") }

                    Otsu4FinalMockListView(purchaseStore: purchaseStore, startMock: { set in
                        guard purchaseStore.isPremium else { showingPaywall = true; return }
                        begin(.mock(set), store.mockExamQuestions(set: set) ?? [])
                    }, showPaywall: { showingPaywall = true })
                    .tag(Otsu4FinalTab.mock)
                    .tabItem { Label("模試", systemImage: "doc.text") }

                    Otsu4FinalHistoryView(contentStore: store, purchaseStore: purchaseStore, learningStore: learningStore)
                        .tag(Otsu4FinalTab.history)
                        .tabItem { Label("記録", systemImage: "chart.bar") }

                    Otsu4SettingsView(purchaseStore: purchaseStore, learningStore: learningStore, showPaywall: { showingPaywall = true })
                        .tag(Otsu4FinalTab.settings)
                        .tabItem { Label("設定", systemImage: "gearshape") }
                }
                .tint(Otsu4Theme.ai)
                .dynamicTypeSize(dynamicTypeSize)
            } else if let loadError {
                ContentUnavailableView("問題データを読み込めません", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ZStack { Otsu4PaperBackground(); ProgressView("720問を読み込み中") }
            }
        }
        .task {
            guard contentStore == nil, loadError == nil else { return }
            do { contentStore = try Otsu4ContentStore() }
            catch { loadError = "questions.generated.json を読み込めませんでした。" }
        }
        .fullScreenCover(item: $activeSession) { session in
            Otsu4StudyFlowView(session: session, learningStore: learningStore) {
                if !session.isFinished { learningStore.saveResume(session: session) }
                activeSession = nil
            }
            .dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(isPresented: $showingPaywall) { Otsu4PaywallView(purchaseStore: purchaseStore) { showingPaywall = false } }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        if ProcessInfo.processInfo.arguments.contains("OTS4_UI_TEST_ACCESSIBILITY3") { return .accessibility3 }
        return learningStore.fontScale == 0 ? .medium : (learningStore.fontScale == 2 ? .xxLarge : .large)
    }

    private func begin(_ kind: Otsu4StudyKind, _ questions: [Otsu4Question]) {
        guard !questions.isEmpty else { return }
        learningStore.clearResume()
        activeSession = Otsu4StudySession(
            kind: kind,
            questions: questions,
            onAnswer: { questionID, correct in
                learningStore.recordQuestionAnswer(questionID: questionID, correct: correct)
            }
        )
    }
}

private struct Otsu4FinalHomeView: View {
    let contentStore: Otsu4ContentStore
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore
    let startSprint: () -> Void
    let startWeak: () -> Void
    let resume: () -> Void
    let goMock: () -> Void
    let startSubject: (String) -> Void
    let startRound: (Int) -> Void
    let showPaywall: () -> Void
    @State private var mode: Otsu4PracticeMode = .subject

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("学びスプリント").font(Otsu4Theme.sans(12, weight: .bold)).foregroundStyle(Otsu4Theme.shu)
                            Text("危険物 乙4").font(Otsu4Theme.serif(34, weight: .bold)).foregroundStyle(Otsu4Theme.ink)
                            Text("今日も1問、力に変える。").font(Otsu4Theme.sans(15)).foregroundStyle(Otsu4Theme.ink2)
                        }
                        if let days = learningStore.examDaysRemaining { countdown(days) }
                        Otsu4Card {
                            HStack(spacing: 16) {
                                Otsu4ProgressRing(value: learningStore.todayProgress, label: "\(learningStore.todayAnswered)/\(learningStore.goal)")
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("今日のスプリント").font(Otsu4Theme.serif(20, weight: .bold))
                                    Text("\(learningStore.goal)問を短く周回").font(Otsu4Theme.sans(13)).foregroundStyle(Otsu4Theme.ink2)
                                    Button("始める", action: startSprint).buttonStyle(.borderedProminent).tint(Otsu4Theme.shu)
                                }
                            }
                        }
                        if learningStore.resumeSnapshot != nil { Button("続きから再開", action: resume).buttonStyle(.bordered).tint(Otsu4Theme.ai) }
                        Button(action: startWeak) {
                            HStack { Label("苦手を復習", systemImage: "repeat"); Spacer(); Text("\(learningStore.weakCount)問") }.frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.bordered).disabled(learningStore.weakCount == 0)
                        Button(action: goMock) {
                            HStack { Label("模擬試験へ", systemImage: "timer"); Spacer(); Text("35問・120分") }.frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.bordered).tint(Otsu4Theme.ai)
                        practiceSection
                        HStack(spacing: 10) {
                            metric("学習済み", "\(learningStore.seenCount)問", Otsu4Theme.ai)
                            metric("苦手", "\(learningStore.weakCount)問", Otsu4Theme.shu)
                            metric("全問題", purchaseStore.isPremium ? "720問" : "72問", Otsu4Theme.midori)
                        }
                        Text("問題データ: \(contentStore.bank.contentVersion) ／ 720問監査済み").font(Otsu4Theme.sans(10)).foregroundStyle(Otsu4Theme.ink3).frame(maxWidth: .infinity)
                    }
                    .padding(18).padding(.bottom, 18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func countdown(_ days: Int) -> some View {
        let total = contentStore.availableQuestions(isPremium: purchaseStore.isPremium).count
        return HStack {
            VStack(alignment: .leading) { Text("試験まで").font(Otsu4Theme.sans(12, weight: .bold)); Text("\(days)日").font(Otsu4Theme.serif(30, weight: .bold)).foregroundStyle(Otsu4Theme.shu) }
            Spacer()
            if days > 0, let pace = learningStore.requiredDailyPace(totalQuestions: total) { Text("必要ペース \(pace)問 / 日").font(Otsu4Theme.sans(13, weight: .bold)).foregroundStyle(Otsu4Theme.ai) }
        }.padding(14).background(Otsu4Theme.shuSoft).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("問題を選ぶ").font(Otsu4Theme.serif(20, weight: .bold))
            Picker("演習方法", selection: $mode) { ForEach(Otsu4PracticeMode.allCases) { item in Text(item.rawValue).tag(item) } }
                .pickerStyle(.segmented).accessibilityIdentifier("practice-mode-picker")
            if mode == .subject {
                ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                    NavigationLink {
                        Otsu4SubjectQuestionListView(
                            subject: subject,
                            contentStore: contentStore,
                            purchaseStore: purchaseStore,
                            learningStore: learningStore,
                            startAll: { startSubject(subject) },
                            showPaywall: showPaywall
                        )
                    } label: {
                        row(subject, trailing: "\(contentStore.allQuestions.filter { $0.subject == subject }.count)問")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("subject-\(subject)")
                    .accessibilityLabel("\(subject)の問題一覧")
                }
            } else {
                ForEach(1...Otsu4ContentStore.mockSetCount, id: \.self) { set in
                    Button { startRound(set) } label: { row("第\(set)回", trailing: set == 1 || purchaseStore.isPremium ? "35問" : "35問  🔒") }
                        .buttonStyle(.plain).accessibilityIdentifier("round-\(set)").accessibilityLabel("第\(set)回 試験回別演習")
                }
            }
        }
    }

    private func row(_ title: String, trailing: String) -> some View {
        HStack { Text(title).font(Otsu4Theme.sans(15, weight: .bold)); Spacer(); if !trailing.isEmpty { Text(trailing).font(Otsu4Theme.sans(12)).foregroundStyle(Otsu4Theme.ink2) }; Image(systemName: "chevron.right") }
            .foregroundStyle(Otsu4Theme.ai).frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) { Text(value).font(Otsu4Theme.serif(17, weight: .bold)).foregroundStyle(color); Text(title).font(Otsu4Theme.sans(10)).foregroundStyle(Otsu4Theme.ink2) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(Otsu4Theme.card).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct Otsu4SubjectQuestionListView: View {
    let subject: String
    let contentStore: Otsu4ContentStore
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore
    let startAll: () -> Void
    let showPaywall: () -> Void

    private var allQuestions: [Otsu4Question] {
        contentStore.allQuestions.filter { $0.subject == subject }
    }

    private var availableQuestions: [Otsu4Question] {
        contentStore.questions(subject: subject, isPremium: purchaseStore.isPremium)
    }

    private var availableIDs: Set<String> {
        Set(availableQuestions.map(\.id))
    }

    var body: some View {
        ZStack {
            Otsu4PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Otsu4Card {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(subject)
                                    .font(Otsu4Theme.serif(28, weight: .bold))
                                    .foregroundStyle(Otsu4Theme.ink)
                                Spacer()
                                Text("全\(allQuestions.count)問")
                                    .font(Otsu4Theme.sans(13, weight: .bold))
                                    .foregroundStyle(Otsu4Theme.ink2)
                            }
                            Text("各問題の正解回数 / 解いた回数を確認できます。問題文は一覧では1行だけ表示します。")
                                .font(Otsu4Theme.sans(13))
                                .foregroundStyle(Otsu4Theme.ink2)

                            Button(purchaseStore.isPremium ? "全\(allQuestions.count)問を通して解く" : "無料範囲\(availableQuestions.count)問を通して解く", action: startAll)
                                .buttonStyle(.borderedProminent)
                                .tint(Otsu4Theme.shu)
                                .frame(maxWidth: .infinity)

                            if !purchaseStore.isPremium {
                                Button("全\(allQuestions.count)問を解放", action: showPaywall)
                                    .buttonStyle(.bordered)
                                    .tint(Otsu4Theme.ai)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    HStack {
                        Text("問題一覧")
                            .font(Otsu4Theme.serif(19, weight: .bold))
                            .foregroundStyle(Otsu4Theme.ink)
                        Spacer()
                        Text("正解 / 解答")
                            .font(Otsu4Theme.sans(12, weight: .bold))
                            .foregroundStyle(Otsu4Theme.ink2)
                    }
                    .padding(.top, 4)

                    ForEach(Array(allQuestions.enumerated()), id: \.element.id) { index, question in
                        let progress = learningStore.questionProgress(for: question.id)
                        let unlocked = availableIDs.contains(question.id)
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(Otsu4Theme.sans(12, weight: .bold))
                                .foregroundStyle(Otsu4Theme.ai)
                                .frame(width: 30, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(question.topic)
                                        .font(Otsu4Theme.sans(13, weight: .bold))
                                        .foregroundStyle(Otsu4Theme.ink)
                                    if !unlocked {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Otsu4Theme.kin)
                                    }
                                }
                                Text(question.question)
                                    .font(Otsu4Theme.sans(12))
                                    .foregroundStyle(Otsu4Theme.ink2)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Text("\(progress.correctCount) / \(progress.answerCount)")
                                .font(Otsu4Theme.sans(13, weight: .bold).monospacedDigit())
                                .foregroundStyle(progress.answerCount > 0 ? Otsu4Theme.ai : Otsu4Theme.ink2)
                                .frame(minWidth: 52, alignment: .trailing)
                        }
                        .padding(12)
                        .background(Otsu4Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Otsu4Theme.line, lineWidth: 1)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("第\(index + 1)問 \(question.topic) 正解\(progress.correctCount)回 解答\(progress.answerCount)回")
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("\(subject)・全問")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Otsu4FinalMockListView: View {
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    let startMock: (Int) -> Void
    let showPaywall: () -> Void
    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("模擬試験").font(Otsu4Theme.serif(30, weight: .bold))
                        Text("第1〜6回。各35問・120分。法令15／物化10／性消10、3科目すべて60%以上で合格判定。").font(Otsu4Theme.sans(14)).foregroundStyle(Otsu4Theme.ink2)
                        ForEach(1...Otsu4ContentStore.mockSetCount, id: \.self) { set in
                            Otsu4Card {
                                HStack {
                                    VStack(alignment: .leading) { Text("第\(set)回 模擬試験").font(Otsu4Theme.serif(19, weight: .bold)); Text("法令15 ／ 物化10 ／ 性消10").font(Otsu4Theme.sans(12)).foregroundStyle(Otsu4Theme.ink2) }
                                    Spacer()
                                    if purchaseStore.isPremium { Button("開始") { startMock(set) }.buttonStyle(.borderedProminent).tint(Otsu4Theme.ai).accessibilityIdentifier("mock-\(set)") }
                                    else { Button(action: showPaywall) { Label("解放", systemImage: "lock.fill") }.buttonStyle(.bordered) }
                                }
                            }
                        }
                    }.padding(18).padding(.bottom, 20)
                }
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct Otsu4FinalHistoryView: View {
    let contentStore: Otsu4ContentStore
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore
    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("学習記録").font(Otsu4Theme.serif(30, weight: .bold))
                        Otsu4Card {
                            HStack(spacing: 18) {
                                progressDonut
                                VStack(alignment: .leading, spacing: 7) { Text("達成度").font(Otsu4Theme.serif(20, weight: .bold)); Text("正答 \(learningStore.totalCorrect)問"); Text("苦手 \(learningStore.weakCount)問") }.font(Otsu4Theme.sans(13))
                                Spacer()
                            }
                        }
                        Text("5週間の学習").font(Otsu4Theme.serif(19, weight: .bold))
                        heatmap
                        Text("科目別").font(Otsu4Theme.serif(19, weight: .bold))
                        ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                            let qs = contentStore.allQuestions.filter { $0.subject == subject }
                            let seen = learningStore.seenIDs.intersection(Set(qs.map(\.id))).count
                            VStack(spacing: 4) { HStack { Text(subject).font(Otsu4Theme.sans(14, weight: .bold)); Spacer(); Text("\(seen)/\(qs.count)") }; ProgressView(value: qs.isEmpty ? 0 : Double(seen) / Double(qs.count)).tint(Otsu4Theme.ai) }
                        }
                        Text("苦手一覧").font(Otsu4Theme.serif(19, weight: .bold))
                        let weak = learningStore.weakQuestions(from: contentStore, isPremium: purchaseStore.isPremium)
                        if weak.isEmpty { Text("苦手はありません。誤答・わからないの問題がここに追加されます。").font(Otsu4Theme.sans(13)).foregroundStyle(Otsu4Theme.ink2) }
                        else { ForEach(Array(weak.prefix(8))) { q in Text("\(q.subject)・\(q.topic)　\(q.question)").font(Otsu4Theme.sans(12)).lineLimit(2).padding(8).background(Otsu4Theme.card).clipShape(RoundedRectangle(cornerRadius: 10)) } }
                    }.padding(18).padding(.bottom, 18)
                }
            }.toolbar(.hidden, for: .navigationBar)
        }
    }

    private var progressDonut: some View {
        let total = purchaseStore.isPremium ? 720 : 72
        let ratio = min(1, Double(learningStore.seenCount) / Double(total))
        return ZStack { Circle().stroke(Otsu4Theme.line, lineWidth: 9); Circle().trim(from: 0, to: ratio).stroke(Otsu4Theme.ai, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90)); Text("\(learningStore.seenCount)/\(total)").font(Otsu4Theme.sans(12, weight: .bold)) }
            .frame(width: 88, height: 88).accessibilityElement(children: .ignore).accessibilityIdentifier("全体達成度").accessibilityLabel("全体達成度").accessibilityValue("\(learningStore.seenCount) / \(total)")
    }

    private var heatmap: some View {
        let counts = learningStore.last35DayCounts()
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(15), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<35, id: \.self) { i in RoundedRectangle(cornerRadius: 3).fill(counts[i] == 0 ? Otsu4Theme.line : Otsu4Theme.shu.opacity(counts[i] < 4 ? 0.3 : 0.7)).frame(width: 15, height: 15) }
        }
    }
}
