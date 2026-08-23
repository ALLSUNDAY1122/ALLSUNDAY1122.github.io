import AppShell
import SwiftUI

@main
struct ScannerParityHostApp: App {
    private let scannerApp = ScannerParityApp()

    var body: some Scene {
        scannerApp.body
    }
}
