import SwiftUI
import LearningSprintCore

@main
struct KanriEiyoushiSprintApp: App {
    @StateObject private var purchase: PurchaseController
    @StateObject private var store: KanriLearningStore
    init() {
        let purchase=PurchaseController(productID:KanriAppConfig.productID)
        _purchase=StateObject(wrappedValue:purchase)
        _store=StateObject(wrappedValue:KanriLearningStore(purchase:purchase))
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(purchase)
                .dynamicTypeSize(preferredDynamicTypeSize)
                .kanriPurchaseStatus(purchase.state)
                .task{await purchase.refresh()}
        }
    }
    private var preferredDynamicTypeSize: DynamicTypeSize {
        switch store.state.textSizeStep { case 0:return .medium; case 2:return .xLarge; default:return .large }
    }
}
