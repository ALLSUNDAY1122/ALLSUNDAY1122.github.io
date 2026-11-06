import SwiftUI

@main
struct YobiTantouSprintApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(store)
                .task { await store.refresh() }
        }
    }
}
