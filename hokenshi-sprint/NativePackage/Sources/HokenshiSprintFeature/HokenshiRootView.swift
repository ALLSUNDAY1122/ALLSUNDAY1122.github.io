#if canImport(SwiftUI)
import SwiftUI
import LearningSprintCore

public struct HokenshiRootView: View {
    @State private var selectedTab: Tab = .home

    public init() {}

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            TabView(selection: $selectedTab) {
                HokenshiHomeView()
                    .tabItem { Label("ホーム", systemImage: "house.fill") }
                    .tag(Tab.home)
                HokenshiMockListView()
                    .tabItem { Label("模試", systemImage: "doc.text.fill") }
                    .tag(Tab.mock)
                HokenshiHistoryView()
                    .tabItem { Label("記録", systemImage: "chart.bar.fill") }
                    .tag(Tab.history)
                HokenshiSettingsView()
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
            .tint(LearningSprintTheme.indigo)
        }
    }

    private enum Tab: Hashable {
        case home, mock, history, settings
    }
}

public struct HokenshiHomeView: View {
    public init() {}

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

                HokenshiCard {
                    HStack(spacing: 18) {
                        LearningSprintProgressRing(progress: 0, label: "0 / 8")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("今日の学習")
                                .font(LearningSprintTheme.sans(13, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.ink2)
                            Text("8問で1スプリント")
                                .font(LearningSprintTheme.serif(20, weight: .semibold))
                                .foregroundStyle(LearningSprintTheme.ink)
                            Text("短く区切って、毎日積み上げる")
                                .font(LearningSprintTheme.sans(12))
                                .foregroundStyle(LearningSprintTheme.ink3)
                        }
                        Spacer(minLength: 0)
                    }
                }

                Text("今日のスプリント")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)
                HokenshiActionCard(
                    title: "8問を解く",
                    subtitle: "標準スプリント",
                    systemImage: "figure.run",
                    accent: LearningSprintTheme.indigo
                )

                HStack(spacing: 12) {
                    HokenshiActionCard(
                        title: "苦手をつぶす",
                        subtitle: "誤答・わからない",
                        systemImage: "target",
                        accent: LearningSprintTheme.vermilion
                    )
                    HokenshiActionCard(
                        title: "模擬試験",
                        subtitle: "110問 × 3回",
                        systemImage: "doc.text",
                        accent: LearningSprintTheme.gold
                    )
                }

                Text("分野から解く")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)

                LazyVStack(spacing: 10) {
                    ForEach(Array(HokenshiExamBlueprint.current.subjects.enumerated()), id: \.offset) { index, subject in
                        HokenshiCard {
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", index + 1))
                                    .font(LearningSprintTheme.sans(11, weight: .bold))
                                    .foregroundStyle(LearningSprintTheme.indigo)
                                    .frame(width: 30, height: 30)
                                    .background(LearningSprintTheme.indigoSoft)
                                    .clipShape(Circle())
                                Text(subject)
                                    .font(LearningSprintTheme.sans(14, weight: .semibold))
                                    .foregroundStyle(LearningSprintTheme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(LearningSprintTheme.ink3)
                            }
                        }
                    }
                }

                Text("これまで")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink2)
                HStack(spacing: 10) {
                    HokenshiMetric(title: "解答", value: "0")
                    HokenshiMetric(title: "正答率", value: "—")
                    HokenshiMetric(title: "苦手", value: "0")
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
}

public struct HokenshiMockListView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("模擬試験")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                Text("本試験と同じ110問構成で、独自問題を3回分用意する設計です。問題監査PASS後に解放します。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)

                ForEach(1...HokenshiSprintConfiguration.plannedMockExamCount, id: \.self) { number in
                    HokenshiCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("独自模試 第\(number)回")
                                    .font(LearningSprintTheme.serif(19, weight: .semibold))
                                    .foregroundStyle(LearningSprintTheme.ink)
                                Text("110問・コンテンツ監査待ち")
                                    .font(LearningSprintTheme.sans(12, weight: .medium))
                                    .foregroundStyle(LearningSprintTheme.ink3)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(LearningSprintTheme.gold)
                                .accessibilityLabel("監査完了まで利用不可")
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
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("学習記録")
                    .font(LearningSprintTheme.serif(28, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink)
                HStack(spacing: 10) {
                    HokenshiMetric(title: "解答", value: "0")
                    HokenshiMetric(title: "正答", value: "0")
                    HokenshiMetric(title: "苦手", value: "0")
                }
                HokenshiCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("直近5週間")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        LearningSprintHeatmap(values: [:])
                    }
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(18)
            .padding(.bottom, 90)
        }
        .accessibilityIdentifier("hokenshi.history")
    }
}

public struct HokenshiSettingsView: View {
    @State private var dailyTarget = HokenshiSprintConfiguration.standardSprintCount

    public init() {}

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
                        Picker("1日の目標", selection: $dailyTarget) {
                            ForEach(HokenshiSprintConfiguration.selectableSprintCounts, id: \.self) { count in
                                Text("\(count)問").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                HokenshiCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("バックアップ")
                            .font(LearningSprintTheme.sans(13, weight: .bold))
                        Text("JSON書き出し・読み込みはアプリターゲット統合時に LearningSprintCore の状態保存へ接続します。")
                            .font(LearningSprintTheme.sans(13))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(18)
            .padding(.bottom, 90)
        }
        .accessibilityIdentifier("hokenshi.settings")
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
