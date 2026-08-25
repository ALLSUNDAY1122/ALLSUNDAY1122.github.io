import SwiftUI

@main
struct PharmacistSprintApp: App {
    @StateObject private var learning = LearningStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(learning)
                .tint(.sprintAi)
        }
    }
}
