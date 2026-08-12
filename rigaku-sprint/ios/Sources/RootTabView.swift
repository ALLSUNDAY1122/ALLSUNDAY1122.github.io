import SwiftUI
import LearningSprintCore

private enum RootTab: Hashable {
    case home
    case mock
    case history
    case settings
}

struct RootTabView: View {
    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(RootTab.home)

            MockExamView()
                .tabItem { Label("模試", systemImage: "doc.text") }
                .tag(RootTab.mock)

            HistoryView()
                .tabItem { Label("記録", systemImage: "chart.bar") }
                .tag(RootTab.history)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .tint(LearningSprintTheme.indigo)
    }
}

private struct HomeView: View {
    @State private var destination: StudyDestination?

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        dailyProgressCard
                        studyButton(
                            title: "今日のスプリント",
                            subtitle: "8問・短時間で1セット",
                            systemImage: "figure.run",
                            destination: .daily
                        )
                        studyButton(
                            title: "苦手をつぶす",
                            subtitle: "誤答・わからないを優先",
                            systemImage: "scope",
                            destination: .weak
                        )
                        studyButton(
                            title: "模擬試験",
                            subtitle: "試験回単位で実戦確認",
                            systemImage: "timer",
                            destination: .mock
                        )
                        subjectSection
                        summarySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationDestination(item: $destination) { item in
                StudyPlaceholderView(destination: item)
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

    private var dailyProgressCard: some View {
        HStack(spacing: 16) {
            LearningSprintProgressRing(progress: 0, label: "0/8")
            VStack(alignment: .leading, spacing: 6) {
                Text("今日の学習")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)
                Text("まずは8問。終われば今日の1セット完了。")
                    .font(LearningSprintTheme.serif(17, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LearningSprintTheme.line, lineWidth: 1)
        )
        .accessibilityIdentifier("home.progress")
    }

    private func studyButton(
        title: String,
        subtitle: String,
        systemImage: String,
        destination: StudyDestination
    ) -> some View {
        Button {
            self.destination = destination
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(LearningSprintTheme.sans(16, weight: .bold))
                    Text(subtitle)
                        .font(LearningSprintTheme.sans(12, weight: .medium))
                        .foregroundStyle(LearningSprintTheme.ink2)
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
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearningSprintTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.\(destination.rawValue)")
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野から解く")
                .font(LearningSprintTheme.sans(16, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink)
            ForEach(RigakuAppConfiguration.generalSubjects, id: \.self) { subject in
                Button {
                    destination = .subject(subject)
                } label: {
                    HStack {
                        Text(subject)
                            .font(LearningSprintTheme.sans(14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(LearningSprintTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("home.subjects")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで")
                .font(LearningSprintTheme.sans(16, weight: .bold))
            HStack(spacing: 10) {
                SummaryCell(label: "解答", value: "0")
                SummaryCell(label: "正答率", value: "—")
                SummaryCell(label: "苦手", value: "0")
            }
        }
    }
}

private struct SummaryCell: View {
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

private enum StudyDestination: Hashable, Identifiable {
    case daily
    case weak
    case mock
    case subject(String)

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .daily: return "daily"
        case .weak: return "weak"
        case .mock: return "mock"
        case .subject(let name): return "subject-\(name)"
        }
    }

    var title: String {
        switch self {
        case .daily: return "今日のスプリント"
        case .weak: return "苦手をつぶす"
        case .mock: return "模擬試験"
        case .subject(let name): return name
        }
    }
}

private struct StudyPlaceholderView: View {
    let destination: StudyDestination

    var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            VStack(spacing: 16) {
                Text(destination.title)
                    .font(LearningSprintTheme.serif(24, weight: .bold))
                LearningSprintMemoryBlock("問題本文は権利監査と3回分構成監査を通過したデータだけを読み込みます。")
                Text("ネイティブ学習エンジン接続前の開発ゲート")
                    .font(LearningSprintTheme.sans(13, weight: .medium))
                    .foregroundStyle(LearningSprintTheme.ink2)
            }
            .padding(18)
            .frame(maxWidth: 520)
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MockExamView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("模擬試験")
                            .font(LearningSprintTheme.serif(26, weight: .bold))
                        Text("公式構成の監査が終わった試験回だけ本番形式を有効化します。")
                            .font(LearningSprintTheme.sans(13))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        ForEach(RigakuAppConfiguration.examRounds) { exam in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("第\(exam.round)回")
                                        .font(LearningSprintTheme.serif(20, weight: .bold))
                                    Text(questionCountLabel(exam))
                                        .font(LearningSprintTheme.sans(12, weight: .medium))
                                        .foregroundStyle(LearningSprintTheme.ink2)
                                }
                                Spacer()
                                Image(systemName: exam.officialQuestionCount == nil ? "lock" : "checkmark.seal")
                                    .foregroundStyle(exam.officialQuestionCount == nil ? LearningSprintTheme.gold : LearningSprintTheme.green)
                            }
                            .padding(16)
                            .background(LearningSprintTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("mock.screen")
    }

    private func questionCountLabel(_ exam: RigakuAppConfiguration.ExamRound) -> String {
        if let count = exam.officialQuestionCount {
            return "公式PDF確認済み：\(count)問"
        }
        return "公式PDF構成を監査中・件数未固定"
    }
}

private struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("学習記録")
                            .font(LearningSprintTheme.serif(26, weight: .bold))
                        HStack(spacing: 10) {
                            SummaryCell(label: "解答", value: "0")
                            SummaryCell(label: "正答率", value: "—")
                            SummaryCell(label: "苦手", value: "0")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("直近5週間")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            LearningSprintHeatmap(values: [:])
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
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("history.screen")
    }
}

private struct SettingsView: View {
    @State private var dailyTarget = RigakuAppConfiguration.defaultDailyTarget
    @State private var textSize = 1

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                Form {
                    Section("1日の目標") {
                        Picker("問題数", selection: $dailyTarget) {
                            ForEach(RigakuAppConfiguration.allowedDailyTargets, id: \.self) { value in
                                Text("\(value)問").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("文字サイズ") {
                        Picker("文字サイズ", selection: $textSize) {
                            Text("小").tag(0)
                            Text("標準").tag(1)
                            Text("大").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("データ") {
                        Button("バックアップを書き出す") {}
                            .disabled(true)
                        Text("学習状態ストア接続後に有効化")
                            .font(.caption)
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }
                    Section("アプリ") {
                        LabeledContent("コンテンツ版", value: RigakuAppConfiguration.contentVersion)
                        LabeledContent("Bundle ID", value: RigakuAppConfiguration.runtimeBundleIdentifier ?? "要確認")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
        }
        .accessibilityIdentifier("settings.screen")
    }
}
