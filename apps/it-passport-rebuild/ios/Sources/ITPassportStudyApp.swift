import SwiftUI

@main
@MainActor
struct ITPassportStudyApp: App {
    @StateObject private var premium = PremiumStore()
    @StateObject private var records = StudyRecordStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .environmentObject(premium)
                .environmentObject(records)
                .task { await premium.refresh() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { Task { await premium.refreshEntitlements() } }
                }
        }
    }
}
