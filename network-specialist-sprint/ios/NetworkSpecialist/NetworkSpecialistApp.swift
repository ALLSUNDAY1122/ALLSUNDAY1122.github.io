import SwiftUI

@main
struct NetworkSpecialistApp: App {
    @StateObject private var store = LearningStore()
    @StateObject private var purchases = PremiumPurchaseStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(purchases)
                .task {
                    await purchases.prepare()
                }
        }
    }
}
