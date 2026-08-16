import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()
    @StateObject private var meshModel = MeshScanModel()
    @StateObject private var backend = ScanLabBackend()

    var body: some Scene {
        WindowGroup {
            ScanLabDiscoverShellView()
                .environmentObject(model)
                .environmentObject(meshModel)
                .environmentObject(backend)
        }
    }
}
