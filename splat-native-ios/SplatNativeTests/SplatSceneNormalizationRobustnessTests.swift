import XCTest
import simd

final class SplatSceneNormalizationRobustnessTests: XCTestCase {
    func testMeasurementScaleDoesNotCollapseForLargeButValidSceneExtent() {
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-2_000_000, 0, 0),
            SIMD3<Float>(2_000_000, 0, 0),
        ]

        let normalization = SplatSceneNormalization(cameraPositions: positions)

        XCTAssertEqual(normalization.scale, 0.000_000_5, accuracy: 0.000_000_000_1)
        XCTAssertEqual(normalization.metersPerSceneUnit, 2_000_000, accuracy: 1)
        XCTAssertEqual(normalization.normalized(positions[0]).x, -1, accuracy: 0.0001)
        XCTAssertEqual(normalization.normalized(positions[1]).x, 1, accuracy: 0.0001)
    }

    func testFiniteCameraCoordinatesDoNotOverflowCentroidAccumulation() {
        let maximum = Float.greatestFiniteMagnitude
        let high = maximum * 0.75
        let low = maximum * 0.50
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(high, 0, 0),
            SIMD3<Float>(low, 0, 0),
        ]

        let normalization = SplatSceneNormalization(cameraPositions: positions)
        let normalizedHigh = normalization.normalized(positions[0]).x
        let normalizedLow = normalization.normalized(positions[1]).x

        XCTAssertTrue(normalization.translation.x.isFinite)
        XCTAssertTrue(normalization.scale.isFinite)
        XCTAssertGreaterThan(normalization.scale, 0)
        XCTAssertLessThan(normalization.scale, 1)
        XCTAssertEqual(normalizedHigh, 1, accuracy: 0.001)
        XCTAssertEqual(normalizedLow, -1, accuracy: 0.001)
        XCTAssertTrue(normalization.metersPerSceneUnit.isFinite)
        XCTAssertGreaterThan(normalization.metersPerSceneUnit, 1)
    }
}
