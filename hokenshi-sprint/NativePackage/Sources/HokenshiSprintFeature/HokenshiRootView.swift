#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import LearningSprintCore

public struct HokenshiRootView: View {
    @StateObject private var model = HokenshiProductModel()
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            TabView(selection: $selectedTab) {
                HomeView(model: model, selectedTab: $selectedTab)
                    .tabItem { Label("ホーム", systemImage: "house.fill") }.tag(0)
                MockView(model: model)
                    .tabItem { Label("模試", systemImage: "doc.text.fill") }.tag(1)
                HistoryView(model: model)
                    .tabItem { Label("記録", systemImage: "chart.bar.fill") }.tag(2)
                SettingsView(model: model)
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }.tag(3)
            }
            .tint(LearningSprintTheme.indigo)
        }
        .environment(\.dynamicTypeSize, preferredDynamicTypeSize)
        .sheet(item: $model.activeSession) { session in
            HokenshiSessionContainer(
                questions: session.questions,
                title: session.title,
                startIndex: session.startIndex,
                onAdvance: model.commitAdvance,
                onClose: {
                    model.closeActiveSession(keepForResume: model.state.resumeSession != nil)
                }
            )
        }
    }

    private var preferredDynamicTypeSize: DynamicTypeSize {
        switch model.state.textSizeStep {
        case 2: return .xxLarge
        case 1: return .xLarge
        default: return .large
        }
    }
}

private struct HomeView: View {
    @ObservedObject var model: HokenshiProductModel
    @Binding var selectedTab: Int

