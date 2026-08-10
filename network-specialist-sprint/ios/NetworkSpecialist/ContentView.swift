import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LearningStore

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
                            MockView()
                        case .history:
                            HistoryView()
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
