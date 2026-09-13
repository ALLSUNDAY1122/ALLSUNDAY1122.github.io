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

    func testEyeClampsFinitePitchToViewerGestureEnvelope() {
        let center = SIMD3<Float>(1, -2, 3)
        let clamped = SplatCameraGeometry.eye(
            center: center,
            distance: 4,
            yaw: 0.7,
            pitch: SplatCameraGeometry.maximumOrbitPitch
        )
        let oversized = SplatCameraGeometry.eye(
            center: center,
            distance: 4,
            yaw: 0.7,
            pitch: Float.pi
        )
        let undersized = SplatCameraGeometry.eye(
            center: center,
            distance: 4,
            yaw: 0.7,
            pitch: -Float.pi
        )
        let lowerClamp = SplatCameraGeometry.eye(
            center: center,
            distance: 4,
            yaw: 0.7,
            pitch: -SplatCameraGeometry.maximumOrbitPitch
        )

        XCTAssertEqual(oversized.x, clamped.x, accuracy: 0.0001)
        XCTAssertEqual(oversized.y, clamped.y, accuracy: 0.0001)
        XCTAssertEqual(oversized.z, clamped.z, accuracy: 0.0001)
        XCTAssertEqual(undersized.x, lowerClamp.x, accuracy: 0.0001)
        XCTAssertEqual(undersized.y, lowerClamp.y, accuracy: 0.0001)
        XCTAssertEqual(undersized.z, lowerClamp.z, accuracy: 0.0001)
    }

    func testEyeKeepsLargeFiniteYawInsidePeriodicOrbit() {
        let center = SIMD3<Float>(0.5, -1, 2)
        let yaw: Float = 0.37 + 4_096 * (2 * .pi)
        let reducedYaw = yaw.truncatingRemainder(dividingBy: 2 * .pi)
        let large = SplatCameraGeometry.eye(center: center, distance: 3, yaw: yaw, pitch: 0.2)
        let reduced = SplatCameraGeometry.eye(center: center, distance: 3, yaw: reducedYaw, pitch: 0.2)

        XCTAssertEqual(large.x, reduced.x, accuracy: 0.0001)
        XCTAssertEqual(large.y, reduced.y, accuracy: 0.0001)
        XCTAssertEqual(large.z, reduced.z, accuracy: 0.0001)
    }

    func testRotationZKeepsLargeFiniteAnglePeriodic() {
        let angle: Float = -0.42 + 8_192 * (2 * .pi)
        let reduced = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let largeMatrix = SplatCameraGeometry.rotationZ(angle)
        let reducedMatrix = SplatCameraGeometry.rotationZ(reduced)

        for column in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(largeMatrix[column][row], reducedMatrix[column][row], accuracy: 0.0001)
            }
        }
    }
}
