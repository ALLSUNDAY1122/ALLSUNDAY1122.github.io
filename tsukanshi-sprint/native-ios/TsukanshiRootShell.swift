import SwiftUI
import LearningSprintCore

private enum TsukanshiTab: Hashable { case home, mock, records, settings }

struct TsukanshiRootView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject private var purchase: PurchaseController
    @State private var selectedTab: TsukanshiTab = .home
    @State private var showPaywall = false

    init(model: TsukanshiAppModel) {
        self.model = model
        self.purchase = model.purchaseController
    }

    var body: some View {
        Group {
            if let error = model.loadError {
                loadFailure(error)
            } else if model.content == nil {
                ZStack {
                    LearningSprintPaperBackground()
                    ProgressView("監査済み問題を読み込み中")
                }
            } else {
                TabView(selection: $selectedTab) {
                    TsukanshiHomeNativeView(model: model) { selectedTab = .mock }
                        .tag(TsukanshiTab.home)
                        .tabItem { Label("ホーム", systemImage: "house") }
                    TsukanshiMockNativeView(model: model)
                        .tag(TsukanshiTab.mock)
                        .tabItem { Label("模試", systemImage: "doc.text") }
                    TsukanshiRecordsNativeView(model: model)
                        .tag(TsukanshiTab.records)
                        .tabItem { Label("記録", systemImage: "chart.bar") }
                    TsukanshiSettingsNativeView(model: model) { showPaywall = true }
                        .tag(TsukanshiTab.settings)
                        .tabItem { Label("設定", systemImage: "gearshape") }
                }
                .tint(LearningSprintTheme.indigo)
                .dynamicTypeSize(dynamicType)
            }
        }
        .fullScreenCover(item: $model.activeSession) { session in
            TsukanshiStudyFlowView(model: model, session: session)
                .dynamicTypeSize(dynamicType)
        }
        .sheet(isPresented: $showPaywall) {
            TsukanshiPaywallNativeView(purchase: purchase)
        }
        .alert("お知らせ", isPresented: Binding(
            get: { model.transientMessage != nil },
            set: { if !$0 { model.transientMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.transientMessage = nil }
        } message: {
            Text(model.transientMessage ?? "")
        }
    }

    private var dynamicType: DynamicTypeSize {
        switch model.state.textSizeStep {
        case 0: return .medium
        case 2: return .xxLarge
        default: return .large
        }
    }

    private func loadFailure(_ error: String) -> some View {
        ZStack {
            LearningSprintPaperBackground()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34))
                    .foregroundStyle(LearningSprintTheme.vermilion)
                Text("問題データを読み込めません")
                    .font(LearningSprintTheme.serif(22, weight: .bold))
                Text(error)
                    .font(LearningSprintTheme.sans(13))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 520)
        }
    }
}
