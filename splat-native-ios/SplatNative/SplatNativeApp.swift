import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()
    @StateObject private var meshModel = MeshScanModel()

    var body: some Scene {
        WindowGroup {
            RootScanView()
                .environmentObject(model)
                .environmentObject(meshModel)
        }
    }
}
