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
                    Text("今日の学習")
                        .font(Otsu4Theme.sans(13, weight: .bold))
                        .foregroundStyle(Otsu4Theme.ink3)
                    Text(learningStore.todayAnswered >= learningStore.goal ? "今日の目標達成" : "あと\(max(0, learningStore.goal - learningStore.todayAnswered))問")
                        .font(Otsu4Theme.serif(22, weight: .bold))
                        .foregroundStyle(Otsu4Theme.ink)
                    Text("標準は8問。設定で4／8／16問に変更できます。")
                        .font(Otsu4Theme.sans(12))
                        .foregroundStyle(Otsu4Theme.ink2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var primaryActions: some View {
        VStack(spacing: 10) {
            Button(action: startSprint) {
                actionRow(title: "今日のスプリント", subtitle: "\(learningStore.goal)問を短く一周", icon: "bolt.fill", color: Otsu4Theme.ai)
            }
            .buttonStyle(.plain)

            Button(action: startWeak) {
                actionRow(title: "苦手をつぶす", subtitle: learningStore.weakCount == 0 ? "苦手はありません" : "\(learningStore.weakCount)問を3連続正解で解除", icon: "target", color: Otsu4Theme.shu)
            }
            .buttonStyle(.plain)
            .disabled(learningStore.weakCount == 0)
            .opacity(learningStore.weakCount == 0 ? 0.55 : 1)

            Button(action: goMock) {
                actionRow(title: "模擬試験", subtitle: "35問・120分・3回分", icon: "doc.text.fill", color: Otsu4Theme.kin)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Otsu4Theme.sans(16, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink)
                Text(subtitle)
                    .font(Otsu4Theme.sans(12))
                    .foregroundStyle(Otsu4Theme.ink2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Otsu4Theme.ink3)
        }
        .padding(14)
        .background(Otsu4Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Otsu4Theme.line))
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野から解く")
                .font(Otsu4Theme.sans(15, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink)
            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                Button {
                    startSubject(subject)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(subject)
                                .font(Otsu4Theme.sans(15, weight: .bold))
                                .foregroundStyle(Otsu4Theme.ink)
                            Text("\(contentStore.questions(subject: subject, isPremium: purchaseStore.isPremium).count)問利用可能")
                                .font(Otsu4Theme.sans(11))
                                .foregroundStyle(Otsu4Theme.ink3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Otsu4Theme.ai)
                    }
                    .padding(13)
                    .background(Otsu4Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Otsu4Theme.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで")
                .font(Otsu4Theme.sans(15, weight: .bold))
            HStack(spacing: 8) {
                summaryCell(value: "\(learningStore.history.count)", label: "完了")
                summaryCell(value: "\(learningStore.weakCount)", label: "苦手")
                summaryCell(value: purchaseStore.isPremium ? "360" : "72", label: "利用問題")
            }
        }
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Otsu4Theme.serif(23, weight: .bold))
                .foregroundStyle(Otsu4Theme.ai)
            Text(label)
                .font(Otsu4Theme.sans(11, weight: .bold))
                .foregroundStyle(Otsu4Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Otsu4Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private var auditFootnote: some View {
        Text("問題360問・監査日 \(contentStore.bank.lawAuditDate)。公式過去問本文は転載せず、一次資料から独自作問。")
            .font(Otsu4Theme.sans(10))
            .foregroundStyle(Otsu4Theme.ink3)
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
                            .font(Otsu4Theme.serif(32, weight: .bold))
                            .foregroundStyle(Otsu4Theme.ink)
                        Text("各回35問・120分。法令15／物化10／性質消火10。3科目すべて60%以上を目指します。")
                            .font(Otsu4Theme.sans(14))
                            .foregroundStyle(Otsu4Theme.ink2)

                        ForEach(1...3, id: \.self) { set in
                            Button { startMock(set) } label: {
                                Otsu4Card {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("第\(set)回")
                                                .font(Otsu4Theme.serif(22, weight: .bold))
                                                .foregroundStyle(Otsu4Theme.ink)
                                            Text("35問・120分")
                                                .font(Otsu4Theme.sans(12, weight: .semibold))
                                                .foregroundStyle(Otsu4Theme.ink2)
                                        }
                                        Spacer()
                                        if purchaseStore.isPremium {
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(Otsu4Theme.ai)
                                        } else {
                                            Image(systemName: "lock.fill")
                                                .foregroundStyle(Otsu4Theme.kin)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if !purchaseStore.isPremium {
                            Button("プレミアムで模試3回を解放") { showPaywall() }
                                .buttonStyle(.borderedProminent)
                                .tint(Otsu4Theme.ai)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 18)
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

    private var allCorrect: Int { learningStore.history.reduce(0) { $0 + $1.correct } }
    private var allTotal: Int { learningStore.history.reduce(0) { $0 + $1.total } }
    private var achievement: Double { allTotal == 0 ? 0 : Double(allCorrect) / Double(allTotal) }

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("学習記録")
                            .font(Otsu4Theme.serif(32, weight: .bold))
                        Otsu4Card {
                            HStack(spacing: 18) {
                                ZStack {
                                    Circle().stroke(Otsu4Theme.line, lineWidth: 10)
                                    Circle()
                                        .trim(from: 0, to: achievement)
                                        .stroke(Otsu4Theme.midori, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    Text("\(Int((achievement * 100).rounded()))%")
                                        .font(Otsu4Theme.serif(20, weight: .bold))
                                }
                                .frame(width: 96, height: 96)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("達成度")
                                        .font(Otsu4Theme.sans(13, weight: .bold))
                                        .foregroundStyle(Otsu4Theme.ink3)
                                    Text("\(allCorrect) / \(allTotal)")
                                        .font(Otsu4Theme.serif(24, weight: .bold))
                                    Text("累計解答の正答率")
                                        .font(Otsu4Theme.sans(11))
                                        .foregroundStyle(Otsu4Theme.ink2)
                                }
                            }
                        }

                        subjectBars
                        heatmap
                        weakList
                    }
                    .padding(18)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var subjectBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野別")
                .font(Otsu4Theme.sans(15, weight: .bold))
            ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                let rates = learningStore.history.compactMap { $0.subjectRates[subject] }
                let rate = rates.isEmpty ? 0 : rates.reduce(0, +) / rates.count
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(subject).font(Otsu4Theme.sans(13, weight: .semibold))
                        Spacer()
                        Text("\(rate)%").font(Otsu4Theme.sans(12, weight: .bold))
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Otsu4Theme.line)
                            Capsule().fill(Otsu4Theme.ai).frame(width: proxy.size.width * CGFloat(rate) / 100)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(16)
        .background(Otsu4Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("5週間")
                .font(Otsu4Theme.sans(15, weight: .bold))
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 5), count: 7), spacing: 5) {
                ForEach((0..<35).reversed(), id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                    let count = learningStore.history.filter { calendar.isDate($0.finishedAt, inSameDayAs: day) }.count
                    RoundedRectangle(cornerRadius: 4)
                        .fill(count == 0 ? Otsu4Theme.line : Otsu4Theme.midori.opacity(min(1, 0.35 + Double(count) * 0.18)))
                        .frame(width: 18, height: 18)
                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)) \(count)回")
                }
            }
        }
        .padding(16)
        .background(Otsu4Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weakList: some View {
        let weak = learningStore.weakQuestions(from: contentStore, isPremium: purchaseStore.isPremium)
        return VStack(alignment: .leading, spacing: 9) {
            Text("苦手")
                .font(Otsu4Theme.sans(15, weight: .bold))
            if weak.isEmpty {
                Text("苦手問題はありません。")
                    .font(Otsu4Theme.sans(13))
                    .foregroundStyle(Otsu4Theme.ink3)
            } else {
                ForEach(weak.prefix(8)) { q in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(q.topic).font(Otsu4Theme.sans(12, weight: .bold))
                        Text(q.point).font(Otsu4Theme.serif(14)).lineLimit(2)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(16)
        .background(Otsu4Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct Otsu4SettingsView: View {
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    @ObservedObject var learningStore: Otsu4LearningStore
    let showPaywall: () -> Void
    @State private var examDateEnabled = false
    @State private var localExamDate = Date()
    @State private var exporting = false
    @State private var exportDocument = Otsu4BackupDocument()
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                Form {
                    Section("学習") {
                        Picker("1日の目標", selection: Binding(get: { learningStore.goal }, set: learningStore.setGoal)) {
                            Text("4問").tag(4)
                            Text("8問").tag(8)
                            Text("16問").tag(16)
                        }
                        Picker("文字サイズ", selection: Binding(get: { learningStore.fontScale }, set: learningStore.setFontScale)) {
                            Text("小").tag(0)
                            Text("標準").tag(1)
                            Text("大").tag(2)
                        }
                    }

                    Section("試験日") {
                        Toggle("試験日を設定", isOn: $examDateEnabled)
                            .onChange(of: examDateEnabled) { _, enabled in
                                learningStore.setExamDate(enabled ? localExamDate : nil)
                            }
                        if examDateEnabled {
                            DatePicker("日付", selection: $localExamDate, displayedComponents: .date)
                                .onChange(of: localExamDate) { _, date in
                                    learningStore.setExamDate(date)
                                }
                        }
                    }

                    Section("プレミアム") {
                        if purchaseStore.isPremium {
                            Label("購入済み・360問利用可能", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Otsu4Theme.midori)
                        } else {
                            Button("360問・模試3回を解放") { showPaywall() }
                        }
                        Button("購入を復元") {
                            Task { await purchaseStore.restorePurchases() }
                        }
                    }

                    Section("学習データ") {
                        Button("JSONを書き出す") {
                            do {
                                exportDocument = Otsu4BackupDocument(data: try learningStore.exportData())
                                exporting = true
                            } catch {
                                importError = "書き出しに失敗しました。"
                            }
                        }
                        Button("JSONを読み込む") { importing = true }
                        Button("学習履歴をリセット", role: .destructive) { learningStore.resetLearningData() }
                    }

                    Section("このアプリ") {
                        Text("危険物取扱者 乙種4類｜学びスプリント")
                        Text("端末内保存を基本とし、課金状態はApp Storeの取引情報から検証します。")
                            .font(.footnote)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
        }
        .onAppear {
            examDateEnabled = learningStore.examDate != nil
            localExamDate = learningStore.examDate ?? Date()
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "otsu4-learning-backup"
        ) { result in
            if case .failure = result { importError = "書き出しに失敗しました。" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                try learningStore.importData(Data(contentsOf: url))
            } catch {
                importError = "バックアップを読み込めませんでした。"
            }
        }
        .alert("学習データ", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }
}

struct Otsu4StudyFlowView: View {
    @ObservedObject var session: Otsu4StudySession
    @ObservedObject var learningStore: Otsu4LearningStore
    let close: () -> Void
    @State private var recorded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Otsu4PaperBackground()
                Group {
                    if session.isFinished { resultView } else { questionView }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ホーム", action: close)
                        .foregroundStyle(Otsu4Theme.ai)
                }
                ToolbarItem(placement: .principal) {
                    Text(session.kind.title)
                        .font(Otsu4Theme.sans(14, weight: .bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(session.progressText)
                        .font(Otsu4Theme.sans(13, weight: .bold).monospacedDigit())
                }
            }
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished && !recorded {
                learningStore.complete(session: session)
                recorded = true
            }
        }
    }

    private var questionView: some View {
        let q = session.currentQuestion
        let answer = session.currentAnswer
        return ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                ProgressView(value: Double(session.index + 1), total: Double(session.questions.count))
                    .tint(Otsu4Theme.ai)

                Text("\(q.subject) ・ \(q.topic)")
                    .font(Otsu4Theme.sans(11, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink3)

                ZStack {
                    Text(q.question)
                        .font(Otsu4Theme.serif(21, weight: .semibold))
                        .foregroundStyle(Otsu4Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(17)
                        .background(Otsu4Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Otsu4Theme.line))
                    if !session.kind.isMock, let answer {
                        Otsu4MarkOverlay(correct: answer.correct)
                    }
                }

                VStack(spacing: 9) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            session.choose(index)
                            learningStore.saveResume(session: session)
                        } label: {
                            HStack(alignment: .top, spacing: 11) {
                                Text("\(index + 1)")
                                    .font(Otsu4Theme.sans(13, weight: .bold))
                                    .foregroundStyle(Otsu4Theme.ink)
                                    .frame(width: 28, height: 28)
                                    .background(choiceNumberBackground(index, question: q, answer: answer), in: Circle())
                                Text(choice)
                                    .font(Otsu4Theme.sans(15, weight: .medium))
                                    .foregroundStyle(Otsu4Theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(13)
                            .background(choiceCardBackground(index, question: q, answer: answer))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Otsu4Theme.line))
                        }
                        .buttonStyle(.plain)
                        .disabled(!session.kind.isMock && answer != nil)
                    }
                }

                if !session.kind.isMock, answer == nil {
                    Button("わからない") {
                        session.choose(nil)
                        learningStore.saveResume(session: session)
                    }
                    .buttonStyle(.bordered)
                    .tint(Otsu4Theme.ink2)
                    .frame(maxWidth: .infinity)
                }

                if !session.kind.isMock, let answer {
                    feedback(question: q, answer: answer)
                    Button(session.isLast ? "結果を見る" : "次の問題へ") {
                        session.next()
                        if !session.isFinished { learningStore.saveResume(session: session) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Otsu4Theme.ai)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }

                if session.kind.isMock {
                    HStack(spacing: 10) {
                        Button("前の問題") {
                            session.previous()
                            learningStore.saveResume(session: session)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!session.canGoBack)
                        Button(session.isLast ? "採点する" : "次の問題") {
                            session.next()
                            if !session.isFinished { learningStore.saveResume(session: session) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Otsu4Theme.ai)
                    }
                    Text("模試では解答中に正誤を表示しません。未回答は不正解として採点します。")
                        .font(Otsu4Theme.sans(11))
                        .foregroundStyle(Otsu4Theme.ink3)
                }
            }
            .padding(18)
            .padding(.bottom, 22)
        }
    }

    @ViewBuilder
    private func feedback(question: Otsu4Question, answer: Otsu4AnswerState) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: answer.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(answer.correct ? "正解" : answer.unknown ? "わからない" : "不正解")
            }
            .font(Otsu4Theme.sans(14, weight: .bold))
            .foregroundStyle(answer.correct ? Otsu4Theme.midori : Otsu4Theme.shu)

            Otsu4MemoryBlock(text: question.point)

            DisclosureGroup("詳しい解説") {
                Text(question.detail)
                    .font(Otsu4Theme.sans(14))
                    .foregroundStyle(Otsu4Theme.ink2)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(Otsu4Theme.ai)
        }
        .padding(15)
        .background(answer.correct ? Otsu4Theme.midoriSoft : Otsu4Theme.shuSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(session.kind.isMock ? "模擬試験 結果" : "スプリント完了")
                    .font(Otsu4Theme.sans(12, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink3)
                Text("\(session.correctCount) / \(session.questions.count)")
                    .font(Otsu4Theme.serif(52, weight: .bold))
                    .foregroundStyle(Otsu4Theme.ink)
                Text("正答率 \(session.scoreRate)%")
                    .font(Otsu4Theme.serif(21, weight: .semibold))
                    .foregroundStyle(Otsu4Theme.ai)

                if session.kind.isMock {
                    VStack(spacing: 9) {
                        ForEach(["法令", "物理・化学", "性質・消火"], id: \.self) { subject in
                            if let r = session.subjectResults[subject] {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subject).font(Otsu4Theme.sans(14, weight: .bold))
                                        Text("\(r.correct) / \(r.total)・\(r.rate)%")
                                            .font(Otsu4Theme.sans(11))
                                            .foregroundStyle(Otsu4Theme.ink3)
                                    }
                                    Spacer()
                                    Text(r.rate >= 60 ? "基準到達" : "60%未満")
                                        .font(Otsu4Theme.sans(12, weight: .bold))
                                        .foregroundStyle(r.rate >= 60 ? Otsu4Theme.midori : Otsu4Theme.shu)
                                }
                                .padding(13)
                                .background(Otsu4Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                            }
                        }
                    }
                    Text(session.mockPassEstimate ? "3科目とも60%以上です。" : "60%未満の科目を優先して復習してください。")
                        .font(Otsu4Theme.serif(17, weight: .semibold))
                        .foregroundStyle(Otsu4Theme.ink)
                }

                Button("ホームへ") { close() }
                    .buttonStyle(.borderedProminent)
                    .tint(Otsu4Theme.ai)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func choiceCardBackground(_ index: Int, question: Otsu4Question, answer: Otsu4AnswerState?) -> Color {
        guard let answer else { return Otsu4Theme.card }
        if session.kind.isMock {
            return answer.selectedIndex == index ? Otsu4Theme.aiSoft : Otsu4Theme.card
        }
        if index == question.answer { return Otsu4Theme.midoriSoft }
        if answer.selectedIndex == index { return Otsu4Theme.shuSoft }
        return Otsu4Theme.card
    }

    private func choiceNumberBackground(_ index: Int, question: Otsu4Question, answer: Otsu4AnswerState?) -> Color {
        guard let answer else { return Otsu4Theme.line }
        if session.kind.isMock {
            return answer.selectedIndex == index ? Otsu4Theme.aiSoft : Otsu4Theme.line
        }
        if index == question.answer { return Otsu4Theme.midori.opacity(0.18) }
        if answer.selectedIndex == index { return Otsu4Theme.shu.opacity(0.18) }
        return Otsu4Theme.line
    }
}
