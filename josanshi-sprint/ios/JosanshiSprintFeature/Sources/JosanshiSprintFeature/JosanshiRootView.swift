import SwiftUI
import LearningSprintCore

@MainActor
public struct JosanshiRootView: View {
    @StateObject private var model: JosanshiDashboardModel

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
        .alert("問題データを監査中", isPresented: $model.isContentGatePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("本番用の独自問題は、330問の件数・重複・正答・一次根拠・権利監査をPASSしてから有効化します。")
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
                    Text("令和5年版出題基準を現行ベースラインとして監査")
                        .font(LearningSprintTheme.sans(13))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                HStack(spacing: 16) {
                    LearningSprintProgressRing(progress: 0, label: "0 / \(model.dailyTarget)")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日の学習")
                            .font(LearningSprintTheme.serif(20, weight: .semibold))
                        Text("標準は8問。4 / 8 / 16問から目標を選べます。")
                            .font(LearningSprintTheme.sans(14))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(LearningSprintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(action: model.requestStandardSprint) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("標準スプリント")
                                .font(LearningSprintTheme.serif(20, weight: .bold))
                            Text("8問を短時間で反復")
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
                .accessibilityIdentifier("start-standard-sprint")

                VStack(alignment: .leading, spacing: 10) {
                    Text("分野別演習")
                        .font(LearningSprintTheme.serif(20, weight: .semibold))
                    ForEach(JosanshiExamConfiguration.subjects, id: \.self) { subject in
                        Button {
                            model.requestSubjectPractice(subject)
                        } label: {
                            HStack {
                                Text(subject)
                                    .font(LearningSprintTheme.sans(16, weight: .semibold))
                                    .foregroundStyle(LearningSprintTheme.ink)
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
                        .accessibilityLabel("\(subject)を演習")
                    }
                }

                LearningSprintMemoryBlock("根拠の確認日を問題単位で持ち、古い制度・統計・医療情報をそのまま残さない。")
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
                Text("最新確認済みの第109回は午前55問・午後55問。製品版は直接転載ではなく、同規模の独自模試を3回分作成します。")
                    .font(LearningSprintTheme.sans(15))
                    .foregroundStyle(LearningSprintTheme.ink2)

                ForEach(1...JosanshiExamConfiguration.originalMockSetCount, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("独自模試 \(index)")
                            .font(LearningSprintTheme.serif(20, weight: .semibold))
                        Text("110問・監査完了後に解放")
                            .font(LearningSprintTheme.sans(14))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Text("直近5週間")
                    .font(LearningSprintTheme.sans(15, weight: .semibold))
                LearningSprintHeatmap(values: [:])
                Text("問題データ結線後、正答率・分野別進捗・苦手問題・連続正解解除を LearningSprintCore の履歴に接続します。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
            }
            .padding(18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
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
                LabeledContent("最新確認試験", value: "第109回")
                LabeledContent("本試験問題数", value: "110問")
                LabeledContent("独自問題目標", value: model.productionQuestionTargetText)
                LabeledContent("出題基準", value: "令和5年版")
            }

            Section("本番識別子") {
                LabeledContent("Bundle ID", value: "要確認")
                LabeledContent("ASC App ID", value: "要確認")
                LabeledContent("IAP Product ID", value: "要確認")
            }

            Section("バックアップ") {
                Button("JSONを書き出す") {}
                    .disabled(true)
                Button("JSONから復元") {}
                    .disabled(true)
                Text("LearningStateStore 接続後に有効化")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
    }
}
