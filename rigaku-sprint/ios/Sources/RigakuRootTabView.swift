import SwiftUI
import UniformTypeIdentifiers
import LearningSprintCore

private enum RigakuRootTab: Hashable {
    case home, mock, history, settings
}

private enum RigakuStudyRoute: Hashable {
    case sprint
    case weak
    case subject(String)
    case mock(String)
    case resume
}

struct RigakuRootTabView: View {
    @StateObject private var model = RigakuAppModel()
    @State private var selection: RigakuRootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            RigakuHomeScreen(model: model, selection: $selection)
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(RigakuRootTab.home)

            RigakuMockScreen(model: model)
                .tabItem { Label("模試", systemImage: "doc.text") }
                .tag(RigakuRootTab.mock)

            RigakuHistoryScreen(model: model)
                .tabItem { Label("記録", systemImage: "chart.bar") }
                .tag(RigakuRootTab.history)

            RigakuSettingsScreen(model: model)
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(RigakuRootTab.settings)
        }
        .tint(LearningSprintTheme.indigo)
    }
}

private struct RigakuHomeScreen: View {
    @ObservedObject var model: RigakuAppModel
    @Binding var selection: RigakuRootTab

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        brandHeader
                        if model.state.examDate != nil { examCountdown }
                        todayCard
                        if model.state.resumeSession != nil { resumeCard }
                        sprintCard
                        weakCard
                        mockCard
                        subjectSection
                        historySummary
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationDestination(for: RigakuStudyRoute.self) { route in
                routeDestination(route)
            }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("学びスプリント")
                .font(LearningSprintTheme.sans(12, weight: .bold))
                .foregroundStyle(LearningSprintTheme.vermilion)
                .tracking(1.2)
            Text("理学療法士国家試験")
                .font(LearningSprintTheme.serif(30, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
            Text("今日も1問、力に変える。")
                .font(LearningSprintTheme.serif(16))
                .foregroundStyle(LearningSprintTheme.ink2)
        }
    }

