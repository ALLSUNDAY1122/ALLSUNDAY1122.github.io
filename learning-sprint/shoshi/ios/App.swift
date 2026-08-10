import SwiftUI

@main
struct ShoshiSprintApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(store)
        }
    }
}
