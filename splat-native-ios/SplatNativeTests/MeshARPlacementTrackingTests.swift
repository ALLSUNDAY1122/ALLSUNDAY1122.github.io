import ARKit
import XCTest
@testable import SplatNative

final class MeshARPlacementTrackingTests: XCTestCase {
    func testNormalTrackingAllowsPlacement() {
        XCTAssertTrue(MeshARPlacementView.Coordinator.isStableTracking(.normal))
    }

    func testLimitedTrackingRejectsPlacement() {
        XCTAssertFalse(MeshARPlacementView.Coordinator.isStableTracking(.limited(.initializing)))
        XCTAssertFalse(MeshARPlacementView.Coordinator.isStableTracking(.limited(.excessiveMotion)))
        XCTAssertFalse(MeshARPlacementView.Coordinator.isStableTracking(.limited(.insufficientFeatures)))
    }

    func testUnavailableTrackingRejectsPlacement() {
        XCTAssertFalse(MeshARPlacementView.Coordinator.isStableTracking(.notAvailable))
    }
}
