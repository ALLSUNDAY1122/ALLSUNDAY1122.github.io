import XCTest
import simd

final class SplatViewerStateTests: XCTestCase {
    func testDefaultEditSettingsAreNonDestructive() {
        let settings = SplatEditSettings.default
        XCTAssertEqual(settings.exposureEV, 0)
        XCTAssertEqual(settings.contrast, 1)
        XCTAssertFalse(settings.hasCrop)
    }

    func testNormalizationClampsAndRepairsCropRanges() {
        let settings = SplatEditSettings(
            exposureEV: 8,
            contrast: 0.1,
            cropXMin: 0.92,
            cropXMax: 0.20,
            cropYMin: -2,
            cropYMax: 4,
            cropZMin: 0.40,
            cropZMax: 0.405
        ).normalized()

        XCTAssertEqual(settings.exposureEV, 2)
        XCTAssertEqual(settings.contrast, 0.5)
        XCTAssertGreaterThanOrEqual(settings.cropXMin, 0)
        XCTAssertLessThanOrEqual(settings.cropXMax, 1)
        XCTAssertGreaterThanOrEqual(settings.cropXMax - settings.cropXMin, 0.0199)
        XCTAssertEqual(settings.cropYMin, 0)
        XCTAssertEqual(settings.cropYMax, 1)
        XCTAssertGreaterThanOrEqual(settings.cropZMax - settings.cropZMin, 0.0199)
    }

    func testEditSettingsRoundTripThroughJSON() throws {
        let expected = SplatEditSettings(
            exposureEV: 0.7,
            contrast: 1.25,
            cropXMin: 0.1,
            cropXMax: 0.9,
            cropYMin: 0.2,
            cropYMax: 0.8,
            cropZMin: 0.05,
            cropZMax: 0.95
        )
        let data = try JSONEncoder().encode(expected)
        let decoded = try JSONDecoder().decode(SplatEditSettings.self, from: data)
        XCTAssertEqual(decoded, expected)
    }

    func testMeasurementFormattingUsesPracticalUnits() {
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: 0.004), "4.0 mm")
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: 0.245), "24.5 cm")
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: 1.25), "1.25 m")
    }

    func testSceneNormalizationMatchesMsplatScaleAndCenter() {
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-0.20, 0.00, 1.50),
            SIMD3<Float>( 0.00, 0.10, 1.45),
            SIMD3<Float>( 0.20, 0.00, 1.50),
        ]
        let normalization = SplatSceneNormalization(cameraPositions: positions)

        // Mean camera position is removed, then the largest absolute centered
        // camera component (0.20 m here) is scaled to 1.0 by msplat.
        XCTAssertEqual(normalization.scale, 5.0, accuracy: 0.0001)
        XCTAssertEqual(normalization.metersPerSceneUnit, 0.20, accuracy: 0.0001)
        XCTAssertEqual(normalization.normalized(positions[0]).x, -1.0, accuracy: 0.0001)
        XCTAssertEqual(normalization.normalized(positions[2]).x, 1.0, accuracy: 0.0001)

        let normalizedDistance = simd_distance(
            normalization.normalized(positions[0]),
            normalization.normalized(positions[2])
        )
        XCTAssertEqual(normalizedDistance * normalization.metersPerSceneUnit, 0.40, accuracy: 0.0001)
    }
}
