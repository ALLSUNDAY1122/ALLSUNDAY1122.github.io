import SwiftUI
import UniformTypeIdentifiers

private enum Otsu4Tab: Hashable {
    case home, mock, history, settings
}

struct Otsu4NativeRootView: View {
    @StateObject private var purchaseStore = Otsu4PurchaseStore()
    @StateObject private var learningStore = Otsu4LearningStore()
    @State private var contentStore: Otsu4ContentStore?
    @State private var loadError: String?
    @State private var activeSession: Otsu4StudySession?
    @State private var showingPaywall = false
    @State private var selectedTab: Otsu4Tab = .home

    var body: some View {
        Group {
            if let contentStore {
                TabView(selection: $selectedTab) {
                    Otsu4HomeView(
                        contentStore: contentStore,
                        purchaseStore: purchaseStore,
                        learningStore: learningStore,
                        startSprint: { start(.sprint(learningStore.goal), from: contentStore) },
                        startWeak: { start(.weak, from: contentStore) },
                        resume: { resume(from: contentStore) },
                        goMock: { selectedTab = .mock },
                        startSubject: { start(.subject($0), from: contentStore) }
                    )
                    .tag(Otsu4Tab.home)
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
                    .tag(Otsu4Tab.mock)
                    .tabItem { Label("模試", systemImage: "doc.text") }

                    Otsu4HistoryView(
                        contentStore: contentStore,
                        purchaseStore: purchaseStore,
                        learningStore: learningStore
                    )
                    .tag(Otsu4Tab.history)
                    .tabItem { Label("記録", systemImage: "chart.bar") }

                    Otsu4SettingsView(
                        purchaseStore: purchaseStore,
                        learningStore: learningStore,
                        showPaywall: { showingPaywall = true }
                    )
                    .tag(Otsu4Tab.settings)
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
                loadError = "questions.generated.json をCopy Bundle Resourcesへ追加してください。"
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
            questions = Array(learningStore.weakQuestions(from: store, isPremium: purchaseStore.isPremium).shuffled().prefix(learningStore.goal))
        case .subject(let subject):
            questions = Array(store.questions(subject: subject, isPremium: purchaseStore.isPremium).shuffled().prefix(learningStore.goal))
        case .mock(let set):
            questions = store.mockExamQuestions(set: set) ?? []
        }
        guard !questions.isEmpty else { return }
        learningStore.clearResume()
        activeSession = Otsu4StudySession(kind: kind, questions: questions)
    }
}

struct Otsu4HomeView: View {
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("試験まで")
                    .font(Otsu4Theme.sans(12, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink3)
                Text("\(days)日")
                    .font(Otsu4Theme.serif(32, weight: .bold))
                    .foregroundStyle(Otsu4Theme.shu)
            }
            Spacer()
            Text(days == 0 ? "今日が試験日です" : "1日\(learningStore.goal)問のペースを維持")
                .font(Otsu4Theme.sans(12, weight: .semibold))
                .foregroundStyle(Otsu4Theme.ink2)
        }
        .padding(14)
        .background(Otsu4Theme.shuSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        VStack(alignment: .leading, spacing: 10) {
            Text("科目別")
                .font(Otsu4Theme.serif(20, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                Button {
                    startSubject(subject)
                } label: {
                    HStack {
                        Text(subject)
                            .font(Otsu4Theme.sans(15, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Otsu4Theme.ai)
                .accessibilityLabel("\(subject)を学習")
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 10) {
            summaryChip(title: "学習済み", value: "\(learningStore.seenCount)問", color: Otsu4Theme.ai)
            summaryChip(title: "苦手", value: "\(learningStore.weakCount)問", color: Otsu4Theme.shu)
            summaryChip(title: "全問題", value: purchaseStore.isPremium ? "360問" : "72問", color: Otsu4Theme.midori)
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

struct Otsu4MockListView: View {
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    let startMock: (Int) -> Void
    let showPaywall: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("模擬試験")
                            .font(Otsu4Theme.serif(30, weight: .bold))
                            .foregroundStyle(Otsu4Theme.ink)
                        Text("各35問・120分。3科目すべて60%以上で合格判定。解答中は正誤を表示しません。")
                            .font(Otsu4Theme.sans(14))
                            .foregroundStyle(Otsu4Theme.ink2)

                        ForEach(1...3, id: \.self) { set in
                            Otsu4Card {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("第\(set)回 模擬試験")
                                            .font(Otsu4Theme.serif(19, weight: .bold))
                                            .foregroundStyle(Otsu4Theme.ink)
                                        Text("法令15 ／ 物化10 ／ 性消10")
                                            .font(Otsu4Theme.sans(12))
                                            .foregroundStyle(Otsu4Theme.ink2)
                                    }
                                    Spacer()
                                    if purchaseStore.isPremium {
                                        Button("開始") { startMock(set) }
                                            .buttonStyle(.borderedProminent)
                                            .tint(Otsu4Theme.ai)
                                    } else {
                                        Button(action: showPaywall) {
                                            Label("解放", systemImage: "lock.fill")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Otsu4Theme.kin)
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct Otsu4HistoryView: View {
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

                        Otsu4Card {
                            HStack {
                                metric("学習済み", "\(learningStore.seenCount)問")
                                metric("正答", "\(learningStore.totalCorrect)問")
                                metric("苦手", "\(learningStore.weakCount)問")
                            }
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("5週間")
                                .font(Otsu4Theme.serif(19, weight: .bold))
                            heatmap
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("科目別")
                                .font(Otsu4Theme.serif(19, weight: .bold))
                            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                                let total = contentStore.allQuestions.filter { $0.subject == subject }.count
                                let seen = learningStore.seenIDs.intersection(Set(contentStore.allQuestions.filter { $0.subject == subject }.map(\.id))).count
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
                        }

                        if !purchaseStore.isPremium {
                            Text("無料版は72問まで。Premiumでは360問すべての進捗を記録します。")
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

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Otsu4Theme.serif(20, weight: .bold))
                .foregroundStyle(Otsu4Theme.ai)
            Text(title)
                .font(Otsu4Theme.sans(11))
                .foregroundStyle(Otsu4Theme.ink3)
        }
        .frame(maxWidth: .infinity)
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
                    .accessibilityLabel("\(35 - index)日前 \(count)問")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func heatColor(_ count: Int) -> Color {
        switch count {
        case 0: return Otsu4Theme.line
        case 1...3: return Otsu4Theme.midori.opacity(0.35)
        case 4...7: return Otsu4Theme.midori.opacity(0.65)
        default: return Otsu4Theme.midori
        }
    }
}

struct Otsu4SettingsView: View {
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore
    let showPaywall: () -> Void
    @State private var exportDocument: Otsu4BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("1日の目標") {
                    Picker("問題数", selection: Binding(
                        get: { learningStore.goal },
                        set: { learningStore.setGoal($0) }
                    )) {
                        Text("4問").tag(4)
                        Text("8問").tag(8)
                        Text("16問").tag(16)
                    }
                    .pickerStyle(.segmented)
                }

                Section("文字サイズ") {
                    Picker("表示", selection: Binding(
                        get: { learningStore.fontScale },
                        set: { learningStore.setFontScale($0) }
                    )) {
                        Text("小").tag(0)
                        Text("標準").tag(1)
                        Text("大").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("試験日") {
                    DatePicker(
                        "日付",
                        selection: Binding(
                            get: { learningStore.examDate ?? Date() },
                            set: { learningStore.setExamDate($0) }
                        ),
                        displayedComponents: .date
                    )
                    if let days = learningStore.examDaysRemaining {
                        Text("あと\(days)日 ／ 必要ペース \(learningStore.requiredDailyPace(totalQuestions: 360))問/日")
                    }
                }

                Section("バックアップ") {
                    Button("JSONを書き出す") {
                        do {
                            exportDocument = Otsu4BackupDocument(data: try learningStore.exportData())
                            showingExporter = true
                        } catch {
                            importMessage = "書き出しデータを作成できませんでした"
                        }
                    }
                    Button("JSONを読み込む") {
                        showingImporter = true
                    }
                    if let importMessage {
                        Text(importMessage)
                            .font(.footnote)
                            .foregroundStyle(Otsu4Theme.ink2)
                    }
                }

                Section("Premium") {
                    if purchaseStore.isPremium {
                        Label("360問・模試3回 解放済み", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Otsu4Theme.midori)
                    } else {
                        Button("360問・模試3回を解放", action: showPaywall)
                    }
                    Button("購入を復元") {
                        Task { await purchaseStore.restorePurchases() }
                    }
                    Text("価格はApp Storeの商品情報を取得して表示します。")
                        .font(.footnote)
                        .foregroundStyle(Otsu4Theme.ink3)
                }

                Section("コンテンツ") {
                    Text("問題は端末内に保存され、通常の学習はオフラインで利用できます。")
                    Text("法令・問題の更新時はcontentVersionと監査日を更新します。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Otsu4Theme.paper)
            .navigationTitle("設定")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "otsu4-backup"
        ) { _ in
            exportDocument = nil
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try learningStore.importData(Data(contentsOf: url))
                importMessage = "バックアップを復元しました"
            } catch {
                importMessage = "バックアップを読み込めませんでした"
            }
        }
    }
}

struct Otsu4StudyFlowView: View {
    @ObservedObject var session: Otsu4StudySession
    @ObservedObject var learningStore: Otsu4LearningStore
    let onClose: () -> Void
    @State private var completedStored = false
    @State private var now = Date()

    var body: some View {
        ZStack {
            Otsu4PaperBackground()
            if session.isFinished {
                Otsu4ResultView(session: session, learningStore: learningStore, onClose: onClose)
                    .onAppear { storeCompletionIfNeeded() }
            } else {
                Otsu4QuestionView(session: session, now: now, onClose: onClose)
            }
        }
        .onChange(of: session.isFinished) { _, value in
            if value { storeCompletionIfNeeded() }
        }
        .task(id: session.isMock && !session.isFinished) {
            guard session.isMock else { return }
            while !Task.isCancelled && !session.isFinished {
                now = Date()
                if session.remainingSeconds(at: now) == 0 {
                    session.finishBecauseTimeExpired()
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func storeCompletionIfNeeded() {
        guard !completedStored else { return }
        completedStored = true
        learningStore.complete(session: session)
    }
}

struct Otsu4QuestionView: View {
    @ObservedObject var session: Otsu4StudySession
    let now: Date
    let onClose: () -> Void

    private var question: Otsu4Question { session.currentQuestion }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(question.subject)
                        .font(Otsu4Theme.sans(12, weight: .bold))
                        .foregroundStyle(Otsu4Theme.shu)
                    Text(question.question)
                        .font(Otsu4Theme.serif(22, weight: .semibold))
                        .foregroundStyle(Otsu4Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("問題。\(question.question)")

                    VStack(spacing: 9) {
                        ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                            Button {
                                session.choose(index)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text(String(UnicodeScalar(65 + index)!))
                                        .font(Otsu4Theme.sans(13, weight: .bold))
                                        .frame(width: 27, height: 27)
                                        .background(choiceCircleColor(index))
                                        .clipShape(Circle())
                                    Text(choice)
                                        .font(Otsu4Theme.sans(15, weight: .medium))
                                        .foregroundStyle(Otsu4Theme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .background(choiceBackground(index))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(choiceBorder(index), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!session.isMock && session.hasAnsweredCurrent)
                            .accessibilityLabel("選択肢 \(index + 1)。\(choice)")
                        }
                    }

                    Button {
                        session.choose(nil)
                    } label: {
                        Text("わからない")
                            .font(Otsu4Theme.sans(14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                    .tint(Otsu4Theme.ink2)
                    .disabled(!session.isMock && session.hasAnsweredCurrent)

                    if !session.isMock, session.hasAnsweredCurrent {
                        feedback
                    }

                    navigationButtons
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .overlay {
            if !session.isMock, session.hasAnsweredCurrent {
                Otsu4MarkOverlay(correct: session.currentAnswerState?.isCorrect == true)
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("学習を閉じる")
                Spacer()
                if session.isMock {
                    Text(session.timerText(at: now))
                        .font(Otsu4Theme.sans(16, weight: .bold).monospacedDigit())
                        .foregroundStyle(session.remainingSeconds(at: now) < 600 ? Otsu4Theme.shu : Otsu4Theme.ink)
                } else {
                    Text("\(session.currentNumber) / \(session.total)")
                        .font(Otsu4Theme.sans(13, weight: .bold))
                        .foregroundStyle(Otsu4Theme.ink2)
                }
            }
            ProgressView(value: Double(session.currentNumber), total: Double(session.total))
                .tint(Otsu4Theme.shu)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .background(Otsu4Theme.card.opacity(0.94))
    }

    @ViewBuilder
    private var feedback: some View {
        if let state = session.currentAnswerState {
            VStack(alignment: .leading, spacing: 12) {
                Text(state.selected == nil ? "わからない" : (state.isCorrect ? "正解" : "不正解"))
                    .font(Otsu4Theme.serif(22, weight: .bold))
                    .foregroundStyle(state.isCorrect ? Otsu4Theme.midori : Otsu4Theme.shu)
                Otsu4MemoryBlock(text: question.point)
                Text(question.detail)
                    .font(Otsu4Theme.sans(14))
                    .foregroundStyle(Otsu4Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: question.sourceURL)!) {
                    Label(question.sourceTitle, systemImage: "doc.text.magnifyingglass")
                        .font(Otsu4Theme.sans(12, weight: .semibold))
                }
                .tint(Otsu4Theme.ai)
            }
            .padding(.top, 4)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 10) {
            if session.isMock && session.index > 0 {
                Button("前へ", action: session.previous)
                    .buttonStyle(.bordered)
            }
            Spacer()
            if session.isMock {
                Button(session.index == session.questions.count - 1 ? "採点する" : "次へ") {
                    session.next()
                }
                .buttonStyle(.borderedProminent)
                .tint(Otsu4Theme.ai)
            } else if session.hasAnsweredCurrent {
                Button(session.index == session.questions.count - 1 ? "結果を見る" : "次の問題へ") {
                    session.next()
                }
                .buttonStyle(.borderedProminent)
                .tint(Otsu4Theme.shu)
            }
        }
        .padding(.top, 2)
    }

    private func choiceBackground(_ index: Int) -> Color {
        guard !session.isMock, let state = session.currentAnswerState else {
            return Otsu4Theme.card
        }
        if index == question.answer { return Otsu4Theme.midoriSoft }
        if state.selected == index && !state.isCorrect { return Otsu4Theme.shuSoft }
        return Otsu4Theme.card
    }

    private func choiceBorder(_ index: Int) -> Color {
        guard !session.isMock, let state = session.currentAnswerState else {
            return Otsu4Theme.line
        }
        if index == question.answer { return Otsu4Theme.midori }
        if state.selected == index && !state.isCorrect { return Otsu4Theme.shu }
        return Otsu4Theme.line
    }

    private func choiceCircleColor(_ index: Int) -> Color {
        guard !session.isMock, let state = session.currentAnswerState else {
            return Otsu4Theme.aiSoft
        }
        if index == question.answer { return Otsu4Theme.midoriSoft }
        if state.selected == index && !state.isCorrect { return Otsu4Theme.shuSoft }
        return Otsu4Theme.aiSoft
    }
}

struct Otsu4ResultView: View {
    @ObservedObject var session: Otsu4StudySession
    @ObservedObject var learningStore: Otsu4LearningStore
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(session.mockPassEstimate ? "合格圏" : "結果")
                    .font(Otsu4Theme.serif(34, weight: .bold))
                    .foregroundStyle(session.isMock ? (session.mockPassEstimate ? Otsu4Theme.midori : Otsu4Theme.shu) : Otsu4Theme.ink)
                Text("\(session.correctCount) / \(session.total)問 正解")
                    .font(Otsu4Theme.serif(24, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink)
                Text("正答率 \(session.correctRate)% ／ わからない \(session.unknownCount)問")
                    .font(Otsu4Theme.sans(14))
                    .foregroundStyle(Otsu4Theme.ink2)

                if session.isMock {
                    VStack(spacing: 8) {
                        ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                            if let result = session.subjectResults[subject] {
                                HStack {
                                    Text(subject)
                                    Spacer()
                                    Text("\(result.correct)/\(result.total)  \(result.rate)%")
                                        .monospacedDigit()
                                    Text(result.passed ? "PASS" : "未達")
                                        .fontWeight(.bold)
                                        .foregroundStyle(result.passed ? Otsu4Theme.midori : Otsu4Theme.shu)
                                }
                                .font(Otsu4Theme.sans(13))
                            }
                        }
                    }
                    .padding(14)
                    .background(Otsu4Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Otsu4MemoryBlock(text: session.correctRate >= 80 ? "よく定着しています。苦手だけ短く再確認。" : "誤答と「わからない」を3回正解するまで回す。")

                Button("ホームへ", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(Otsu4Theme.shu)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }
}

struct Otsu4BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
