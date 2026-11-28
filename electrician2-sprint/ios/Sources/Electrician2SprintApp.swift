import SwiftUI

@main
struct Electrician2SprintApp: App {
    @StateObject private var model = StudyModel()
    @StateObject private var premium = PremiumStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).environmentObject(premium).preferredColorScheme(.light)
        }
    }
}
