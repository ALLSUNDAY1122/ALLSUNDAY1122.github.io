import SwiftUI

@main
struct EnprintGuardApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color(red: 0.16, green: 0.43, blue: 0.34))
                .onOpenURL { url in
                    Task {
                        await CloudSyncService.shared.handleOpenURL(url)
                        await store.syncNow()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await CloudSyncService.shared.refreshSession()
                        await store.syncNow()
                    }
                }
        }
    }
}
