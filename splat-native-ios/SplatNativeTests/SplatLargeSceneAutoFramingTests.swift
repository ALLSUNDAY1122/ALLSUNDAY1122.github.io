import SplatIO
import simd
import XCTest

final class SplatLargeSceneAutoFramingTests: XCTestCase {
    func testLargeSceneInitialFramingUsesAvailableCameraEnvelope() {
        let points = [
            makePoint(position: SIMD3<Float>(-30, 0, 0)),
            makePoint(position: SIMD3<Float>(30, 0, 0)),
            makePoint(position: SIMD3<Float>(0, -30, 0)),
            makePoint(position: SIMD3<Float>(0, 30, 0)),
            makePoint(position: SIMD3<Float>(0, 0, -30)),
            makePoint(position: SIMD3<Float>(0, 0, 30))
        ]

        let framing = SplatCameraGeometry.robustFraming(for: points)

        XCTAssertGreaterThan(framing.distance, 60)
        XCTAssertEqual(framing.distance, 84, accuracy: 0.001)
        XCTAssertLessThanOrEqual(framing.distance, SplatCameraGeometry.maximumCameraDistance)
    }

    func testExtremeSceneInitialFramingStillHonorsFiniteSafetyCeiling() {
        let points = [
            makePoint(position: SIMD3<Float>(-1_000, 0, 0)),
            makePoint(position: SIMD3<Float>(1_000, 0, 0)),
            makePoint(position: SIMD3<Float>(0, -1_000, 0)),
            makePoint(position: SIMD3<Float>(0, 1_000, 0)),
            makePoint(position: SIMD3<Float>(0, 0, -1_000)),
            makePoint(position: SIMD3<Float>(0, 0, 1_000))
        ]

        let framing = SplatCameraGeometry.robustFraming(for: points)

        XCTAssertEqual(framing.distance, SplatCameraGeometry.maximumCameraDistance, accuracy: 0.001)
        XCTAssertTrue(framing.distance.isFinite)
    }

    private func makePoint(position: SIMD3<Float>) -> SplatPoint {
        SplatPoint(
            position: position,
            color: SIMD4<UInt8>(255, 255, 255, 255),
            scale: SIMD3<Float>(repeating: 0.01),
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        )
    }
}
