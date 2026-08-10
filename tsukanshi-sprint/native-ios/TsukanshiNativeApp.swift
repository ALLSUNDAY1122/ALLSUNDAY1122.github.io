import SwiftUI

@main
struct TsukanshiNativeApp: App {
    @StateObject private var model = TsukanshiAppModel()

    var body: some Scene {
        WindowGroup {
            TsukanshiRootView(model: model)
                .preferredColorScheme(.light)
        }
    }
}
