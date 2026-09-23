import SwiftUI

@main
struct HealthManager2App: App {
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            // Keep the WebView inside the native safe area. The previous
            // ignoresSafeArea() allowed sticky quiz/history headers to render
            // underneath the iOS status bar on real devices.
            LocalWebView(store: store)
        }
    }
}
