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

    public init() {
        _model = StateObject(wrappedValue: JosanshiDashboardModel())
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
        .fullScreenCover(isPresented: $model.isSessionPresented) {
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
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("学びスプリント")
                        .font(LearningSprintTheme.sans(12, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text("助産師国家試験")
                        .font(LearningSprintTheme.serif(28, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text(model.contentStatusText)
                        .font(LearningSprintTheme.sans(13))
                        .foregroundStyle(model.hasReadyContent ? LearningSprintTheme.indigo : LearningSprintTheme.vermilion)
                }

                HStack(spacing: 16) {
                    LearningSprintProgressRing(
                        progress: model.todayProgress,
                        label: "\(model.todayAnsweredCount) / \(model.dailyTarget)"
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日の学習")
                            .font(LearningSprintTheme.serif(20, weight: .semibold))
                        Text("標準8問。4 / 8 / 16問から1日の目標を選べます。")
                            .font(LearningSprintTheme.sans(14))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(LearningSprintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if model.hasResumableSession {
                    Button(action: model.resumePreviousSession) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("前回の続きから再開")
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
                            Text("標準スプリント")
                                .font(LearningSprintTheme.serif(20, weight: .bold))
                            Text("\(model.dailyTarget)問を短時間で反復")
                                .font(LearningSprintTheme.sans(13))
                                .opacity(0.82)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.white)
                    .background(LearningSprintTheme.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!model.hasReadyContent)
                .accessibilityIdentifier("start-standard-sprint")

                if model.weakQuestionCount > 0 {
                    Button(action: model.requestWeakReview) {
                        HStack {
                            Label("苦手復習", systemImage: "arrow.triangle.2.circlepath")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            Spacer()
                            Text("\(model.weakQuestionCount)問")
                                .font(LearningSprintTheme.sans(13, weight: .semibold))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(LearningSprintTheme.card)
                        .foregroundStyle(LearningSprintTheme.vermilion)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start-weak-review")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("分野別演習")
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
                                    if let accuracy = model.coordinator.subjectAccuracy[subject] {
                                        Text("正答率 \(Int((accuracy * 100).rounded()))%")
                                            .font(LearningSprintTheme.sans(11))
                                            .foregroundStyle(LearningSprintTheme.ink3)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(LearningSprintTheme.ink3)
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

                LearningSprintMemoryBlock("根拠の確認日を問題単位で保持。制度・統計・医療情報の更新時は再監査で古い問題を止める。")
            }
            .padding(18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("")
        .background(Color.clear)
    }

    private var mock: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("模試")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                Text("独自模試3回分。各110問＝一般75問＋状況設定35問で構成します。")
                    .font(LearningSprintTheme.sans(15))
                    .foregroundStyle(LearningSprintTheme.ink2)

                ForEach(1...JosanshiExamConfiguration.originalMockSetCount, id: \.self) { index in
                    Button {
                        model.requestMock(index)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("独自模試 \(index)")
                                    .font(LearningSprintTheme.serif(20, weight: .semibold))
                                    .foregroundStyle(LearningSprintTheme.ink)
                                Text("110問・FULL監査済み")
                                    .font(LearningSprintTheme.sans(14))
                                    .foregroundStyle(LearningSprintTheme.ink2)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
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

                HStack(spacing: 12) {
                    metricCard(title: "今日", value: "\(model.todayAnsweredCount)問")
                    metricCard(title: "苦手", value: "\(model.weakQuestionCount)問")
                }

                Text("直近5週間")
                    .font(LearningSprintTheme.sans(15, weight: .semibold))
                LearningSprintHeatmap(values: model.coordinator.heatmap35Days)

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
            }
            .padding(18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(LearningSprintTheme.sans(12, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink3)
            Text(value)
                .font(LearningSprintTheme.serif(22, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var settings: some View {
        Form {
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

            Section("コンテンツ") {
                LabeledContent("状態", value: model.contentStatusText)
                LabeledContent("最新確認試験", value: "第109回")
                LabeledContent("本試験構造", value: "110問")
                LabeledContent("独自問題", value: model.productionQuestionTargetText)
                LabeledContent("出題基準", value: "令和5年版")
            }

            Section("端末内データ") {
                LabeledContent("保存", value: "自動")
                LabeledContent("再開", value: model.hasResumableSession ? "あり" : "なし")
                LabeledContent("回答履歴", value: "\(model.coordinator.state.attempts.count)件")
                if let message = model.coordinator.persistenceErrorDescription {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("バックアップ") {
                Button("JSONを書き出す") {
                    do {
                        backupDocument = JosanshiBackupDocument(data: try model.exportBackup())
                        isExportingBackup = true
                    } catch {
                        backupMessage = error.localizedDescription
                    }
                }
                Button("JSONから復元") {
                    isImportingBackup = true
                }
                Text("学習履歴・苦手・1日の目標・途中セッションを端末外へ保存できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("本番識別子") {
                LabeledContent("Bundle ID", value: "要確認")
                LabeledContent("ASC App ID", value: "要確認")
                LabeledContent("IAP Product ID", value: "要確認")
                Text("ローカル学習データの保存には本番Bundle IDを流用せず、専用namespaceを使用しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
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