    private var progress: Double {
        min(1, Double(model.todayAnsweredCount) / Double(max(1, model.state.dailyTarget)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("学びスプリント")
                        .font(LearningSprintTheme.sans(12, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text("保健師国家試験")
                        .font(LearningSprintTheme.serif(28, weight: .bold))
                    Text("今日も1問、力に変える。")
                        .font(LearningSprintTheme.sans(14))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                if let error = model.loadError {
                    Card {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.vermilion)
                    }
                }

                Card {
                    HStack(spacing: 18) {
                        LearningSprintProgressRing(
                            progress: progress,
                            label: "\(model.todayAnsweredCount) / \(model.state.dailyTarget)"
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text("今日の学習")
                                .font(LearningSprintTheme.sans(13, weight: .bold))
                            Text("\(model.state.dailyTarget)問で1スプリント")
                                .font(LearningSprintTheme.serif(20, weight: .semibold))
                            if let pace = model.requiredDailyPace {
                                Text("目標試験日まで 1日\(pace)問")
                                    .font(LearningSprintTheme.sans(12, weight: .bold))
                                    .foregroundStyle(LearningSprintTheme.vermilion)
                            } else {
                                Text("短く区切って、毎日積み上げる")
                                    .font(LearningSprintTheme.sans(12))
                                    .foregroundStyle(LearningSprintTheme.ink3)
                            }
                        }
                    }
                }

                if model.canResume {
                    actionButton(
                        "途中から再開",
                        "確定済み回答の次から",
                        "arrow.clockwise.circle.fill",
                        LearningSprintTheme.green,
                        model.resume
                    )
                    .accessibilityIdentifier("hokenshi.resume")
                }

                Text("今日のスプリント").sectionTitle()
                actionButton(
                    "\(model.state.dailyTarget)問を解く",
                    "標準スプリント",
                    "figure.run",
                    LearningSprintTheme.indigo,
                    model.startSprint
                )
                .accessibilityIdentifier("hokenshi.start.sprint")

                HStack(spacing: 12) {
                    actionButton(
                        "苦手をつぶす",
                        "\(model.state.weakQuestions.count)問・3連続で解除",
                        "target",
                        LearningSprintTheme.vermilion,
                        model.startWeak
                    )
                    .disabled(model.state.weakQuestions.isEmpty)
                    .opacity(model.state.weakQuestions.isEmpty ? 0.55 : 1)
                    actionButton("模擬試験", "110問 × 3回", "doc.text", LearningSprintTheme.gold) {
                        selectedTab = 1
                    }
                }

                Text("分野から解く").sectionTitle()
                ForEach(Array(HokenshiExamBlueprint.current.subjects.enumerated()), id: \.offset) { index, subject in
                    Button { model.startSubject(subject) } label: {
                        Card {
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", index + 1))
                                    .font(LearningSprintTheme.sans(11, weight: .bold))
                                    .foregroundStyle(LearningSprintTheme.indigo)
                                    .frame(width: 30, height: 30)
                                    .background(LearningSprintTheme.indigoSoft)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject)
                                        .font(LearningSprintTheme.sans(14, weight: .semibold))
                                        .foregroundStyle(LearningSprintTheme.ink)
                                    Text("33問収録")
                                        .font(LearningSprintTheme.sans(10))
                                        .foregroundStyle(LearningSprintTheme.ink3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(LearningSprintTheme.ink3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(subject)、33問収録")
                }

                Text("これまで").sectionTitle()
                HStack(spacing: 10) {
                    Metric("解答", "\(model.state.attempts.count)")
                    Metric("正答率", percent(model.accuracy))
                    Metric("苦手", "\(model.state.weakQuestions.count)")
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 96)
        }
        .accessibilityIdentifier("hokenshi.home")
    }

    private func actionButton(
        _ title: String,
        _ subtitle: String,
        _ icon: String,
        _ accent: Color,
        _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ActionCard(title: title, subtitle: subtitle, icon: icon, accent: accent)
        }
        .buttonStyle(.plain)
    }

    private func percent(_ value: Double?) -> String {
        value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }
}

private struct MockView: View {
    @ObservedObject var model: HokenshiProductModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("模擬試験")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                Text("独自問題3回分。午前55・午後55・通し110から選べます。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                Text("一般75問・状況設定35問。10分野×11問は周回学習用に均等化した本アプリ独自設計で、実際の国家試験の科目別出題比率を示すものではありません。")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink3)
                    .lineSpacing(3)

                ForEach(1...3, id: \.self) { round in
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("独自模試 第\(round)回")
                                        .font(LearningSprintTheme.serif(19, weight: .semibold))
                                    Text("110問・監査済み")
                                        .font(LearningSprintTheme.sans(12, weight: .bold))
                                        .foregroundStyle(LearningSprintTheme.green)
                                }
                                Spacer()
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(LearningSprintTheme.green)
                            }
                            HStack(spacing: 8) {
                                ForEach(HokenshiMockSegment.allCases, id: \.rawValue) { segment in
                                    Button(segment.rawValue) {
                                        model.startMock(round: round, segment: segment)
                                    }
                                    .font(LearningSprintTheme.sans(11, weight: .bold))
                                    .foregroundStyle(segment == .full ? Color.white : LearningSprintTheme.indigo)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(segment == .full ? LearningSprintTheme.indigo : LearningSprintTheme.indigoSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .accessibilityLabel("独自模試 第\(round)回 \(segment.rawValue)を開始")
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(18)
            .padding(.bottom, 90)
        }
        .accessibilityIdentifier("hokenshi.mock")
    }
}

private struct HistoryView: View {
    @ObservedObject var model: HokenshiProductModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("学習記録")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                HStack(spacing: 10) {
                    Metric("解答", "\(model.state.attempts.count)")
                    Metric("正答", "\(model.state.attempts.filter(\.isCorrect).count)")
                    Metric("苦手", "\(model.state.weakQuestions.count)")
                }
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("直近5週間")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        LearningSprintHeatmap(values: model.heatmap)
                    }
                }
                Text("分野別").sectionTitle()
                ForEach(HokenshiExamBlueprint.current.subjects, id: \.self) { subject in
                    Card {
                        HStack {
                            Text(subject)
                                .font(LearningSprintTheme.sans(13, weight: .semibold))
                            Spacer()
                            Text(subjectPercent(subject))
                                .font(LearningSprintTheme.serif(15, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.indigo)
                        }
                    }
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(18)
            .padding(.bottom, 90)
        }
        .accessibilityIdentifier("hokenshi.history")
    }

    private func subjectPercent(_ subject: String) -> String {
        model.subjectAccuracy[subject].map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }
}

private struct SettingsView: View {
    @ObservedObject var model: HokenshiProductModel
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument = HokenshiJSONDocument(data: Data())
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("設定")
                    .font(LearningSprintTheme.serif(28, weight: .bold))

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1日の目標")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Picker(
                            "1日の目標",
                            selection: Binding(get: { model.state.dailyTarget }, set: model.setDailyTarget)
                        ) {
                            ForEach([4, 8, 16], id: \.self) { count in
                                Text("\(count)問").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("文字サイズ")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Picker(
                            "文字サイズ",
                            selection: Binding(get: { model.state.textSizeStep }, set: model.setTextSizeStep)
                        ) {
                            Text("標準").tag(0)
                            Text("大").tag(1)
                            Text("特大").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(
                            "目標試験日を設定",
                            isOn: Binding(
                                get: { model.state.examDate != nil },
                                set: { enabled in
                                    if enabled {
                                        model.setExamDate(model.state.examDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()))
                                    } else {
                                        model.setExamDate(nil)
                                    }
                                }
                            )
                        )
                        .font(LearningSprintTheme.sans(13, weight: .bold))
                        if let examDate = model.state.examDate {
                            DatePicker(
                                "目標試験日",
                                selection: Binding(get: { examDate }, set: { model.setExamDate($0) }),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("バックアップ")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Text("学習履歴・苦手・設定をJSONで保存し、同じ保健師アプリへ戻せます。")
                            .font(LearningSprintTheme.sans(12))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        HStack {
                            Button("書き出す", action: prepareExport)
                            Button("読み込む") { importing = true }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("データの扱い")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Text("問題と学習記録は端末内で利用する設計です。アカウント登録は不要です。")
                            .font(LearningSprintTheme.sans(12))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                }

                if let message {
                    Text(message)
                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(18)
            .padding(.bottom, 90)
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "hokenshi-learning-backup"
        ) { result in
            if case .failure = result { message = "バックアップを書き出せませんでした。" }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.json],
            onCompletion: importFile
        )
        .accessibilityIdentifier("hokenshi.settings")
    }

    private func prepareExport() {
        do {
            exportDocument = HokenshiJSONDocument(data: try model.exportBackup())
            exporting = true
        } catch {
            message = "バックアップを作成できませんでした。"
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try model.importBackup(Data(contentsOf: url))
            message = "バックアップを読み込みました。"
        } catch {
            message = "このバックアップは読み込めません。"
        }
    }
}

public struct HokenshiJSONDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }
    public var data: Data
    public init(data: Data) { self.data = data }
    public init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LearningSprintTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.bold())
                    .foregroundStyle(accent)
                Text(title)
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                Text(subtitle)
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Metric: View {
    let title: String
    let value: String
    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }
    var body: some View {
        VStack(spacing: 5) {
            Text(value).font(LearningSprintTheme.serif(20, weight: .bold))
            Text(title)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private extension Text {
    func sectionTitle() -> some View {
        font(LearningSprintTheme.sans(13, weight: .bold))
            .foregroundStyle(LearningSprintTheme.ink2)
    }
}
#endif
