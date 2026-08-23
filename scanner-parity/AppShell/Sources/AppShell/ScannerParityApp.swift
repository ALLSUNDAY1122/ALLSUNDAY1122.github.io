#if canImport(SwiftUI) && canImport(PhotosUI)
import PhotosUI
import SwiftUI
import ProductFlow

@MainActor
public struct ScannerParityApp: App {
    private let driver: any ProductPipelineDriving
    private let reviewWorkflowFactory: @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow

    public init() {
        self.driver = GoldenHardenedScannerRuntime.makeDriver()
        self.reviewWorkflowFactory = { RecoveryProductReviewWorkflow(items: $0) }
    }

    public init(
        driver: any ProductPipelineDriving,
        reviewWorkflowFactory: @escaping @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow
    ) {
        self.driver = driver
        self.reviewWorkflowFactory = reviewWorkflowFactory
    }

    public var body: some Scene {
        WindowGroup {
            ScannerParityRootView(
                driver: driver,
                reviewWorkflowFactory: reviewWorkflowFactory
            )
        }
    }
}
#endif
