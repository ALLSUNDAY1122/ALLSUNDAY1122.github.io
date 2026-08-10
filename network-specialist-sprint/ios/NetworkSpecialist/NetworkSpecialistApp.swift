import SwiftUI

@main
struct NetworkSpecialistApp: App {
    @StateObject private var store = LearningStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
