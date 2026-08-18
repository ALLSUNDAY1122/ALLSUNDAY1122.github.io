import SwiftUI

@main
struct SplatNativeApp: App {
    @StateObject private var model = ScanModel()
    @StateObject private var meshModel = MeshScanModel()
    @StateObject private var backend = ScanLabBackend()
    @StateObject private var passwordRecovery = ScanLabPasswordRecoveryCoordinator()

    var body: some Scene {
        WindowGroup {
            ScanLabShellView()
                .environmentObject(model)
                .environmentObject(meshModel)
                .environmentObject(backend)
                .environmentObject(passwordRecovery)
                .onOpenURL { url in
                    Task { @MainActor in
                        if await passwordRecovery.handleAuthCallbackIfNeeded(url, backend: backend) {
                            return
                        }
                        await backend.handleAuthCallback(url)
                    }
                }
        }
    }
}
