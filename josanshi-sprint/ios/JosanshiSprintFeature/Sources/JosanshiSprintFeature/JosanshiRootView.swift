import SwiftUI
import LearningSprintCore
import UniformTypeIdentifiers

@MainActor
public struct JosanshiRootView: View {
    @StateObject private var model: JosanshiDashboardModel
    @State private var backupDocument = JosanshiBackupDocument()
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupMessage: String?
    @State private var isResetConfirmationPresented = false

    public init() {
        _model = StateObject(wrappedValue: JosanshiDashboardModel(enableStoreKit: true))
    }

    public init(model: JosanshiDashboardModel) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            TabView(selection: $model.selectedTab) {
                NavigationStack { home }
                    .tabItem { Label("ホーム", systemImage: "house") }
                    .tag(JosanshiFeatureTab.home)

                NavigationStack { mock }
                    .tabItem { Label("模試", systemImage: "doc.text") }
                    .tag(JosanshiFeatureTab.mock)

                NavigationStack { history }
                    .tabItem { Label("記録", systemImage: "chart.bar") }
                    .tag(JosanshiFeatureTab.history)

                NavigationStack { settings }
                    .tabItem { Label("設定", systemImage: "gearshape") }
                    .tag(JosanshiFeatureTab.settings)
            }
            .tint(LearningSprintTheme.indigo)
        }
        .dynamicTypeSize(dynamicTypeRange)
        .sheet(isPresented: $model.isSessionPresented) {
            NavigationStack {
                JosanshiQuestionSessionView(
                    coordinator: model.coordinator,
                    questionBank: model.questionBank,
                    onFinish: model.finishSession
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            model.finishSession()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $model.isPaywallPresented) {
            JosanshiPremiumPaywallView(model: model)
        }
        .alert("問題データを読み込めません", isPresented: $model.isContentGatePresented) {
            Button("OK", role: .cancel) { model.dismissContentError() }
        } message: {
            Text(model.contentErrorDescription ?? "処理できませんでした。")
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "josanshi-sprint-backup"
        ) { result in
            if case .failure(let error) = result {
                backupMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
        .alert("バックアップ", isPresented: Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )) {
            Button("OK", role: .cancel) { backupMessage = nil }
        } message: {
            Text(backupMessage ?? "")
        }
        .alert("学習記録をリセットしますか？", isPresented: $isResetConfirmationPresented) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) { model.resetLearningHistory() }
        } message: {
            Text("回答履歴・苦手・途中の演習・模試の完了記録を削除します。文字サイズ、1日の目標、試験日、シャッフル設定は残ります。")
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("学びスプリント")
                        .font(LearningSprintTheme.sans(12, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text("助産師国家試験")
                        .font(LearningSprintTheme.serif(28, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text("今日も1問、力に変える。")
                        .font(LearningSprintTheme.sans(14))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                if let days = model.remainingDays {
                    examCountdown(days: days)
                }

                HStack(spacing: 16) {
                    LearningSprintProgressRing(
                        progress: model.todayProgress,
                        label: "\(model.todayAnsweredCount) / \(model.dailyTarget)"
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日の学習")
                            .font(LearningSprintTheme.serif(20, weight: .semibold))
                        Text("\(model.dailyTarget)問を目標に、短い時間で積み上げます。")
                            .font(LearningSprintTheme.sans(14))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .background(LearningSprintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if model.hasResumableSession {
                    Button(action: model.resumePreviousSession) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("続きから再開")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            Spacer()
                            Text(model.coordinator.sessionProgressText)
                                .font(LearningSprintTheme.sans(13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 14)
                        .foregroundStyle(LearningSprintTheme.indigo)
                        .background(LearningSprintTheme.indigoSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("resume-session")
                }

                Button(action: model.requestStandardSprint) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今日のスプリント")
                                .font(LearningSprintTheme.serif(20, weight: .bold))
                            Text(model.isPremium ? "\(model.dailyTarget)問・全330問から出題" : "\(model.dailyTarget)問・無料\(model.freeQuestionCount)問から出題")
                                .font(LearningSprintTheme.sans(13))
                                .opacity(0.82)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.title3.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [LearningSprintTheme.indigo, Color(hex: 0x1D2C42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!model.hasReadyContent)
                .accessibilityIdentifier("start-standard-sprint")

                actionCard(
                    title: "苦手をつぶす",
                    subtitle: model.isPremium
                        ? (model.weakQuestionCount > 0 ? "\(model.weakQuestionCount)問を復習" : "苦手はまだありません")
                        : "Premiumで苦手だけを復習",
                    systemImage: model.isPremium ? "arrow.triangle.2.circlepath" : "lock.fill",
                    accent: LearningSprintTheme.vermilion,
                    enabled: model.isPremium ? model.weakQuestionCount > 0 : true,
                    accessibilityIdentifier: "start-weak-review",
                    action: model.requestWeakReview
                )

                actionCard(
                    title: "模擬試験",
                    subtitle: model.isPremium ? "110問 × 3回・FULL監査済み" : "Premium・110問 × 3回",
                    systemImage: model.isPremium ? "doc.text" : "lock.fill",
                    accent: LearningSprintTheme.indigo,
                    enabled: model.hasReadyContent,
                    accessibilityIdentifier: "open-mock-tab",
                    action: model.showMockTab
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("分野から解く")
                        .font(LearningSprintTheme.serif(20, weight: .semibold))
                    ForEach(JosanshiExamConfiguration.subjects, id: \.self) { subject in
                        Button {
                            model.requestSubjectPractice(subject)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject)
                                        .font(LearningSprintTheme.sans(16, weight: .semibold))
                                        .foregroundStyle(LearningSprintTheme.ink)
                                    if model.isPremium, let accuracy = model.coordinator.subjectAccuracy[subject] {
                                        Text("正答率 \(Int((accuracy * 100).rounded()))%")
                                            .font(LearningSprintTheme.sans(11))
                                            .foregroundStyle(LearningSprintTheme.ink3)
                                    } else if !model.isPremium {
                                        Text("Premium")
                                            .font(LearningSprintTheme.sans(11, weight: .bold))
                                            .foregroundStyle(LearningSprintTheme.vermilion)
                                    }
                                }
                                Spacer()
                                Image(systemName: model.isPremium ? "chevron.right" : "lock.fill")
                                    .foregroundStyle(model.isPremium ? LearningSprintTheme.ink3 : LearningSprintTheme.vermilion)
                            }
                            .frame(minHeight: 44)
                            .padding(.horizontal, 14)
                            .background(LearningSprintTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!model.hasReadyContent)
                        .accessibilityLabel("\(subject)を演習")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("これまで")
                        .font(LearningSprintTheme.serif(20, weight: .semibold))
                    HStack(spacing: 10) {
                        metricCard(title: "回答", value: "\(model.totalAnsweredCount)問")
                        metricCard(title: "正答率", value: "\(Int((model.overallAccuracy * 100).rounded()))%")
                        metricCard(title: "苦手", value: "\(model.weakQuestionCount)問")
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("")
        .background(Color.clear)
    }

    private func examCountdown(days: Int) -> some View {
        let urgent = days <= 14
        return VStack(alignment: .leading, spacing: 5) {
            Text("試験日まで")
                .font(LearningSprintTheme.sans(12, weight: .bold))
                .opacity(0.85)
            HStack(alignment: .firstTextBaseline) {
                Text("あと\(days)日")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                Spacer()
                if let pace = model.requiredDailyPace {
                    Text("1日 \(pace)問")
                        .font(LearningSprintTheme.sans(14, weight: .bold))
                }
            }
            Text("未回答 \(model.remainingQuestionCount)問。現在の進み方から必要ペースを計算しています。")
                .font(LearningSprintTheme.sans(12))
                .opacity(0.85)
        }
        .padding(16)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: urgent
                    ? [Color(hex: 0xC14328), Color(hex: 0x96301C)]
                    : [Color(hex: 0x2B3F5C), Color(hex: 0x1D2C42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func actionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        enabled: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(LearningSprintTheme.sans(16, weight: .bold))
                    Text(subtitle)
                        .font(LearningSprintTheme.sans(12))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(LearningSprintTheme.card)
            .foregroundStyle(enabled ? accent : LearningSprintTheme.ink3)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearningSprintTheme.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var mock: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("模試")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                Text("独自模試3回分。各110問＝一般75問＋状況設定35問で構成します。")
                    .font(LearningSprintTheme.sans(15))
                    .foregroundStyle(LearningSprintTheme.ink2)

                if !model.isPremium {
                    premiumLockCard(
                        title: "模試はPremiumで開放",
                        detail: "3回分・合計330問の本番形式に取り組めます。"
                    )
                }

                ForEach(1...JosanshiExamConfiguration.originalMockSetCount, id: \.self) { index in
                    Button {
                        model.requestMock(index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("独自模試 \(index)")
                                    .font(LearningSprintTheme.serif(20, weight: .semibold))
                                    .foregroundStyle(LearningSprintTheme.ink)
                                Text(model.isPremium ? "110問・FULL監査済み" : "Premium")
                                    .font(LearningSprintTheme.sans(14, weight: model.isPremium ? .regular : .bold))
                                    .foregroundStyle(model.isPremium ? LearningSprintTheme.ink2 : LearningSprintTheme.vermilion)
                            }
                            Spacer()
                            Image(systemName: model.isPremium ? "play.circle.fill" : "lock.fill")
                                .font(.title2)
                                .foregroundStyle(LearningSprintTheme.indigo)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.hasReadyContent)
                    .accessibilityIdentifier("start-mock-\(index)")
                }
            }
            .padding(18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("記録")
                    .font(LearningSprintTheme.serif(28, weight: .bold))

                VStack(alignment: .leading, spacing: 12) {
                    Text("達成度")
                        .font(LearningSprintTheme.serif(20, weight: .semibold))
                    HStack(spacing: 18) {
                        LearningSprintProgressRing(
                            progress: Double(model.uniqueAnsweredCount) / Double(JosanshiExamConfiguration.originalProductionQuestionTarget),
                            label: "\(model.uniqueAnsweredCount) / \(JosanshiExamConfiguration.originalProductionQuestionTarget)"
                        )
                        VStack(alignment: .leading, spacing: 5) {
                            Text("全330問のうち\(model.uniqueAnsweredCount)問に触れました")
                                .font(LearningSprintTheme.sans(14, weight: .semibold))
                            Text("総回答 \(model.totalAnsweredCount)回・正解 \(model.totalCorrectCount)回")
                                .font(LearningSprintTheme.sans(12))
                                .foregroundStyle(LearningSprintTheme.ink2)
                        }
                    }
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if model.isPremium {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("分野別正答率")
                            .font(LearningSprintTheme.serif(20, weight: .semibold))
                        ForEach(JosanshiExamConfiguration.subjects, id: \.self) { subject in
                            let accuracy = model.coordinator.subjectAccuracy[subject] ?? 0
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(subject)
                                        .font(LearningSprintTheme.sans(13, weight: .semibold))
                                    Spacer()
                                    Text("\(Int((accuracy * 100).rounded()))%")
                                        .font(LearningSprintTheme.sans(12, weight: .bold))
                                }
                                ProgressView(value: accuracy)
                                    .tint(LearningSprintTheme.indigo)
                            }
                        }
                    }
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("直近5週間")
                            .font(LearningSprintTheme.serif(20, weight: .semibold))
                        LearningSprintHeatmap(values: model.coordinator.heatmap35Days)
                    }

                    weakList
                    recentSessions
                } else {
                    premiumLockCard(
                        title: "詳細な記録はPremium",
                        detail: "分野別正答率・5週間ヒートマップ・苦手一覧・直近20セッションを確認できます。"
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var weakList: some View {
        let weak = model.coordinator.state.weakQuestions
            .sorted { $0.value.lastAnsweredAt > $1.value.lastAnsweredAt }
        return VStack(alignment: .leading, spacing: 10) {
            Text("苦手一覧")
                .font(LearningSprintTheme.serif(20, weight: .semibold))

            if weak.isEmpty {
                Text("苦手はまだありません。間違えた問題や「わからない」がここに集まります。")
                    .font(LearningSprintTheme.sans(13))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(Array(weak.prefix(10)), id: \.key) { id, status in
                    let prompt = model.coordinator.questions.first(where: { $0.id == id })?.prompt ?? id
                    HStack(alignment: .top, spacing: 10) {
                        Text(prompt)
                            .font(LearningSprintTheme.sans(13))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(index < status.consecutiveCorrect ? LearningSprintTheme.green : LearningSprintTheme.line)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 5)
                        .accessibilityLabel("連続正解 \(status.consecutiveCorrect) / 3")
                    }
                    .padding(14)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(action: model.requestWeakReview) {
                    Text("苦手だけ解く（\(model.weakQuestionCount)問）")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(LearningSprintTheme.vermilion)
            }
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("直近のスプリント")
                .font(LearningSprintTheme.serif(20, weight: .semibold))

            if model.coordinator.recentSessions.isEmpty {
                Text("完了した演習はまだありません。")
                    .font(LearningSprintTheme.sans(13))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(Array(model.coordinator.recentSessions.prefix(20))) { entry in
                    HStack(spacing: 12) {
                        Text(entry.finishedAt, format: .dateTime.month().day())
                            .font(LearningSprintTheme.sans(12, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.ink3)
                            .frame(width: 54, alignment: .leading)
                        Text(entry.title)
                            .font(LearningSprintTheme.sans(13, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(entry.correctCount) / \(entry.totalCount)")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.indigo)
                    }
                    .padding(13)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func premiumLockCard(title: String, detail: String) -> some View {
        Button(action: model.presentPaywall) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(LearningSprintTheme.vermilion)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LearningSprintTheme.sans(15, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text(detail)
                        .font(LearningSprintTheme.sans(12))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LearningSprintTheme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LearningSprintTheme.vermilion.opacity(0.25), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-premium-paywall")
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(LearningSprintTheme.sans(11, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink3)
            Text(value)
                .font(LearningSprintTheme.serif(19, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var settings: some View {
        Form {
            Section("文字サイズ") {
                Picker("文字サイズ", selection: Binding(
                    get: { model.textSizeStep },
                    set: { model.setTextSizeStep($0) }
                )) {
                    Text("標準").tag(0)
                    Text("大").tag(1)
                    Text("特大").tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section("1日の目標") {
                Picker("問題数", selection: Binding(
                    get: { model.dailyTarget },
                    set: { model.setDailyTarget($0) }
                )) {
                    ForEach(JosanshiExamConfiguration.selectableDailyTargets, id: \.self) { value in
                        Text("\(value)問").tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("出題順シャッフル") {
                Toggle("演習の出題順をシャッフル", isOn: Binding(
                    get: { model.shuffleQuestions },
                    set: { model.setShuffleQuestions($0) }
                ))
                Text("模試は症例の順序を保つため、設定に関係なく固定順です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("選択肢シャッフル") {
                Toggle("選択肢の順番をシャッフル", isOn: Binding(
                    get: { model.shuffleChoices },
                    set: { model.setShuffleChoices($0) }
                ))
            }

            Section("試験日") {
                Toggle("試験日を設定", isOn: Binding(
                    get: { model.examDate != nil },
                    set: { enabled in
                        if enabled {
                            let initial = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                            model.setExamDate(initial)
                        } else {
                            model.setExamDate(nil)
                        }
                    }
                ))
                if model.examDate != nil {
                    DatePicker(
                        "日付",
                        selection: Binding(
                            get: { model.examDate ?? Date() },
                            set: { model.setExamDate($0) }
                        ),
                        displayedComponents: .date
                    )
                }
            }

            Section("学習データ") {
                Button("JSONを書き出す") {
                    guard model.isPremium else {
                        model.presentPaywall()
                        return
                    }
                    do {
                        backupDocument = JosanshiBackupDocument(data: try model.exportBackup())
                        isExportingBackup = true
                    } catch {
                        backupMessage = error.localizedDescription
                    }
                }
                Button("JSONから復元") {
                    if model.isPremium {
                        isImportingBackup = true
                    } else {
                        model.presentPaywall()
                    }
                }
                if !model.isPremium {
                    Text("バックアップ・復元はPremium機能です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = model.coordinator.persistenceErrorDescription {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("覚えかたのルール") {
                Text("間違えた問題と「わからない」は苦手へ追加します。苦手は3回連続で正解すると復習対象から外れます。")
            }

            Section("この教材について") {
                LabeledContent("状態", value: model.contentStatusText)
                LabeledContent("最新確認試験", value: "第109回")
                LabeledContent("独自問題", value: model.productionQuestionTargetText)
                LabeledContent("出題基準", value: "令和5年版")
                LabeledContent("利用状態", value: model.isPremium ? "Premium" : "無料版・\(model.freeQuestionCount)問")
                if !model.isPremium {
                    Button("Premiumを見る") { model.presentPaywall() }
                }
                Text("問題・解説は一次・権威資料を確認した独自教材です。厚生労働省等の公式アプリではありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("学習記録リセット") {
                Button("回答履歴と苦手をリセット", role: .destructive) {
                    isResetConfirmationPresented = true
                }
            }
        }
        .navigationTitle("設定")
    }

    private var dynamicTypeRange: ClosedRange<DynamicTypeSize> {
        switch model.textSizeStep {
        case 1: return .xLarge ... .accessibility5
        case 2: return .xxLarge ... .accessibility5
        default: return .large ... .accessibility5
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            try model.importBackup(Data(contentsOf: url))
            backupMessage = "復元しました。"
        } catch {
            backupMessage = error.localizedDescription
        }
    }
}

private struct JosanshiBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data = Data()

    init() {}

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
