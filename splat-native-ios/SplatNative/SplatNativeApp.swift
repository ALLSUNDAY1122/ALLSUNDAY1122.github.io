import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()
    @StateObject private var meshModel = MeshScanModel()
    @StateObject private var backend = ScanLabBackend()

    var body: some Scene {
        WindowGroup {
            ScanLabShellView()
                .environmentObject(model)
                .environmentObject(meshModel)
                .environmentObject(backend)
                .onOpenURL { url in
                    Task { await backend.handleAuthCallback(url) }
                }
        }
    }
}
