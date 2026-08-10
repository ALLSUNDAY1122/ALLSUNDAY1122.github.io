import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var store: LearningStore
    private let heatColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea()
            PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "記録", subtitle: "反復量と弱点の変化を、短く確認します。")

                    HStack(spacing: 16) {
                        ProgressRing(
                            progress: Double(store.overallAccuracy) / 100,
                            value: "\(store.overallAccuracy)%",
                            caption: "正答率",
                            size: 104
                        )
                        VStack(spacing: 10) {
                            historyStat("\(store.totalAnswered)", "回答")
                            historyStat("\(store.seenCount)", "既習")
                            historyStat("\(store.weakQuestions.count)", "苦手")
                        }
                    }
                    .padding(16)
                    .appCard()

                    Text("分野別")
                        .appSerif(19, weight: .bold)
                        .foregroundStyle(AppTheme.ink)
                    VStack(spacing: 13) {
                        ForEach(store.repository.domains, id: \.self) { domain in
                            let stat = store.domainStats(domain)
                            VStack(spacing: 6) {
                                HStack {
                                    Text(domain)
                                        .appSans(13, weight: .bold)
                                        .foregroundStyle(AppTheme.ink)
                                    Spacer()
                                    Text(stat.answered == 0 ? "未回答" : "\(stat.accuracy)%")
                                        .appSans(11, weight: .bold)
                                        .foregroundStyle(AppTheme.ink3)
                                }
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppTheme.aiSoft)
                                        Capsule().fill(AppTheme.ai)
                                            .frame(width: proxy.size.width * CGFloat(stat.accuracy) / 100)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                    .padding(16)
                    .appCard()

                    Text("5週間")
                        .appSerif(19, weight: .bold)
                        .foregroundStyle(AppTheme.ink)
                    LazyVGrid(columns: heatColumns, spacing: 4) {
                        ForEach(Array(store.heatmap().enumerated()), id: \.offset) { _, item in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(heatColor(item.count))
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityLabel("\(item.date.formatted(date: .abbreviated, time: .omitted))、\(item.count)問")
                        }
                    }
                    .padding(14)
                    .appCard()

                    HStack {
                        Text("苦手一覧")
                            .appSerif(19, weight: .bold)
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Text("3連続正解で解除")
                            .appSans(10, weight: .bold)
                            .foregroundStyle(AppTheme.ink3)
                    }
                    if store.weakQuestions.isEmpty {
                        Text("現在の苦手はありません。")
                            .appSans(13)
                            .foregroundStyle(AppTheme.ink2)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .padding(.horizontal, 16)
                            .appCard()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.weakQuestions) { question in
                                Button {
                                    store.retryQuestions([question.id], title: question.topic)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(question.topic)
                                                .appSans(14, weight: .bold)
                                                .foregroundStyle(AppTheme.ink)
                                            Text(question.uiDomain)
                                                .appSans(10)
                                                .foregroundStyle(AppTheme.ink3)
                                        }
                                        Spacer()
                                        let streak = store.state.weak[question.id]?.streak ?? 0
                                        Text("連続 \(streak)/3")
                                            .appSans(11, weight: .bold)
                                            .foregroundStyle(AppTheme.shu)
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(AppTheme.ink3)
                                    }
                                    .padding(14)
                                    .frame(minHeight: 54)
                                }
                                .buttonStyle(.plain)
                                .appCard()
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
        .accessibilityIdentifier("history.screen")
    }

    private func historyStat(_ value: String, _ label: String) -> some View {
        HStack {
            Text(value)
                .appSerif(19, weight: .bold)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(label)
                .appSans(11, weight: .bold)
                .foregroundStyle(AppTheme.ink3)
        }
    }

    private func heatColor(_ count: Int) -> Color {
        if count >= 16 { return AppTheme.midori }
        if count >= 8 { return AppTheme.midori.opacity(0.75) }
        if count >= 4 { return AppTheme.midori.opacity(0.5) }
        if count >= 1 { return AppTheme.midori.opacity(0.25) }
        return AppTheme.line
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.paper.ignoresSafeArea()
            PaperGridBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: "設定", subtitle: "学習量・文字・試験日・バックアップを管理します。")

                    settingsSection("1日の問題数") {
                        Picker("1日の問題数", selection: Binding(
                            get: { store.settings.dailyGoal },
                            set: { store.setDailyGoal($0) }
                        )) {
                            ForEach([4, 8, 16], id: \.self) { Text("\($0)問").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.dailyGoal")
                    }

                    settingsSection("文字サイズ") {
                        Picker("文字サイズ", selection: Binding(
                            get: { store.settings.fontSize },
                            set: { store.setFontSize($0) }
                        )) {
                            ForEach(FontSizePreference.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.fontSize")
                    }

                    settingsSection("試験日") {
                        Toggle("試験日を設定", isOn: Binding(
                            get: { store.settings.examDate != nil },
                            set: { enabled in
                                if enabled {
                                    let date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                                    store.setExamDate(date)
                                } else {
                                    store.setExamDate(nil)
                                }
                            }
                        ))
                        .tint(AppTheme.ai)
                        if let examDate = store.settings.examDate {
                            DatePicker("試験日", selection: Binding(
                                get: { examDate },
                                set: { store.setExamDate($0) }
                            ), displayedComponents: .date)
                            .datePickerStyle(.compact)
                        }
                    }

                    settingsSection("JSONバックアップ") {
                        VStack(spacing: 10) {
                            Button {
                                do {
                                    exportDocument = BackupDocument(data: try store.exportBackup())
                                    showExporter = true
                                } catch {
                                    importError = error.localizedDescription
                                }
                            } label: {
                                settingsAction("square.and.arrow.up", "JSONを書き出す")
                            }
                            .buttonStyle(.plain)

                            Button {
                                showImporter = true
                            } label: {
                                settingsAction("square.and.arrow.down", "JSONを読み込む")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    settingsSection("このアプリ") {
                        VStack(alignment: .leading, spacing: 10) {
                            infoRow("コンテンツ", store.repository.payload.contentVersion)
                            infoRow("監査記録日時", store.repository.payload.sourceCheckedAt.isEmpty ? "未取得" : store.repository.payload.sourceCheckedAt)
                            infoRow("法令基準日", store.repository.payload.lawBaselineDate ?? "正本に定義なし")
                            infoRow("問題", "75出題枠 / 68ユニーク")
                            infoRow("課金", "初期版なし")
                        }
                    }

                    settingsSection("サポート") {
                        VStack(spacing: 10) {
                            Link(destination: URL(string: "https://allsunday1122.github.io/network-specialist-sprint/support.html")!) {
                                settingsAction("questionmark.circle", "サポート")
                            }
                            Link(destination: URL(string: "https://allsunday1122.github.io/network-specialist-sprint/privacy.html")!) {
                                settingsAction("hand.raised", "プライバシーポリシー")
                            }
                        }
                    }

                    Text("本アプリは独立した学習アプリであり、IPAの公式アプリではありません。IPA公開問題を基に改変した問題には出典を表示します。")
                        .appSans(11)
                        .foregroundStyle(AppTheme.ink3)
                        .padding(.bottom, 18)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "network-specialist-backup"
        ) { result in
            if case .failure(let error) = result { importError = error.localizedDescription }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try store.importBackup(Data(contentsOf: url))
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("バックアップ", isPresented: Binding(
            get: { importError != nil || store.importMessage != nil },
            set: { visible in
                if !visible {
                    importError = nil
                    store.clearImportMessage()
                }
            }
        )) {
            Button("OK", role: .cancel) {
                importError = nil
                store.clearImportMessage()
            }
        } message: {
            Text(importError ?? store.importMessage ?? "")
        }
        .accessibilityIdentifier("settings.screen")
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .appSerif(18, weight: .bold)
                .foregroundStyle(AppTheme.ink)
            content()
        }
        .padding(16)
        .appCard()
    }

    private func settingsAction(_ image: String, _ title: String) -> some View {
        HStack {
            Image(systemName: image)
                .foregroundStyle(AppTheme.ai)
                .frame(width: 24)
            Text(title)
                .appSans(14, weight: .bold)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.ink3)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .appSans(11, weight: .bold)
                .foregroundStyle(AppTheme.ink3)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .appSans(12)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
