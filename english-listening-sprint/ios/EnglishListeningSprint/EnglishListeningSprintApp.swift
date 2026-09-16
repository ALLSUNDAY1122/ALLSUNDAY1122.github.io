import SwiftUI

@main
struct EnglishListeningSprintApp: App {
    @StateObject private var store = LearningStore()

    init() {
        AudioSession.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
