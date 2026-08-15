import SwiftUI

struct KanteishiShortAnswerRootView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var purchases: PremiumPurchaseStore

    var body: some View {
        Group {
            if let error = store.startupError {
                StartupErrorView(message: error)
            } else if let result = store.result {
                if purchases.isPremium || !store.requiresPremium(questionIDs: result.questionIDs) {
                    ResultScreen(result: result)
                } else {
                    PremiumSessionLockedView(title: result.title)
                }
            } else if let session = store.session {
                if purchases.isPremium || !store.requiresPremium(questionIDs: session.questionIDs) {
                    QuizScreen()
                } else {
                    PremiumSessionLockedView(title: session.title)
                }
            } else {
                VStack(spacing: 0) {
                    Group {
                        switch store.currentTab {
                        case .home: HomeView()
                        case .mock: MockView()
                        case .history: HistoryView()
                        case .settings: SettingsView()
                        }
                    }
                    BottomTabBar(selection: $store.currentTab)
                }
                .background(AppTheme.paper)
            }
        }
        .environment(\.appFontScale, store.fontScale)
        .tint(AppTheme.ai)
        .preferredColorScheme(.light)
    }
}

private struct StartupErrorView: View {
    let message: String
    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.shu)
                Text("学習データを読み込めません")
                    .appSerif(22, weight: .bold)
                    .foregroundStyle(AppTheme.ink)
                Text(message)
                    .appSans(13)
                    .foregroundStyle(AppTheme.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 420)
        }
        .accessibilityIdentifier("startup.error")
    }
}

