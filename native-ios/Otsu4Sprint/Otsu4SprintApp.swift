import SwiftUI

@main
struct Otsu4SprintApp: App {
    private var isAccessibilityTextUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("OTS4_UI_TEST_ACCESSIBILITY3")
    }

    var body: some Scene {
        WindowGroup {
            if isAccessibilityTextUITest {
                Otsu4FinalRootView()
                    .dynamicTypeSize(.accessibility3)
            } else {
                Otsu4FinalRootView()
            }
        }
    }
}
