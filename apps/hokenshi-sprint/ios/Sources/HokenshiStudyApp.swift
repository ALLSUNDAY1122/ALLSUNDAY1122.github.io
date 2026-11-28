import SwiftUI
import LearningSprintCore

@main
struct HokenshiStudyApp: App {
    @StateObject private var model = HokenshiAppModel()
    @StateObject private var purchase = PurchaseController(productIDs: [
        "jp.allsunday1122.hokenshisprint.premium.monthly",
        "jp.allsunday1122.hokenshisprint.premium.lifetime"
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