    private var examCountdown: some View {
        let days = daysUntilExam
        return HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("試験まで")
                .font(LearningSprintTheme.sans(12, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink2)
            Text(days.map(String.init) ?? "—")
                .font(LearningSprintTheme.serif(28, weight: .bold))
                .foregroundStyle(LearningSprintTheme.vermilion)
            Text("日")
                .font(LearningSprintTheme.sans(13, weight: .bold))
            Spacer()
            if let pace = model.requiredDailyPace {
                Text("必要ペース \(pace)問/日")
                    .font(LearningSprintTheme.sans(12, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.indigo)
            }
        }
        .padding(14)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var todayCard: some View {
        HStack(spacing: 18) {
            LearningSprintProgressRing(
                progress: model.dailyProgress,
                label: "\(model.todayAnsweredCount)/\(model.state.dailyTarget)"
            )
            VStack(alignment: .leading, spacing: 5) {
                Text("今日の学習")
                    .font(LearningSprintTheme.serif(20, weight: .bold))
                Text(model.todayAnsweredCount >= model.state.dailyTarget
                     ? "今日の目標を達成しました。"
                     : "あと\(max(0, model.state.dailyTarget - model.todayAnsweredCount))問")
                    .font(LearningSprintTheme.sans(13, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink2)
            }
            Spacer()
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
    }

    private var resumeCard: some View {
        NavigationLink(value: RigakuStudyRoute.resume) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("続きから再開")
                        .font(LearningSprintTheme.sans(15, weight: .bold))
                    if let snapshot = model.state.resumeSession {
                        Text("\(min(snapshot.currentIndex + 1, snapshot.questionIDs.count)) / \(snapshot.questionIDs.count)問")
                            .font(LearningSprintTheme.sans(12))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
            }
            .padding(15)
            .foregroundStyle(LearningSprintTheme.indigo)
            .background(LearningSprintTheme.indigoSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.resumeQuestions().isEmpty)
    }

    private var sprintCard: some View {
        StudyActionCard(
            title: "今日のスプリント",
            subtitle: "\(model.state.dailyTarget)問だけ集中",
            systemImage: "bolt.fill",
            accent: LearningSprintTheme.indigo,
            disabled: model.questions.isEmpty,
            destination: .sprint
        )
    }

    private var weakCard: some View {
        StudyActionCard(
            title: "苦手をつぶす",
            subtitle: model.weakCount == 0 ? "苦手登録はありません" : "\(model.weakCount)問を復習",
            systemImage: "target",
            accent: LearningSprintTheme.vermilion,
            disabled: model.weakCount == 0,
            destination: .weak
        )
    }

    private var mockCard: some View {
        Button {
            selection = .mock
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(LearningSprintTheme.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("模擬試験")
                        .font(LearningSprintTheme.serif(18, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text("公式配点・採点除外を再現")
                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(16)
            .background(LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野から解く")
                .font(LearningSprintTheme.serif(20, weight: .bold))
            ForEach(RigakuAppConfiguration.generalSubjects, id: \.self) { subject in
                let count = model.questions.filter { $0.subject == subject }.count
                NavigationLink(value: RigakuStudyRoute.subject(subject)) {
                    HStack {
                        Text(subject)
                            .font(LearningSprintTheme.sans(14, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink)
                        Spacer()
                        Text("\(count)問")
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }
                    .padding(14)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .opacity(count == 0 ? 0.52 : 1)
            }
        }
    }

    private var historySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで")
                .font(LearningSprintTheme.serif(20, weight: .bold))
            HStack(spacing: 8) {
                MetricChip(label: "解答", value: "\(model.state.attempts.count)")
                MetricChip(label: "正答率", value: model.accuracy.map { "\(Int($0 * 100))%" } ?? "—")
                MetricChip(label: "苦手", value: "\(model.weakCount)")
            }
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: RigakuStudyRoute) -> some View {
        switch route {
        case .sprint:
            let qs = model.questions(for: .sprint)
            RigakuStudySessionView(model: model, kind: .sprint, questions: qs)
        case .weak:
            let qs = model.questions(for: .weak)
            RigakuStudySessionView(model: model, kind: .weak, questions: qs)
        case .subject(let subject):
            let kind = SessionKind.subject(subject)
            let qs = model.questions(for: kind)
            RigakuStudySessionView(model: model, kind: kind, questions: qs)
        case .mock(let round):
            let kind = SessionKind.mock(round)
            RigakuStudySessionView(model: model, kind: kind, questions: model.completeMockQuestions(round: round))
        case .resume:
            if let snapshot = model.state.resumeSession {
                RigakuStudySessionView(
                    model: model,
                    kind: snapshot.kind,
                    questions: model.resumeQuestions(),
                    resumeIndex: snapshot.currentIndex
                )
            } else {
                RigakuEmptyMessage(title: "再開データはありません", message: "新しいスプリントを開始してください。")
            }
        }
    }

    private var daysUntilExam: Int? {
        guard let examDate = model.state.examDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: examDate)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}

private struct RigakuMockScreen: View {
    @ObservedObject var model: RigakuAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("模擬試験")
                            .font(LearningSprintTheme.serif(28, weight: .bold))
                        Text("公式の採点除外・実地3点・一般1点を反映します。200問すべての内容監査が終わった回だけ開始できます。")
                            .font(LearningSprintTheme.sans(13))
                            .foregroundStyle(LearningSprintTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(["60", "59", "58"], id: \.self) { round in
                            let loaded = model.loadedMockQuestionCount(round: round)
                            let available = model.isMockAvailable(round: round)
                            NavigationLink(value: RigakuStudyRoute.mock(round)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("第\(round)回ベース")
                                            .font(LearningSprintTheme.serif(19, weight: .bold))
                                        Spacer()
                                        Text(available ? "開始できます" : "監査中")
                                            .font(LearningSprintTheme.sans(11, weight: .bold))
                                            .foregroundStyle(available ? LearningSprintTheme.green : LearningSprintTheme.vermilion)
                                    }
                                    ProgressView(value: Double(loaded), total: 200)
                                        .tint(LearningSprintTheme.indigo)
                                    Text("監査済み \(loaded) / 200問")
                                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                                        .foregroundStyle(LearningSprintTheme.ink2)
                                }
                                .padding(16)
                                .background(LearningSprintTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!available)
                            .opacity(available ? 1 : 0.68)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationDestination(for: RigakuStudyRoute.self) { route in
                if case .mock(let round) = route {
                    let kind = SessionKind.mock(round)
                    RigakuStudySessionView(model: model, kind: kind, questions: model.completeMockQuestions(round: round))
                }
            }
        }
    }
}

private struct RigakuHistoryScreen: View {
    @ObservedObject var model: RigakuAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("学習記録")
                            .font(LearningSprintTheme.serif(28, weight: .bold))
                        HStack(spacing: 8) {
                            MetricChip(label: "解答", value: "\(model.state.attempts.count)")
                            MetricChip(label: "正答率", value: model.accuracy.map { "\(Int($0 * 100))%" } ?? "—")
                            MetricChip(label: "苦手", value: "\(model.weakCount)")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("直近5週間")
                                .font(LearningSprintTheme.serif(18, weight: .bold))
                            LearningSprintHeatmap(values: model.heatmap)
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("分野別正答率")
                                .font(LearningSprintTheme.serif(18, weight: .bold))
                            ForEach(RigakuAppConfiguration.generalSubjects, id: \.self) { subject in
                                let rate = model.subjectAccuracy[subject]
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(subject)
                                            .font(LearningSprintTheme.sans(13, weight: .bold))
                                        Spacer()
                                        Text(rate.map { "\(Int($0 * 100))%" } ?? "—")
                                            .font(LearningSprintTheme.sans(12, weight: .bold))
                                            .foregroundStyle(LearningSprintTheme.ink2)
                                    }
                                    ProgressView(value: rate ?? 0)
                                        .tint(LearningSprintTheme.green)
                                }
                            }
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(18)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct RigakuSettingsScreen: View {
    @ObservedObject var model: RigakuAppModel
    @State private var useExamDate = false
    @State private var examDate = Date()
    @State private var exportDocument = RigakuBackupDocument()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                Form {
                    Section("1日の目標") {
                        Picker("問題数", selection: Binding(
                            get: { model.state.dailyTarget },
                            set: { model.setDailyTarget($0) }
                        )) {
                            ForEach([4, 8, 16], id: \.self) { Text("\($0)問").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("文字サイズ") {
                        Picker("文字サイズ", selection: Binding(
                            get: { model.state.textSizeStep },
                            set: { model.setTextSizeStep($0) }
                        )) {
                            Text("小").tag(0)
                            Text("標準").tag(1)
                            Text("大").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("試験日") {
                        Toggle("試験日を登録", isOn: $useExamDate)
                            .onChange(of: useExamDate) { enabled in
                                model.setExamDate(enabled ? examDate : nil)
                            }
                        if useExamDate {
                            DatePicker("試験日", selection: $examDate, displayedComponents: .date)
                                .onChange(of: examDate) { model.setExamDate($0) }
                        }
                    }

                    Section("バックアップ") {
                        Button("JSONを書き出す") {
                            do {
                                exportDocument = RigakuBackupDocument(data: try model.exportBackup())
                                showingExporter = true
                            } catch {
                                statusMessage = error.localizedDescription
                            }
                        }
                        Button("JSONを読み込む") {
                            showingImporter = true
                        }
                        Text("学習履歴・苦手・試験日・設定を端末外へ保存できます。別資格のバックアップは読み込みません。")
                            .font(.caption)
                    }

                    Section("製品化ゲート") {
                        LabeledContent("Bundle ID", value: "要確認")
                        LabeledContent("App Store Connect ID", value: "要確認")
                        LabeledContent("IAP Product ID", value: "要確認")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("設定")
        }
        .onAppear {
            if let saved = model.state.examDate {
                examDate = saved
                useExamDate = true
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "rigaku-learning-backup"
        ) { result in
            if case .failure(let error) = result { statusMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try model.importBackup(Data(contentsOf: url))
                statusMessage = "バックアップを読み込みました。"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
        .alert("バックアップ", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }
}

private struct StudyActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let disabled: Bool
    let destination: RigakuStudyRoute

    var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LearningSprintTheme.serif(18, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text(subtitle)
                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(16)
            .background(LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.52 : 1)
    }
}

private struct MetricChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(LearningSprintTheme.serif(20, weight: .bold))
            Text(label)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RigakuEmptyMessage: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            VStack(spacing: 12) {
                Text(title)
                    .font(LearningSprintTheme.serif(20, weight: .bold))
                Text(message)
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}
