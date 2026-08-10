import SwiftUI
import LearningSprintCore

@main
struct KanriEiyoushiSprintApp: App {
    @StateObject private var purchase: PurchaseController
    @StateObject private var store: KanriLearningStore

    init() {
        let purchase = PurchaseController(productID: KanriAppConfig.productID)
        _purchase = StateObject(wrappedValue: purchase)
        _store = StateObject(wrappedValue: KanriLearningStore(purchase: purchase))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(purchase)
                .task { await purchase.refresh() }
        }
    }
}
