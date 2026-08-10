import SwiftUI

@main
struct PharmacistSprintApp: App {
    @StateObject private var learning = LearningStore()
    @StateObject private var storeKit = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(learning)
                .environmentObject(storeKit)
                .tint(.sprintAi)
        }
    }
}
