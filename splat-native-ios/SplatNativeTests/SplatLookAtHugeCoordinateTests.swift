import simd
import XCTest

final class SplatLookAtHugeCoordinateTests: XCTestCase {
    func testOppositeHugeFiniteCoordinatesPreserveTrueViewDirection() {
        let magnitude = Float.greatestFiniteMagnitude * 0.75
        let center = SIMD3<Float>(-magnitude, 0, 0)
        let eye = SIMD3<Float>(magnitude, 0, 0)

        let matrix = SplatCameraGeometry.lookAt(
            eye: eye,
            center: center,
            up: SIMD3<Float>(0, 1, 0)
        )

        // The view Z basis must point from center toward eye (+X). The old Float subtraction
        // overflowed to Infinity here and silently fell back to +Z instead.
        XCTAssertEqual(matrix.columns.0.z, 1, accuracy: 0.0001)
        XCTAssertEqual(matrix.columns.1.z, 0, accuracy: 0.0001)
        XCTAssertEqual(matrix.columns.2.z, 0, accuracy: 0.0001)
        for column in 0..<4 {
            for row in 0..<4 {
                XCTAssertTrue(matrix[column][row].isFinite)
            }
        }
    }

    func testOrdinaryLookAtDirectionIsUnchanged() {
        let matrix = SplatCameraGeometry.lookAt(
            eye: SIMD3<Float>(2, 0, 0),
            center: .zero,
            up: SIMD3<Float>(0, 1, 0)
        )

        XCTAssertEqual(matrix.columns.0.z, 1, accuracy: 0.0001)
        XCTAssertEqual(matrix.columns.1.z, 0, accuracy: 0.0001)
        XCTAssertEqual(matrix.columns.2.z, 0, accuracy: 0.0001)
    }
}
