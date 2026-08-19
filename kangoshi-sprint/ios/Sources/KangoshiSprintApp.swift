import SwiftUI
import LearningSprintCore

@main
struct KangoshiSprintApp: App {
    @StateObject private var model = KangoshiAppModel()
    @StateObject private var purchase = PurchaseController(productIDs: [
        "jp.allsunday1122.kangoshi.monthly",
        "jp.allsunday1122.kangoshi.lifetime"
    ])

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(purchase)
                .preferredColorScheme(.light)
        }
    }
}
