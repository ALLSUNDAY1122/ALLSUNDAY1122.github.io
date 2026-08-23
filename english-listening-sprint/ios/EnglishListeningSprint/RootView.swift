import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var tab = 0

    var body: some View {
        Group {
            if store.currentLesson != nil {
                LessonView()
            } else {
                TabView(selection: $tab) {
                    HomeView().tabItem { Label("ホーム", systemImage: "house.fill") }.tag(0)
                    LibraryView().tabItem { Label("レッスン", systemImage: "headphones") }.tag(1)
                    LearningProgressView().tabItem { Label("記録", systemImage: "chart.bar.fill") }.tag(2)
                    SettingsView().tabItem { Label("設定", systemImage: "gearshape.fill") }.tag(3)
                }
                .tint(SprintTheme.accent)
            }
        }
        .background(SprintTheme.background.ignoresSafeArea())
    }
}

enum SprintTheme {
    static let background = Color(red: 9/255, green: 19/255, blue: 31/255)
    static let panel = Color(red: 21/255, green: 38/255, blue: 58/255)
    static let panel2 = Color(red: 30/255, green: 51/255, blue: 75/255)
    static let accent = Color(red: 1, green: 159/255, blue: 67/255)
    static let muted = Color(red: 174/255, green: 187/255, blue: 208/255)
}