private struct PremiumSessionLockedView: View {
    @EnvironmentObject private var store: LearningStore
    let title: String

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.ai)
                Text("プレミアム学習を一時停止中")
                    .appSerif(21, weight: .bold)
                    .foregroundStyle(AppTheme.ink)
                Text(title)
                    .appSans(13, weight: .bold)
                    .foregroundStyle(AppTheme.ink2)
                Text("購入状態を確認すると、全240問と年度別80問模試を再開できます。")
                    .appSans(12)
                    .foregroundStyle(AppTheme.ink3)
                    .multilineTextAlignment(.center)
                Button {
                    store.exitSessionToHome()
                    store.currentTab = .settings
                } label: {
                    Text("プレミアムを確認")
                        .appSans(15, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(AppTheme.ai)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 420)
        }
        .accessibilityIdentifier("premium.sessionLocked")
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var purchases: PremiumPurchaseStore

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea()
            PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("学びスプリント")
                            .appSans(12, weight: .bold)
                            .foregroundStyle(AppTheme.ai)
                        Text("不動産鑑定士試験・短答式")
                            .appSerif(27, weight: .bold)
                            .foregroundStyle(AppTheme.ink)
                            .accessibilityIdentifier("home.title")
                        Text("今日も1問、力に変える。")
                            .appSans(14)
                            .foregroundStyle(AppTheme.ink2)
                    }
                    .padding(.top, 18)

                    if let countdown = store.examCountdown {
                        countdownCard(countdown)
                    }

                    HStack(spacing: 16) {
                        ProgressRing(
                            progress: store.todayGoalProgress,
                            value: "\(store.todayAnswered)",
                            caption: "/ \(store.todaySessionTarget)"
                        )
                        VStack(alignment: .leading, spacing: 5) {
                            Text("今日の学習")
                                .appSans(12, weight: .bold)
                                .foregroundStyle(AppTheme.shu)
                            Text(
                                store.todayAnswered >= store.todaySessionTarget
                                    ? "今日の目標を達成"
                                    : "あと\(max(0, store.todaySessionTarget - store.todayAnswered))問"
                            )
                            .appSerif(19, weight: .bold)
                            .foregroundStyle(AppTheme.ink)
                            Text("正解 \(store.todayCorrect)問・公式過去問 \(store.repository.questions.count)問")
                                .appSans(11)
                                .foregroundStyle(AppTheme.ink3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .appCard()

                    if let inProgress = store.state.inProgress {
                        Button {
                            if !store.resumeSession(isPremium: purchases.isPremium) { store.currentTab = .settings }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppTheme.ai)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("続きから再開")
                                        .appSans(11, weight: .bold)
                                        .foregroundStyle(AppTheme.ink3)
                                    Text(inProgress.title)
                                        .appSans(15, weight: .bold)
                                        .foregroundStyle(AppTheme.ink)
                                }
                                Spacer()
                                Text("\(min(inProgress.index + 1, inProgress.total)) / \(inProgress.total)")
                                    .appSans(12, weight: .bold)
                                    .foregroundStyle(AppTheme.ai)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.ink3)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                        .appCard()
                        .accessibilityIdentifier("home.resume")
                    }

                    Button {
                        store.startToday(isPremium: purchases.isPremium)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 22, weight: .bold))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("今日のスプリント")
                                    .appSans(11, weight: .bold)
                                Text("\(store.todaySessionTarget)問を解く")
                                    .appSans(18, weight: .bold)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .background(AppTheme.ai)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.startToday")

                    Button {
                        if !store.startWeak(isPremium: purchases.isPremium) { store.currentTab = .settings }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "repeat")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.shu)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("苦手をつぶす")
                                    .appSans(11, weight: .bold)
                                    .foregroundStyle(AppTheme.ink3)
                                Text(store.accessibleWeakQuestions(isPremium: purchases.isPremium).isEmpty ? "現在の苦手はありません" : "\(store.accessibleWeakQuestions(isPremium: purchases.isPremium).count)問あります")
                                    .appSans(16, weight: .bold)
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            Text("\(store.accessibleWeakQuestions(isPremium: purchases.isPremium).count)")
                                .appSerif(18, weight: .bold)
                                .foregroundStyle(AppTheme.shu)
                                .frame(minWidth: 34, minHeight: 34)
                                .background(AppTheme.shuSoft)
                                .clipShape(Circle())
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                    .appCard()
                    .disabled(store.accessibleWeakQuestions(isPremium: purchases.isPremium).isEmpty)
                    .opacity(store.accessibleWeakQuestions(isPremium: purchases.isPremium).isEmpty ? 0.72 : 1)

                    Button {
                        store.currentTab = .mock
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.ai)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("模擬試験")
                                    .appSans(11, weight: .bold)
                                    .foregroundStyle(AppTheme.ink3)
                                Text("令和8・7・6年／公式過去問 各80問")
                                    .appSans(16, weight: .bold)
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.ink3)
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                    .appCard()

                    sectionHeader("分野から解く", trailing: "完答回数")
                    ForEach(store.repository.domains, id: \.self) { domain in
                        Button {
                            if !store.startDomain(domain, isPremium: purchases.isPremium) { store.currentTab = .settings }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(domain)
                                        .appSans(15, weight: .bold)
                                        .foregroundStyle(AppTheme.ink)
                                    Text("\(store.accessibleQuestionCount(store.repository.questions(domain: domain), isPremium: purchases.isPremium))問")
                                        .appSans(11)
                                        .foregroundStyle(AppTheme.ink3)
                                }
                                Spacer()
                                Text("\(store.completionCount(for: "domain:\(domain)"))回")
                                    .appSans(12, weight: .bold)
                                    .foregroundStyle(AppTheme.ai)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.ink3)
                            }
                            .padding(15)
                            .frame(minHeight: 54)
                        }
                        .buttonStyle(.plain)
                        .appCard()
                    }

                    sectionHeader("これまで")
                    HStack(spacing: 10) {
                        statCard("\(store.totalAnswered)", "回答")
                        statCard("\(store.overallAccuracy)%", "正答率")
                        statCard("\(store.accessibleWeakQuestions(isPremium: purchases.isPremium).count)", "苦手")
                    }
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func countdownCard(_ info: (days: Int, pace: Int)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("試験まで")
                    .appSans(11, weight: .bold)
                    .foregroundStyle(AppTheme.ink3)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(info.days >= 0 ? "\(info.days)" : "—")
                        .appSerif(34, weight: .bold)
                        .foregroundStyle(AppTheme.shu)
                    Text("日")
                        .appSans(13, weight: .bold)
                        .foregroundStyle(AppTheme.ink2)
                }
            }
            Spacer()
            Text(info.days > 0 ? "240問を一周する目安\n1日 \(info.pace)問" : "試験日を迎えました")
                .appSans(12, weight: .semibold)
                .foregroundStyle(AppTheme.ink2)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
        .background(AppTheme.shuSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title)
                .appSerif(19, weight: .bold)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .appSans(11, weight: .bold)
                    .foregroundStyle(AppTheme.ink3)
            }
        }
        .padding(.top, 4)
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .appSerif(21, weight: .bold)
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .appSans(11, weight: .bold)
                .foregroundStyle(AppTheme.ink3)
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .appCard()
    }
}

