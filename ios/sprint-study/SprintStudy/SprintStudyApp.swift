import SwiftUI

@main
struct SprintStudyApp: App {
    var body: some Scene {
        WindowGroup {
            LocalWebView()
                .ignoresSafeArea()
        }
    }
}
