import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()
    @StateObject private var backend = ScanLabBackend()

    var body: some Scene {
        WindowGroup {
            ScanLabShellView()
                .environmentObject(model)
                .environmentObject(backend)
        }
    }
}
