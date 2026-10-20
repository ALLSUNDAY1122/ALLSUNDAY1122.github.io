import SplatIO
import simd
import XCTest

final class SplatRobustFramingFiniteDistanceTests: XCTestCase {
    func testHugeFiniteCoordinatesDoNotCollapseToFallbackFraming() {
        let magnitude = Float.greatestFiniteMagnitude * 0.75
        let points = [
            makePoint(SIMD3<Float>(-magnitude, 0, 0)),
            makePoint(SIMD3<Float>(magnitude, 0, 0)),
            makePoint(SIMD3<Float>(0, -magnitude, 0)),
            makePoint(SIMD3<Float>(0, magnitude, 0)),
            makePoint(SIMD3<Float>(0, 0, -magnitude)),
            makePoint(SIMD3<Float>(0, 0, magnitude))
        ]

        let framing = SplatCameraGeometry.robustFraming(for: points)

        XCTAssertTrue(framing.radius.isFinite)
        XCTAssertGreaterThan(framing.radius, 1)
        XCTAssertEqual(framing.distance, 60, accuracy: 0.001)
    }

    func testNormalSceneFramingRemainsUnchanged() {
        let points = [
            makePoint(SIMD3<Float>(-1, 0, 0)),
            makePoint(SIMD3<Float>(1, 0, 0)),
            makePoint(SIMD3<Float>(0, -1, 0)),
            makePoint(SIMD3<Float>(0, 1, 0)),
            makePoint(SIMD3<Float>(0, 0, -1)),
            makePoint(SIMD3<Float>(0, 0, 1))
        ]

        let framing = SplatCameraGeometry.robustFraming(for: points)

        XCTAssertEqual(framing.center.x, 0, accuracy: 0.001)
        XCTAssertEqual(framing.center.y, 0, accuracy: 0.001)
        XCTAssertEqual(framing.center.z, 0, accuracy: 0.001)
        XCTAssertEqual(framing.radius, 1, accuracy: 0.001)
        XCTAssertEqual(framing.distance, 2.8, accuracy: 0.001)
    }

    private func makePoint(_ position: SIMD3<Float>) -> SplatPoint {
        SplatPoint(
            position: position,
            color: .sRGBUInt8(SIMD3<UInt8>(128, 128, 128)),
            opacity: .linearFloat(0.8),
            scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        )
    }
}
