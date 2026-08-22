import SwiftUI

@main
struct MoisesLane4HostApp: App {
    private let slots = HostModuleSlots.empty

    var body: some Scene {
        WindowGroup {
            HostStatusView(slots: slots)
        }
    }
}
