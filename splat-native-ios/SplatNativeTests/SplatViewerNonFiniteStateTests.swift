import simd
import XCTest

final class SplatViewerNonFiniteStateTests: XCTestCase {
    func testEditNormalizationReplacesNonFiniteValuesWithDefaults() {
        let normalized = SplatEditSettings(
            exposureEV: .nan,
            contrast: .infinity,
            cropXMin: -.infinity,
            cropXMax: .nan,
            cropYMin: .nan,
            cropYMax: .infinity,
            cropZMin: -.infinity,
            cropZMax: .nan
        ).normalized()

        XCTAssertEqual(normalized.exposureEV, 0)
        XCTAssertEqual(normalized.contrast, 1)
        XCTAssertEqual(normalized.cropXMin, 0)
        XCTAssertEqual(normalized.cropXMax, 1)
        XCTAssertEqual(normalized.cropYMin, 0)
        XCTAssertEqual(normalized.cropYMax, 1)
        XCTAssertEqual(normalized.cropZMin, 0)
        XCTAssertEqual(normalized.cropZMax, 1)
    }

    func testSceneNormalizationIgnoresNonFiniteCameraPose() {
        let normalization = SplatSceneNormalization(cameraPositions: [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(2, 0, 0),
            SIMD3<Float>(.nan, 100, 100),
        ])

        XCTAssertEqual(normalization.translation.x, 1, accuracy: 0.0001)
        XCTAssertEqual(normalization.translation.y, 0, accuracy: 0.0001)
        XCTAssertEqual(normalization.translation.z, 0, accuracy: 0.0001)
        XCTAssertEqual(normalization.scale, 1, accuracy: 0.0001)
        XCTAssertEqual(normalization.metersPerSceneUnit, 1, accuracy: 0.0001)
    }

    func testMeasurementFormatterNeverDisplaysNaNOrInfinity() {
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: .nan), "0.0 mm")
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: .infinity), "0.0 mm")
    }
}
