import SwiftUI

private enum Otsu4GoldenTab: Hashable {
    case home, mock, history, settings
}

struct Otsu4GoldenRootView: View {
    @StateObject private var purchaseStore = Otsu4PurchaseStore()
    @StateObject private var learningStore = Otsu4LearningStore()
    @State private var contentStore: Otsu4ContentStore?
    @State private var loadError: String?
    @State private var activeSession: Otsu4StudySession?
    @State private var showingPaywall = false
    @State private var selectedTab: Otsu4GoldenTab = .home

    var body: some View {
        Group {
            if let contentStore {
                TabView(selection: $selectedTab) {
                    Otsu4GoldenHomeView(
                        contentStore: contentStore,
                        purchaseStore: purchaseStore,
                        learningStore: learningStore,
                        startSprint: { start(.sprint(learningStore.goal), from: contentStore) },
                        startWeak: { start(.weak, from: contentStore) },
                        resume: { resume(from: contentStore) },
                        goMock: { selectedTab = .mock },
                        startSubject: { start(.subject($0), from: contentStore) }
                    )
                    .tag(Otsu4GoldenTab.home)
                    .tabItem { Label("ホーム", systemImage: "house") }

                    Otsu4MockListView(
                        purchaseStore: purchaseStore,
                        startMock: { set in
                            if purchaseStore.isPremium {
                                start(.mock(set), from: contentStore)
                            } else {
                                showingPaywall = true
                            }
                        },
                        showPaywall: { showingPaywall = true }
                    )
                    .tag(Otsu4GoldenTab.mock)
                    .tabItem { Label("模試", systemImage: "doc.text") }

                    Otsu4GoldenHistoryView(
                        contentStore: contentStore,
                        purchaseStore: purchaseStore,
                        learningStore: learningStore
                    )
                    .tag(Otsu4GoldenTab.history)
                    .tabItem { Label("記録", systemImage: "chart.bar") }

                    Otsu4SettingsView(
                        purchaseStore: purchaseStore,
                        learningStore: learningStore,
                        showPaywall: { showingPaywall = true }
                    )
                    .tag(Otsu4GoldenTab.settings)
                    .tabItem { Label("設定", systemImage: "gearshape") }
                }
                .tint(Otsu4Theme.ai)
                .toolbarBackground(Otsu4Theme.card.opacity(0.96), for: .tabBar)
                .dynamicTypeSize(dynamicTypeSize)
            } else if let loadError {
                ContentUnavailableView(
                    "問題データを読み込めません",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ZStack {
                    Otsu4PaperBackground()
                    ProgressView("360問を読み込み中")
                        .tint(Otsu4Theme.ai)
                }
            }
        }
        .task {
            guard contentStore == nil, loadError == nil else { return }
            do {
                contentStore = try Otsu4ContentStore()
            } catch {
                loadError = "questions.generated.json を読み込めませんでした。"
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            Otsu4StudyFlowView(session: session, learningStore: learningStore) {
                if !session.isFinished {
                    learningStore.saveResume(session: session)
                }
                activeSession = nil
            }
            .dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(isPresented: $showingPaywall) {
            Otsu4PaywallView(purchaseStore: purchaseStore) {
                showingPaywall = false
            }
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        if ProcessInfo.processInfo.arguments.contains("OTS4_UI_TEST_ACCESSIBILITY3") {
            return .accessibility3
        }
        switch learningStore.fontScale {
        case 0: return .medium
        case 2: return .xxLarge
        default: return .large
        }
    }

    private func resume(from store: Otsu4ContentStore) {
        activeSession = learningStore.restoreSession(from: store)
    }

    private func start(_ kind: Otsu4StudyKind, from store: Otsu4ContentStore) {
        let questions: [Otsu4Question]
        switch kind {
        case .sprint(let goal):
            questions = store.sprint(goal: goal, isPremium: purchaseStore.isPremium)
        case .weak:
            questions = Array(
                learningStore
                    .weakQuestions(from: store, isPremium: purchaseStore.isPremium)
                    .shuffled()
                    .prefix(learningStore.goal)
            )
        case .subject(let subject):
            questions = Array(
                store
                    .questions(subject: subject, isPremium: purchaseStore.isPremium)
                    .shuffled()
                    .prefix(learningStore.goal)
            )
        case .mock(let set):
            questions = store.mockExamQuestions(set: set) ?? []
        }
        guard !questions.isEmpty else { return }
        learningStore.clearResume()
        activeSession = Otsu4StudySession(kind: kind, questions: questions)
    }
}

struct Otsu4GoldenHomeView: View {
    let contentStore: Otsu4ContentStore
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore
    let startSprint: () -> Void
    let startWeak: () -> Void
    let resume: () -> Void
    let goMock: () -> Void
    let startSubject: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if let days = learningStore.examDaysRemaining {
                            examCountdown(days: days)
                        }
                        todayCard
                        if learningStore.resumeSnapshot != nil {
                            Button(action: resume) {
                                Label("続きから再開", systemImage: "arrow.clockwise")
                                    .font(Otsu4Theme.sans(15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.bordered)
                            .tint(Otsu4Theme.ai)
                        }
                        primaryActions
                        subjectSection
                        summarySection
                        auditFootnote
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .padding(.bottom, 14)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("学びスプリント")
                .font(Otsu4Theme.sans(12, weight: .bold))
                .foregroundStyle(Otsu4Theme.shu)
            Text("危険物 乙4")
                .font(Otsu4Theme.serif(34, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            Text("今日も1問、力に変える。")
                .font(Otsu4Theme.sans(15, weight: .medium))
                .foregroundStyle(Otsu4Theme.ink2)
        }
    }

    private func examCountdown(days: Int) -> some View {
        let pace = learningStore.requiredDailyPace(totalQuestions: 360)
        return HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("試験まで")
                    .font(Otsu4Theme.sans(12, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink3)
                Text("\(days)日")
                    .font(Otsu4Theme.serif(32, weight: .bold))
                    .foregroundStyle(Otsu4Theme.shu)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(days == 0 ? "今日が試験日です" : "必要ペース")
                    .font(Otsu4Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Otsu4Theme.ink2)
                if days > 0, let pace {
                    Text("\(pace)問 / 日")
                        .font(Otsu4Theme.serif(20, weight: .bold))
                        .foregroundStyle(Otsu4Theme.ai)
                }
            }
        }
        .padding(14)
        .background(Otsu4Theme.shuSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var todayCard: some View {
        Otsu4Card {
            HStack(spacing: 16) {
                Otsu4ProgressRing(
                    value: learningStore.todayProgress,
                    label: "\(learningStore.todayAnswered)/\(learningStore.goal)"
                )
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日のスプリント")
                        .font(Otsu4Theme.serif(20, weight: .bold))
                        .foregroundStyle(Otsu4Theme.ink)
                    Text("\(learningStore.goal)問を短く周回")
                        .font(Otsu4Theme.sans(13, weight: .medium))
                        .foregroundStyle(Otsu4Theme.ink2)
                    Button("始める", action: startSprint)
                        .buttonStyle(.borderedProminent)
                        .tint(Otsu4Theme.shu)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var primaryActions: some View {
        VStack(spacing: 10) {
            Button(action: startWeak) {
                HStack {
                    Label("苦手を復習", systemImage: "repeat")
                    Spacer()
                    Text("\(learningStore.weakCount)問")
                }
                .font(Otsu4Theme.sans(15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(Otsu4Theme.shu)
            .disabled(learningStore.weakCount == 0)

            Button(action: goMock) {
                HStack {
                    Label("模擬試験へ", systemImage: "timer")
                    Spacer()
                    Text("35問・120分")
                }
                .font(Otsu4Theme.sans(15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(Otsu4Theme.ai)
        }
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分野から解く")
                .font(Otsu4Theme.serif(20, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                Button {
                    startSubject(subject)
                } label: {
                    HStack(spacing: 12) {
                        Text(subject)
                            .font(Otsu4Theme.sans(15, weight: .bold))
                        Spacer(minLength: 12)
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .foregroundStyle(Otsu4Theme.ai)
                .accessibilityLabel("\(subject)を学習")
                .accessibilityIdentifier("subject-\(subject)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで")
                .font(Otsu4Theme.serif(20, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            HStack(spacing: 10) {
                summaryChip(title: "学習済み", value: "\(learningStore.seenCount)問", color: Otsu4Theme.ai)
                summaryChip(title: "苦手", value: "\(learningStore.weakCount)問", color: Otsu4Theme.shu)
                summaryChip(title: "全問題", value: purchaseStore.isPremium ? "360問" : "72問", color: Otsu4Theme.midori)
            }
        }
    }

    private func summaryChip(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Otsu4Theme.serif(18, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(Otsu4Theme.sans(11, weight: .medium))
                .foregroundStyle(Otsu4Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Otsu4Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var auditFootnote: some View {
        Text("問題データ: \(contentStore.bank.contentVersion) ／ 監査日 \(contentStore.bank.lawAuditDate)")
            .font(Otsu4Theme.sans(10))
            .foregroundStyle(Otsu4Theme.ink3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

struct Otsu4GoldenHistoryView: View {
    let contentStore: Otsu4ContentStore
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("学習記録")
                            .font(Otsu4Theme.serif(30, weight: .bold))
                            .foregroundStyle(Otsu4Theme.ink)

                        achievementCard
                        heatmapSection
                        subjectSection
                        weakSection

                        if !purchaseStore.isPremium {
                            Text("無料版は72問まで。Premiumでは360問すべての進捗と苦手を継続して確認できます。")
                                .font(Otsu4Theme.sans(12))
                                .foregroundStyle(Otsu4Theme.ink3)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var achievementCard: some View {
        Otsu4Card {
            HStack(spacing: 18) {
                Otsu4AchievementDonut(
                    value: Double(learningStore.seenCount) / 360.0,
                    label: "\(learningStore.seenCount)/360"
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("達成度")
                        .font(Otsu4Theme.serif(20, weight: .bold))
                        .foregroundStyle(Otsu4Theme.ink)
                    HStack(spacing: 14) {
                        historyMetric("正答", "\(learningStore.totalCorrect)問")
                        historyMetric("苦手", "\(learningStore.weakCount)問")
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func historyMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Otsu4Theme.serif(18, weight: .bold))
                .foregroundStyle(title == "苦手" ? Otsu4Theme.shu : Otsu4Theme.ai)
            Text(title)
                .font(Otsu4Theme.sans(11))
                .foregroundStyle(Otsu4Theme.ink3)
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("5週間の学習")
                .font(Otsu4Theme.serif(19, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            heatmap
        }
    }

    private var heatmap: some View {
        let counts = learningStore.last35DayCounts()
        let columns = Array(repeating: GridItem(.fixed(15), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<35, id: \.self) { index in
                let count = counts[index]
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(heatColor(count))
                    .frame(width: 15, height: 15)
                    .accessibilityLabel("\(34 - index)日前 \(count)問")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func heatColor(_ count: Int) -> Color {
        switch count {
        case 0: return Otsu4Theme.line
        case 1...3: return Otsu4Theme.shu.opacity(0.28)
        case 4...7: return Otsu4Theme.shu.opacity(0.58)
        default: return Otsu4Theme.shu
        }
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("科目別")
                .font(Otsu4Theme.serif(19, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                let questions = contentStore.allQuestions.filter { $0.subject == subject }
                let total = questions.count
                let seen = learningStore.seenIDs.intersection(Set(questions.map(\.id))).count
                VStack(spacing: 5) {
                    HStack {
                        Text(subject)
                            .font(Otsu4Theme.sans(14, weight: .bold))
                        Spacer()
                        Text("\(seen)/\(total)")
                            .font(Otsu4Theme.sans(13))
                            .foregroundStyle(Otsu4Theme.ink2)
                    }
                    ProgressView(value: total == 0 ? 0 : Double(seen) / Double(total))
                        .tint(Otsu4Theme.ai)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var weakSection: some View {
        let weak = learningStore.weakQuestions(from: contentStore, isPremium: purchaseStore.isPremium)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("苦手一覧")
                    .font(Otsu4Theme.serif(19, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink)
                Spacer()
                Text("\(weak.count)問")
                    .font(Otsu4Theme.sans(12, weight: .bold))
                    .foregroundStyle(Otsu4Theme.shu)
            }

            if weak.isEmpty {
                Text("苦手はありません。誤答・わからないの問題がここに追加されます。")
                    .font(Otsu4Theme.sans(13))
                    .foregroundStyle(Otsu4Theme.ink3)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(weak.prefix(8))) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(question.subject)・\(question.topic)")
                            .font(Otsu4Theme.sans(11, weight: .bold))
                            .foregroundStyle(Otsu4Theme.shu)
                        Text(question.question)
                            .font(Otsu4Theme.serif(15, weight: .semibold))
                            .foregroundStyle(Otsu4Theme.ink)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Otsu4Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Otsu4Theme.line, lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                }
                if weak.count > 8 {
                    Text("ほか \(weak.count - 8)問。ホームの「苦手を復習」から周回できます。")
                        .font(Otsu4Theme.sans(12))
                        .foregroundStyle(Otsu4Theme.ink3)
                }
            }
        }
    }
}

private struct Otsu4AchievementDonut: View {
    let value: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Otsu4Theme.line, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, max(0, value)))
                .stroke(Otsu4Theme.ai, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(Otsu4Theme.sans(13, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 82, height: 82)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("全体達成度")
        .accessibilityValue(label)
    }
}
