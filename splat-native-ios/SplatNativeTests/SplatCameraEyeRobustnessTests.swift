import simd
import XCTest

final class SplatCameraEyeRobustnessTests: XCTestCase {
    func testEyeFallsBackForNonFiniteOrbitScalars() {
        let eye = SplatCameraGeometry.eye(
            center: SIMD3<Float>(1, 2, 3),
            distance: .nan,
            yaw: .infinity,
            pitch: -.infinity
        )

        XCTAssertTrue(eye.x.isFinite)
        XCTAssertTrue(eye.y.isFinite)
        XCTAssertTrue(eye.z.isFinite)
        XCTAssertEqual(eye.x, 1, accuracy: 0.0001)
        XCTAssertEqual(eye.y, 2, accuracy: 0.0001)
        XCTAssertEqual(eye.z, 5.5, accuracy: 0.0001)
    }

    func testEyeFallsBackWhenFiniteComponentsOverflowResult() {
        let huge = Float.greatestFiniteMagnitude
        let eye = SplatCameraGeometry.eye(
            center: SIMD3<Float>(huge, huge, huge),
            distance: huge,
            yaw: .pi / 4,
            pitch: .pi / 4
        )

        XCTAssertTrue(eye.x.isFinite)
        XCTAssertTrue(eye.y.isFinite)
        XCTAssertTrue(eye.z.isFinite)
    }
}
