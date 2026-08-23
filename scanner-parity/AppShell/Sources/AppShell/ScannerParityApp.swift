#if canImport(SwiftUI) && canImport(PhotosUI)
import PhotosUI
import SwiftUI

public struct ScannerParityApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            ScannerParityRootView()
        }
    }
}
#endif