struct MockView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var purchases: PremiumPurchaseStore
    private let subjects = ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"]

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea()
            PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "模擬試験", subtitle: "令和8・7・6年。年度別80問または科目別40問から選べます。")
                    Text("各年度は行政法規40問＋鑑定理論40問＝80問。3年度合計240問の公式過去問を収録しています。")
                        .appSans(12)
                        .foregroundStyle(AppTheme.ink2)
                        .padding(14)
                        .background(AppTheme.aiSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    if !purchases.isPremium {
                        Label("無料版は24問。年度別80問模試と全240問はプレミアムで利用できます。", systemImage: "lock.fill")
                            .appSans(11, weight: .bold)
                            .foregroundStyle(AppTheme.ai)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.aiSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    ForEach(store.repository.editions, id: \.self) { edition in
                        let examKey = "exam:\(edition)"
                        let latest = store.latestCompletion(for: examKey)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("令和\(edition - 2018)年")
                                    .appSerif(20, weight: .bold)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text("公式80問")
                                    .appSans(11, weight: .bold)
                                    .foregroundStyle(AppTheme.ink3)
                            }

                            Button {
                                if !store.startMock(edition: edition, isPremium: purchases.isPremium) { store.currentTab = .settings }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("年度別模試・80問")
                                            .appSans(16, weight: .bold)
                                            .foregroundStyle(AppTheme.ink)
                                        Text(
                                            latest.map {
                                                "完答 \(store.completionCount(for: examKey))回・直近 \($0.correct)/\($0.total)"
                                            } ?? "完答 \(store.completionCount(for: examKey))回"
                                        )
                                        .appSans(11)
                                        .foregroundStyle(AppTheme.ink3)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AppTheme.ai)
                                }
                                .padding(16)
                                .frame(minHeight: 62)
                            }
                            .buttonStyle(.plain)
                            .appCard()
                            .accessibilityIdentifier("mock.edition.\(edition)")

                            Text("科目別演習")
                                .appSans(11, weight: .bold)
                                .foregroundStyle(AppTheme.ink3)
                                .padding(.top, 2)

                            ForEach(subjects, id: \.self) { subject in
                                let questions = store.repository.questions(edition: edition).filter { $0.subject == subject }
                                let key = "exam:\(edition):subject:\(subject)"
                                Button {
                                    if !store.startEditionSubject(edition: edition, subject: subject, isPremium: purchases.isPremium) { store.currentTab = .settings }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(shortSubject(subject))
                                                .appSans(14, weight: .bold)
                                                .foregroundStyle(AppTheme.ink)
                                            Text("\(store.accessibleQuestionCount(questions, isPremium: purchases.isPremium))問・完答 \(store.completionCount(for: key))回")
                                                .appSans(11)
                                                .foregroundStyle(AppTheme.ink3)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(AppTheme.ai)
                                    }
                                    .padding(14)
                                    .frame(minHeight: 56)
                                }
                                .buttonStyle(.plain)
                                .appCard()
                                .accessibilityIdentifier("mock.subject.\(edition).\(subject)")
                            }
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("mock.screen")
    }

    private func shortSubject(_ subject: String) -> String {
        subject == "不動産に関する行政法規" ? "行政法規" : "鑑定理論"
    }
}
