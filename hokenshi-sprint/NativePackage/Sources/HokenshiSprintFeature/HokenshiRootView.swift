#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import LearningSprintCore

public struct HokenshiRootView: View {
    @StateObject private var model = HokenshiProductModel()
    @State private var selectedTab: Tab = .home

    public init() {}

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            TabView(selection: $selectedTab) {
                HokenshiHomeView(model: model, selectedTab: $selectedTab)
                    .tabItem { Label("ホーム", systemImage: "house.fill") }
                    .tag(Tab.home)
                HokenshiMockListView(model: model)
                    .tabItem { Label("模試", systemImage: "doc.text.fill") }
                    .tag(Tab.mock)
                HokenshiHistoryView(model: model)
                    .tabItem { Label("記録", systemImage: "chart.bar.fill") }
                    .tag(Tab.history)
                HokenshiSettingsView(model: model)
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
            .tint(LearningSprintTheme.indigo)
        }
        .fullScreenCover(item: $model.activeSession) { session in
            HokenshiSessionContainer(
                questions: session.questions,
                title: session.title,
                onComplete: { evaluations in
                    model.finishActiveSession(evaluations)
                },
                onClose: {
                    model.closeActiveSession(keepForResume: model.state.resumeSession != nil)
                }
            )
        }
    }

    enum Tab: Hashable {
        case home, mock, history, settings
    }
}

public struct HokenshiHomeView: View {
    @ObservedObject var model: HokenshiProductModel
    @Binding var selectedTab: HokenshiRootView.Tab

