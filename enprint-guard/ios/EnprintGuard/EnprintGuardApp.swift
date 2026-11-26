import SwiftUI

@main
struct EnprintGuardApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color(red: 0.16, green: 0.43, blue: 0.34))
        }
    }
}
