import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var store: LearningStore

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
                        Text("ネットワークスペシャリスト")
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
                            caption: "/ \(store.settings.dailyGoal)"
                        )
                        VStack(alignment: .leading, spacing: 5) {
                            Text("今日の学習")
                                .appSans(12, weight: .bold)
                                .foregroundStyle(AppTheme.shu)
                            Text(store.todayAnswered >= store.settings.dailyGoal ? "今日の目標を達成" : "あと\(max(0, store.settings.dailyGoal - store.todayAnswered))問")
                                .appSerif(19, weight: .bold)
                                .foregroundStyle(AppTheme.ink)
                            Text("正解 \(store.todayCorrect)問・ユニーク \(store.uniqueQuestions.count)問")
                                .appSans(11)
                                .foregroundStyle(AppTheme.ink3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .appCard()

                    if let inProgress = store.state.inProgress {
                        Button {
                            store.resumeSession()
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
                        store.startToday()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 22, weight: .bold))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("今日のスプリント")
                                    .appSans(11, weight: .bold)
                                Text("\(store.settings.dailyGoal)問を解く")
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
                        store.startWeak()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "repeat")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.shu)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("苦手をつぶす")
                                    .appSans(11, weight: .bold)
                                    .foregroundStyle(AppTheme.ink3)
                                Text(store.weakQuestions.isEmpty ? "現在の苦手はありません" : "\(store.weakQuestions.count)問あります")
                                    .appSans(16, weight: .bold)
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            Text("\(store.weakQuestions.count)")
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
                    .disabled(store.weakQuestions.isEmpty)
                    .opacity(store.weakQuestions.isEmpty ? 0.72 : 1)
                    .accessibilityIdentifier("home.weak")

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
                                Text("2025・2024・2023 各25問")
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
                    .accessibilityIdentifier("home.openMock")

                    sectionHeader("分野から解く", trailing: "完答回数")
                    VStack(spacing: 10) {
                        ForEach(store.repository.domains, id: \.self) { domain in
                            let count = store.repository.uniqueQuestions(domain: domain).count
                            Button {
                                store.startDomain(domain)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(domain)
                                            .appSans(15, weight: .bold)
                                            .foregroundStyle(AppTheme.ink)
                                        Text("\(count)問")
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
                            .accessibilityLabel("\(domain)、\(count)問、完答\(store.completionCount(for: "domain:\(domain)"))回")
                        }
                    }

                    sectionHeader("これまで")
                    HStack(spacing: 10) {
                        statCard(value: "\(store.totalAnswered)", label: "回答")
                        statCard(value: "\(store.overallAccuracy)%", label: "正答率")
                        statCard(value: "\(store.weakQuestions.count)", label: "苦手")
                    }
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func countdownCard(_ info: (days: Int, pace: Int)) -> some View {
        HStack(alignment: .center) {
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
            Text(info.days > 0 ? "未学習を進める目安\n1日 \(info.pace)問" : "試験日を迎えました")
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

    private func statCard(value: String, label: String) -> some View {
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

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea()
            PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "模擬試験", subtitle: "各年度25問。解答中は正誤を表示しません。")
                    Text("通常学習は重複を除いた68問。模試は試験史実を保持するため、歴史的な再出題・類題を含む75出題枠です。")
                        .appSans(12)
                        .foregroundStyle(AppTheme.ink2)
                        .padding(14)
                        .background(AppTheme.aiSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ForEach(store.repository.years, id: \.self) { year in
                        let key = "exam:\(year)"
                        let latest = store.latestCompletion(for: key)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("\(year)年度 春期")
                                    .appSerif(20, weight: .bold)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text("午前II・25問")
                                    .appSans(11, weight: .bold)
                                    .foregroundStyle(AppTheme.ink3)
                            }
                            Button {
                                store.startMock(year: year)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(year)年度を解く")
                                            .appSans(16, weight: .bold)
                                            .foregroundStyle(AppTheme.ink)
                                        Text(mockDetail(completion: store.completionCount(for: key), latest: latest))
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
                            .accessibilityIdentifier("mock.year.\(year)")
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

    private func mockDetail(completion: Int, latest: CompletionRecord?) -> String {
        if let latest {
            return "完答 \(completion)回・直近 \(latest.correct)/\(latest.total)"
        }
        return "完答 \(completion)回"
    }
}
