import SwiftUI

@main
struct HealthManager2App: App {
    var body: some Scene {
        WindowGroup {
            LocalWebView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
