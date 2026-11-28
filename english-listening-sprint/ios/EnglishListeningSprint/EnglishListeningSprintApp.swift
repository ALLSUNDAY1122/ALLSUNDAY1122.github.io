import SwiftUI

@main
struct EnglishListeningSprintApp: App {
    @StateObject private var store = LearningStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AudioSession.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task { await store.refreshEntitlements(retries: 4) }
                    }
                }
        }
    }
}
