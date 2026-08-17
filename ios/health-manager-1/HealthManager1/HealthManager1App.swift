import SwiftUI

@main
struct HealthManager1App: App {
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
