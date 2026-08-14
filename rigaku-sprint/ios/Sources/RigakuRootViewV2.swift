import LearningSprintCore
import SwiftUI
import UniformTypeIdentifiers

struct RigakuRootViewV2: View {
    @StateObject private var appModel = RigakuAppModel()

    var body: some View {
        TabView {
            RigakuHomeV2()
                .tabItem { Label("ホーム", systemImage: "house") }
            RigakuMockListV2()
                .tabItem { Label("模試", systemImage: "doc.text") }
            RigakuHistoryV2()
                .tabItem { Label("記録", systemImage: "chart.bar") }
            RigakuSettingsV2()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(LearningSprintTheme.indigo)
        .environmentObject(appModel)
    }
}

private struct RigakuHomeV2: View {
    @EnvironmentObject private var appModel: RigakuAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        progressCard
                        contentProgress
                        resumeCard
                        dailyCard
                        weakCard
                        subjectSection
                        summarySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("home.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(RigakuAppConfiguration.seriesName)
                .font(LearningSprintTheme.sans(12, weight: .bold))
                .foregroundStyle(LearningSprintTheme.vermilion)
            Text(RigakuAppConfiguration.qualificationName)
                .font(LearningSprintTheme.serif(25, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
            Text("今日も1問、力に変える。")
                .font(LearningSprintTheme.sans(14, weight: .medium))
                .foregroundStyle(LearningSprintTheme.ink2)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressCard: some View {
        HStack(spacing: 16) {
            LearningSprintProgressRing(
                progress: appModel.dailyProgress,
                label: "\(min(appModel.todayAnsweredCount, appModel.state.dailyTarget))/\(appModel.state.dailyTarget)"
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("今日の学習")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)
                Text(appModel.todayAnsweredCount >= appModel.state.dailyTarget
                     ? "今日の目標を達成しました"
                     : "あと\(max(0, appModel.state.dailyTarget - appModel.todayAnsweredCount))問で今日の1セット完了")
                    .font(LearningSprintTheme.serif(17, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
        .accessibilityIdentifier("home.progress")
    }

    private var contentProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("監査済み問題", systemImage: "checkmark.shield")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.indigo)
                Spacer()
                Text("\(appModel.questions.count) / 600")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
            }
            ProgressView(value: Double(appModel.questions.count), total: 600)
                .tint(LearningSprintTheme.indigo)
            Text(appModel.questions.count == 600
                 ? "第60・59・58回の監査済み問題バンクが完成しています。"
                 : "監査を通過した問題だけ順次利用できます。模試は各回200問が揃うまで開始できません。")
                .font(LearningSprintTheme.sans(12, weight: .medium))
                .foregroundStyle(LearningSprintTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(LearningSprintTheme.indigoSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("home.contentProgress")
    }

    @ViewBuilder
    private var resumeCard: some View {
        if let snapshot = appModel.state.resumeSession {
            NavigationLink {
                RigakuStudyView(kind: snapshot.kind, resumeExisting: true)
            } label: {
                actionCard(
                    title: "途中から再開",
                    subtitle: appModel.isSessionAvailable(snapshot.kind) ? "前回の続きから" : "必要な監査済み問題が揃うまで再開できません",
                    systemImage: "arrow.uturn.forward.circle",
                    accent: LearningSprintTheme.gold
                )
            }
            .buttonStyle(.plain)
            .disabled(!appModel.isSessionAvailable(snapshot.kind))
        }
    }

    private var dailyCard: some View {
        NavigationLink {
            RigakuStudyView(kind: .sprint)
        } label: {
            actionCard(
                title: "今日のスプリント",
                subtitle: "\(appModel.state.dailyTarget)問・短時間で1セット",
                systemImage: "figure.run",
                accent: LearningSprintTheme.vermilion
            )
        }
        .buttonStyle(.plain)
        .disabled(!appModel.isSessionAvailable(.sprint))
        .accessibilityIdentifier("home.daily")
    }

    private var weakCard: some View {
        NavigationLink {
            RigakuStudyView(kind: .weak)
        } label: {
            actionCard(
                title: "苦手をつぶす",
                subtitle: "誤答・わからない \(appModel.weakCount)問",
                systemImage: "scope",
                accent: LearningSprintTheme.green
            )
        }
        .buttonStyle(.plain)
        .disabled(!appModel.isSessionAvailable(.weak))
        .accessibilityIdentifier("home.weak")
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野から解く")
                .font(LearningSprintTheme.sans(16, weight: .bold))
            ForEach(RigakuAppConfiguration.generalSubjects, id: \.self) { subject in
                let count = appModel.auditedQuestionCount(forSubject: subject)
                NavigationLink {
                    RigakuStudyView(kind: .subject(subject))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(subject)
                                .font(LearningSprintTheme.sans(14, weight: .semibold))
                            HStack(spacing: 8) {
                                Text("監査済み \(count)問")
                                if let accuracy = appModel.subjectAccuracy[subject] {
                                    Text("正答率 \(Int((accuracy * 100).rounded()))%")
                                }
                            }
                            .font(LearningSprintTheme.sans(11, weight: .medium))
                            .foregroundStyle(LearningSprintTheme.ink3)
                        }
                        Spacer()
                        Image(systemName: count > 0 ? "chevron.right" : "lock")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(LearningSprintTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
            }
        }
        .accessibilityIdentifier("home.subjects")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで")
                .font(LearningSprintTheme.sans(16, weight: .bold))
            HStack(spacing: 10) {
                RigakuSummaryCellV2(label: "解答", value: "\(appModel.state.attempts.count)")
                RigakuSummaryCellV2(label: "正答率", value: accuracyLabel)
                RigakuSummaryCellV2(label: "苦手", value: "\(appModel.weakCount)")
            }
        }
    }

    private var accuracyLabel: String {
        guard let value = appModel.accuracy else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func actionCard(title: String, subtitle: String, systemImage: String, accent: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(LearningSprintTheme.sans(16, weight: .bold))
                Text(subtitle)
                    .font(LearningSprintTheme.sans(12, weight: .medium))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(LearningSprintTheme.ink)
        .padding(16)
        .frame(minHeight: 58)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
    }
}

private struct RigakuMockListV2: View {
    @EnvironmentObject private var appModel: RigakuAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("第58〜60回ベース模試")
                            .font(LearningSprintTheme.serif(26, weight: .bold))
                        Text("各回200枠の公式出題範囲・配点をもとに、問題文と図版を権利・内容監査した独自問題で再構成しています。")
                            .font(LearningSprintTheme.sans(13))
                            .foregroundStyle(LearningSprintTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(RigakuAppConfiguration.examRounds) { exam in
                            let round = String(exam.round)
                            let readyCount = appModel.auditedQuestionCount(forRound: round)
                            let expected = exam.officialQuestionCount ?? 0
                            let ready = appModel.isMockReady(round: round, expectedQuestionCount: exam.officialQuestionCount)

                            NavigationLink {
                                RigakuStudyView(kind: .mock(round))
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("第\(exam.round)回ベース模試")
                                            .font(LearningSprintTheme.serif(20, weight: .bold))
                                        Text("監査済み \(readyCount) / \(expected)問")
                                            .font(LearningSprintTheme.sans(12, weight: .semibold))
                                            .foregroundStyle(ready ? LearningSprintTheme.green : LearningSprintTheme.ink2)
                                        Text(ready ? "200問のベース模試を開始" : "全問PASS後に解放")
                                            .font(LearningSprintTheme.sans(11, weight: .medium))
                                            .foregroundStyle(LearningSprintTheme.ink3)
                                    }
                                    Spacer()
                                    Image(systemName: ready ? "checkmark.seal" : "lock")
                                        .foregroundStyle(ready ? LearningSprintTheme.green : LearningSprintTheme.gold)
                                }
                                .padding(16)
                                .background(LearningSprintTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
                            }
                            .buttonStyle(.plain)
                            .disabled(!ready)
                            .accessibilityIdentifier("mock.round.\(exam.round)")
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("mock.screen")
    }
}

private struct RigakuHistoryV2: View {
    @EnvironmentObject private var appModel: RigakuAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("学習記録")
                            .font(LearningSprintTheme.serif(26, weight: .bold))

                        HStack(spacing: 10) {
                            RigakuSummaryCellV2(label: "解答", value: "\(appModel.state.attempts.count)")
                            RigakuSummaryCellV2(label: "正答率", value: accuracyLabel)
                            RigakuSummaryCellV2(label: "苦手", value: "\(appModel.weakCount)")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("直近5週間")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            LearningSprintHeatmap(values: appModel.heatmap)
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        subjectAccuracy

                        if let pace = appModel.requiredDailyPace, appModel.state.examDate != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("試験日までの目安")
                                    .font(LearningSprintTheme.sans(13, weight: .bold))
                                Text("未消化の監査済み問題を1日 約\(pace)問")
                                    .font(LearningSprintTheme.serif(17, weight: .semibold))
                            }
                            .padding(16)
                            .background(LearningSprintTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("history.screen")
    }

    private var subjectAccuracy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野別")
                .font(LearningSprintTheme.sans(15, weight: .bold))
            ForEach(RigakuAppConfiguration.generalSubjects, id: \.self) { subject in
                HStack {
                    Text(subject)
                        .font(LearningSprintTheme.sans(13, weight: .semibold))
                    Spacer()
                    Text(appModel.subjectAccuracy[subject].map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        .font(LearningSprintTheme.sans(13, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.indigo)
                }
                if subject != RigakuAppConfiguration.generalSubjects.last {
                    Divider().overlay(LearningSprintTheme.line)
                }
            }
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var accuracyLabel: String {
        guard let value = appModel.accuracy else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}

private struct RigakuSettingsV2: View {
    @EnvironmentObject private var appModel: RigakuAppModel
    @State private var exportDocument: LearningBackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var operationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                Form {
                    Section("文字サイズ") {
                        Picker("文字サイズ", selection: textSizeBinding) {
                            Text("小").tag(0)
                            Text("標準").tag(1)
                            Text("大").tag(2)
                        }
                        .pickerStyle(.segmented)
                        Text("iOSのDynamic Typeにも対応します。")
                            .font(.caption)
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }

                    Section("1日の目標") {
                        Picker("問題数", selection: dailyTargetBinding) {
                            ForEach(RigakuAppConfiguration.allowedDailyTargets, id: \.self) { value in
                                Text("\(value)問").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("試験日") {
                        Toggle("試験日を設定", isOn: examDateEnabled)
                        if appModel.state.examDate != nil {
                            DatePicker(
                                "試験日",
                                selection: examDateBinding,
                                in: Calendar.current.startOfDay(for: Date())...,
                                displayedComponents: .date
                            )
                        }
                    }

                    Section("バックアップ") {
                        Button("JSONを書き出す") { exportBackup() }
                        Button("JSONから復元") { showImporter = true }
                        if let operationMessage {
                            Text(operationMessage)
                                .font(.caption)
                                .foregroundStyle(LearningSprintTheme.ink2)
                        }
                    }

                    Section("覚えかたのルール") {
                        Text("間違い・「わからない」は苦手に追加し、3回連続正解で苦手から卒業します。")
                            .font(.caption)
                    }

                    RigakuPurchaseSettingsSection()
                    RigakuLegalSettingsSection()

                    Section("この教材について") {
                        LabeledContent("コンテンツ版", value: RigakuAppConfiguration.contentVersion)
                        LabeledContent("監査済み", value: "\(appModel.questions.count) / 600問")
                        LabeledContent("Bundle ID", value: RigakuAppConfiguration.runtimeBundleIdentifier ?? "要確認")
                        Text("App Store Connect App ID / Bundle ID / IAP Product ID は正本値が確認できるまで推測値を埋め込みません。")
                            .font(.caption)
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "rigaku-sprint-backup"
        ) { result in
            if case .failure = result {
                operationMessage = "バックアップ書き出しを完了できませんでした。"
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            importBackup(result)
        }
        .accessibilityIdentifier("settings.screen")
    }

    private var dailyTargetBinding: Binding<Int> {
        Binding(
            get: { appModel.state.dailyTarget },
            set: { appModel.setDailyTarget($0) }
        )
    }

    private var textSizeBinding: Binding<Int> {
        Binding(
            get: { appModel.state.textSizeStep },
            set: { appModel.setTextSizeStep($0) }
        )
    }

    private var examDateEnabled: Binding<Bool> {
        Binding(
            get: { appModel.state.examDate != nil },
            set: { enabled in
                appModel.setExamDate(enabled ? (appModel.state.examDate ?? defaultExamDate) : nil)
            }
        )
    }

    private var examDateBinding: Binding<Date> {
        Binding(
            get: { appModel.state.examDate ?? defaultExamDate },
            set: { appModel.setExamDate($0) }
        )
    }

    private var defaultExamDate: Date {
        Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    }

    private func exportBackup() {
        do {
            exportDocument = LearningBackupDocument(data: try appModel.exportBackup())
            showExporter = true
            operationMessage = nil
        } catch {
            operationMessage = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            try appModel.importBackup(Data(contentsOf: url))
            operationMessage = "バックアップを復元しました。"
        } catch {
            operationMessage = error.localizedDescription
        }
    }
}

private struct RigakuSummaryCellV2: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(LearningSprintTheme.serif(21, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
            Text(label)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink3)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