    var progress: Double {
        guard model.state.dailyTarget > 0 else { return 0 }
        return min(1, Double(model.todayAnsweredCount) / Double(model.state.dailyTarget))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("学びスプリント")
                        .font(LearningSprintTheme.sans(12, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text("保健師国家試験")
                        .font(LearningSprintTheme.serif(28, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text("今日も1問、力に変える。")
                        .font(LearningSprintTheme.sans(14, weight: .medium))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                if let loadError = model.loadError {
                    HokenshiCard {
                        Label(loadError, systemImage: "exclamationmark.triangle.fill")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.vermilion)
                    }
                }

                HokenshiCard {
                    HStack(spacing: 18) {
                        LearningSprintProgressRing(
                            progress: progress,
                            label: "\(model.todayAnsweredCount) / \(model.state.dailyTarget)"
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text("今日の学習")
                                .font(LearningSprintTheme.sans(13, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.ink2)
                            Text("\(model.state.dailyTarget)問で1スプリント")
                                .font(LearningSprintTheme.serif(20, weight: .semibold))
                                .foregroundStyle(LearningSprintTheme.ink)
                            if let pace = model.requiredDailyPace {
                                Text("試験日までの必要ペース：1日\(pace)問")
                                    .font(LearningSprintTheme.sans(12, weight: .bold))
                                    .foregroundStyle(LearningSprintTheme.vermilion)
                            } else {
                                Text("短く区切って、毎日積み上げる")
                                    .font(LearningSprintTheme.sans(12))
                                    .foregroundStyle(LearningSprintTheme.ink3)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                if model.canResume {
                    Button(action: model.resume) {
                        HokenshiActionCard(
                            title: "途中から再開",
                            subtitle: "前回の問題セット",
                            systemImage: "arrow.clockwise.circle.fill",
                            accent: LearningSprintTheme.green
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hokenshi.resume")
                }

                Text("今日のスプリント")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)

                Button(action: model.startSprint) {
                    HokenshiActionCard(
                        title: "\(model.state.dailyTarget)問を解く",
                        subtitle: "標準スプリント",
                        systemImage: "figure.run",
                        accent: LearningSprintTheme.indigo
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hokenshi.start.sprint")

                HStack(spacing: 12) {
                    Button(action: model.startWeak) {
                        HokenshiActionCard(
                            title: "苦手をつぶす",
                            subtitle: "\(model.state.weakQuestions.count)問・3連続で解除",
                            systemImage: "target",
                            accent: LearningSprintTheme.vermilion
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(model.state.weakQuestions.isEmpty)
                    .opacity(model.state.weakQuestions.isEmpty ? 0.55 : 1)

                    Button { selectedTab = .mock } label: {
                        HokenshiActionCard(
                            title: "模擬試験",
                            subtitle: "110問 × 3回",
                            systemImage: "doc.text",
                            accent: LearningSprintTheme.gold
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("分野から解く")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)

                LazyVStack(spacing: 10) {
                    ForEach(Array(HokenshiExamBlueprint.current.subjects.enumerated()), id: \.offset) { index, subject in
                        Button { model.startSubject(subject) } label: {
                            HokenshiCard {
                                HStack(spacing: 12) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(LearningSprintTheme.sans(11, weight: .bold))
                                        .foregroundStyle(LearningSprintTheme.indigo)
                                        .frame(width: 30, height: 30)
                                        .background(LearningSprintTheme.indigoSoft)
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(subject)
                                            .font(LearningSprintTheme.sans(14, weight: .semibold))
                                            .foregroundStyle(LearningSprintTheme.ink)
                                        Text("33問収録")
                                            .font(LearningSprintTheme.sans(10, weight: .medium))
                                            .foregroundStyle(LearningSprintTheme.ink3)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(LearningSprintTheme.ink3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("これまで")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)
                HStack(spacing: 10) {
                    HokenshiMetric(title: "解答", value: "\(model.state.attempts.count)")
                    HokenshiMetric(title: "正答率", value: accuracyText(model.accuracy))
                    HokenshiMetric(title: "苦手", value: "\(model.state.weakQuestions.count)")
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 96)
        }
        .background(Color.clear)
        .accessibilityIdentifier("hokenshi.home")
    }

    private func accuracyText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}

public struct HokenshiMockListView: View {
    @ObservedObject var model: HokenshiProductModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("模擬試験")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                Text("独自問題3回分。各回110問を、午前55・午後55・通し110から選べます。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                Text("一般75問・状況設定35問の構成を再現しています。10分野×11問は周回学習用に均等化した本アプリ独自設計で、実際の国家試験の科目別出題比率を示すものではありません。")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink3)
                    .lineSpacing(3)

                ForEach(1...HokenshiSprintConfiguration.plannedMockExamCount, id: \.self) { number in
                    HokenshiCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("独自模試 第\(number)回")
                                        .font(LearningSprintTheme.serif(19, weight: .semibold))
                                    Text("110問・監査済み")
                                        .font(LearningSprintTheme.sans(12, weight: .medium))
                                        .foregroundStyle(LearningSprintTheme.green)
                                }
                                Spacer()
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(LearningSprintTheme.green)
                            }
                            HStack(spacing: 8) {
                                ForEach(HokenshiMockSegment.allCases, id: \.rawValue) { segment in
                                    Button(segment.rawValue) {
                                        model.startMock(round: number, segment: segment)
                                    }
                                    .font(LearningSprintTheme.sans(11, weight: .bold))
                                    .foregroundStyle(segment == .full ? Color.white : LearningSprintTheme.indigo)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(segment == .full ? LearningSprintTheme.indigo : LearningSprintTheme.indigoSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

public struct HokenshiHistoryView: View {
    @ObservedObject var model: HokenshiProductModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("学習記録")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                HStack(spacing: 10) {
                    HokenshiMetric(title: "解答", value: "\(model.state.attempts.count)")
                    HokenshiMetric(title: "正答", value: "\(model.state.attempts.filter(\.isCorrect).count)")
                    HokenshiMetric(title: "苦手", value: "\(model.state.weakQuestions.count)")
                }
                HokenshiCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("直近5週間")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        LearningSprintHeatmap(values: model.heatmap)
                    }
                }

                Text("分野別")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)
                VStack(spacing: 8) {
                    ForEach(HokenshiExamBlueprint.current.subjects, id: \.self) { subject in
                        HokenshiCard {
                            HStack {
                                Text(subject)
                                    .font(LearningSprintTheme.sans(13, weight: .semibold))
                                Spacer()
                                Text(subjectAccuracyText(subject))
                                    .font(LearningSprintTheme.serif(15, weight: .bold))
                                    .foregroundStyle(LearningSprintTheme.indigo)
                            }
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

    private func subjectAccuracyText(_ subject: String) -> String {
        guard let value = model.subjectAccuracy[subject] else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}

public struct HokenshiSettingsView: View {
    @ObservedObject var model: HokenshiProductModel
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument = HokenshiJSONDocument(data: Data())
    @State private var message: String?

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("設定")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                HokenshiCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1日の目標")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Picker("1日の目標", selection: Binding(
                            get: { model.state.dailyTarget },
                            set: { model.setDailyTarget($0) }
                        )) {
                            ForEach(HokenshiSprintConfiguration.selectableSprintCounts, id: \.self) { count in
                                Text("\(count)問").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                HokenshiCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("文字サイズ")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Picker("文字サイズ", selection: Binding(
                            get: { model.state.textSizeStep },
                            set: { model.setTextSizeStep($0) }
                        )) {
                            Text("標準").tag(0)
                            Text("大").tag(1)
                            Text("特大").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                HokenshiCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("バックアップ")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Text("学習履歴・苦手・設定をJSONで書き出し、同じ保健師アプリへ戻せます。")
                            .font(LearningSprintTheme.sans(12))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        HStack(spacing: 10) {
                            Button("書き出す") { prepareExport() }
                            Button("読み込む") { importing = true }
                        }
                        .buttonStyle(.bordered)
                        .tint(LearningSprintTheme.indigo)
                    }
                }

                HokenshiCard {
                    VStack(alignment: .leading, spacing: 6) {
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
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            importFile(result)
        }
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
        self.data = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct HokenshiCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LearningSprintTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearningSprintTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HokenshiActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HokenshiCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                Text(subtitle)
                    .font(LearningSprintTheme.sans(11, weight: .medium))
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HokenshiMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(LearningSprintTheme.serif(20, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
            Text(title)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif
