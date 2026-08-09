import SwiftUI

@main
struct Otsu4SprintApp: App {
    @StateObject private var purchaseStore = Otsu4PurchaseStore()

    var body: some Scene {
        WindowGroup {
            Otsu4LearningView(purchaseStore: purchaseStore)
        }
    }
}
