import SwiftUI

@main
struct KanteishiShortAnswerApp: App {
    @StateObject private var store = LearningStore()
    @StateObject private var purchases = PremiumPurchaseStore(productID: nil)

    var body: some Scene {
        WindowGroup {
            KanteishiShortAnswerRootView()
                .environmentObject(store)
                .environmentObject(purchases)
                .task { await purchases.prepare() }
        }
    }
}
