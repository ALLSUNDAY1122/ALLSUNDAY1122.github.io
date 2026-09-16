import ARKit
import XCTest

final class MeshARPlacementTrackingTests: XCTestCase {
    func testNormalTrackingAllowsPlacement() {
        XCTAssertTrue(MeshARPlacementPolicy.isStableTracking(.normal))
    }

    func testLimitedTrackingRejectsPlacement() {
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.limited(.initializing)))
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.limited(.excessiveMotion)))
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.limited(.insufficientFeatures)))
    }

    func testUnavailableTrackingRejectsPlacement() {
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.notAvailable))
    }
}
