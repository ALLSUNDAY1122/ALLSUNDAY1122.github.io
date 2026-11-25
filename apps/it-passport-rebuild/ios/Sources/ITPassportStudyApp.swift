import SwiftUI

@main
@MainActor
struct ITPassportStudyApp: App {
    @StateObject private var premium = PremiumStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(premium)
                .task { await premium.refresh() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { Task { await premium.refreshEntitlements() } }
                }
        }
    }
}
