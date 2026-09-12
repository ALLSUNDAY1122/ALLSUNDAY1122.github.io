import simd
import XCTest

final class SplatCameraDistanceSafetyTests: XCTestCase {
    func testEyeClampsNegativePersistedDistanceInsteadOfFlippingOrbit() {
        let center = SIMD3<Float>(1, 2, 3)
        let eye = SplatCameraGeometry.eye(
            center: center,
            distance: -5,
            yaw: 0,
            pitch: 0
        )

        XCTAssertEqual(eye.x, center.x, accuracy: 0.0001)
        XCTAssertEqual(eye.y, center.y, accuracy: 0.0001)
        XCTAssertEqual(eye.z, center.z + 0.35, accuracy: 0.0001)
    }

    func testEyeClampsExtremeFinitePersistedDistance() {
        let center = SIMD3<Float>(-2, 0.5, 4)
        let eye = SplatCameraGeometry.eye(
            center: center,
            distance: Float.greatestFiniteMagnitude,
            yaw: 0,
            pitch: 0
        )

        XCTAssertTrue(eye.x.isFinite)
        XCTAssertTrue(eye.y.isFinite)
        XCTAssertTrue(eye.z.isFinite)
        XCTAssertEqual(eye.z, center.z + 60, accuracy: 0.0001)
    }
}
