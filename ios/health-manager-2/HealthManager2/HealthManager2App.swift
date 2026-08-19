import SwiftUI

@main
struct HealthManager2App: App {
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            LocalWebView(store: store)
                .ignoresSafeArea()
        }
    }
}
