import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var purchases: PremiumPurchaseStore

    var body: some View {
        Group {
            if let error = store.startupError {
                StartupErrorView(message: error)
            } else if let result = store.result {
                ResultScreen(result: result)
            } else if store.session != nil {
                QuizScreen()
            } else {
                VStack(spacing: 0) {
                    Group {
                        switch store.currentTab {
                        case .home:
                            HomeView()
                        case .mock:
                            if purchases.isPremium { MockView() } else { PremiumRequiredView(feature: "年度別25問模試") }
                        case .history:
                            if purchases.isPremium { HistoryView() } else { PremiumRequiredView(feature: "記録・5週間ヒートマップ") }
                        case .settings:
                            SettingsView()
                        }
                    }
                    BottomTabBar(selection: $store.currentTab)
                }
                .background(AppTheme.paper)
            }
        }
        .environment(\.appFontScale, store.fontScale)
        .tint(AppTheme.ai)
        .preferredColorScheme(.light)
    }
}

private struct PremiumRequiredView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var purchases: PremiumPurchaseStore
    let feature: String

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.ai)
                Text("プレミアム機能")
                    .appSerif(22, weight: .bold)
                    .foregroundStyle(AppTheme.ink)
                Text("\(feature)はプレミアムで利用できます。")
                    .appSans(13)
                    .foregroundStyle(AppTheme.ink2)
                    .multilineTextAlignment(.center)
                Button {
                    store.currentTab = .settings
                } label: {
                    Text(purchases.displayPrice.map { "プレミアムを見る（\($0)）" } ?? "プレミアムを見る")
                        .appSans(14, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 300, minHeight: 48)
                        .background(AppTheme.ai)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("premium.openSettings")
            }
            .padding(24)
        }
        .accessibilityIdentifier("premium.required")
    }
}

private struct StartupErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.shu)
                Text("学習データを読み込めません")
                    .appSerif(22, weight: .bold)
                    .foregroundStyle(AppTheme.ink)
                Text(message)
                    .appSans(13)
                    .foregroundStyle(AppTheme.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 420)
        }
        .accessibilityIdentifier("startup.error")
    }
}
