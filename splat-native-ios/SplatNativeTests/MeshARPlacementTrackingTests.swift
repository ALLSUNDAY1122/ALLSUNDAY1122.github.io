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

    func testYawUpdatePreservesGestureDirection() {
        XCTAssertEqual(MeshARPlacementPolicy.updatedYaw(current: 0, gestureDelta: 0.25), -0.25, accuracy: 0.0001)
    }

    func testYawUpdateRemainsBoundedAfterLargeAccumulation() {
        let yaw = MeshARPlacementPolicy.updatedYaw(current: 1_000_000, gestureDelta: -1_000_000)
        XCTAssertTrue(yaw.isFinite)
        XCTAssertLessThanOrEqual(abs(yaw), .pi)
    }

    func testYawUpdateRejectsNonFiniteInput() {
        XCTAssertEqual(MeshARPlacementPolicy.updatedYaw(current: .infinity, gestureDelta: 0.1), 0)
        XCTAssertEqual(MeshARPlacementPolicy.updatedYaw(current: 0.1, gestureDelta: .nan), 0)
    }
}
