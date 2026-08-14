import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
