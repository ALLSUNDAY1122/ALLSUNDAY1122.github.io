import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()
    @StateObject private var meshModel = MeshScanModel()

    var body: some Scene {
        WindowGroup {
            ScanHomeView()
                .environmentObject(model)
                .environmentObject(meshModel)
        }
    }
}
