import SplatIO
import simd
import XCTest

final class SplatCameraGeometryTests: XCTestCase {
    func testRobustFramingKeepsLargeSceneAtLiveViewerDistanceCap() {
        let points = stride(from: -10, through: 10, by: 2).map { x in
            SplatPoint(
                position: SIMD3<Float>(Float(x), 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(128, 128, 128)),
                opacity: .linearFloat(1),
                scale: .linearFloat(SIMD3<Float>(repeating: 0.1)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        }

        let framing = SplatCameraGeometry.robustFraming(for: points)

        XCTAssertEqual(framing.center.x, 0, accuracy: 0.0001)
        XCTAssertEqual(framing.distance, 18, accuracy: 0.0001)
    }
}
