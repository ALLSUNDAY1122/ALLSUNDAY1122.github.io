#if canImport(SwiftUI) && canImport(PhotosUI)
import PhotosUI
import SwiftUI
import ProductFlow

public struct ScannerParityApp: App {
    private let driver: any ProductPipelineDriving
    private let reviewWorkflowFactory: @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow

    public init(
        driver: any ProductPipelineDriving = ProductionScannerRuntime.makeDriver(),
        reviewWorkflowFactory: @escaping @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow = { RecoveryProductReviewWorkflow(items: $0) }
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
