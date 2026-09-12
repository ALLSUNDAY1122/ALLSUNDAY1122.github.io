import XCTest
import simd

final class CaptureFiniteSafetyTests: XCTestCase {
    func testNonFiniteViewDirectionFallsBackWithoutIntegerTrap() {
        var transform = matrix_identity_float4x4
        transform.columns.2.x = .nan
        XCTAssertEqual(CapturePolicy.viewDirectionSector(transform: transform, count: 8), 0)

        transform = matrix_identity_float4x4
        transform.columns.2.z = .infinity
        XCTAssertEqual(CapturePolicy.viewDirectionSector(transform: transform, count: 8), 0)
    }

    func testNonFiniteOrbitAndElevationAreRejected() {
        XCTAssertNil(CapturePolicy.orbitSector(
            cameraPosition: SIMD3<Float>(.nan, 0, 1),
            center: .zero,
            count: 8
        ))
        XCTAssertNil(CapturePolicy.elevationBand(
            cameraPosition: SIMD3<Float>(1, .infinity, 0),
            center: .zero
        ))
    }

    func testSpatialCellHandlesNonFiniteAndExtremeCoordinatesWithoutTrap() {
        XCTAssertEqual(
            CapturePolicy.spatialCell(cameraPosition: SIMD3<Float>(.nan, 0, .infinity)),
            CaptureGridCell(x: 0, z: 0)
        )
        XCTAssertEqual(
            CapturePolicy.spatialCell(cameraPosition: SIMD3<Float>(.greatestFiniteMagnitude, 0, -.greatestFiniteMagnitude)),
            CaptureGridCell(x: 1_000_000, z: -1_000_000)
        )
    }

    func testInvalidCellSizeUsesSafeDefault() {
        XCTAssertEqual(
            CapturePolicy.spatialCell(cameraPosition: SIMD3<Float>(1, 0, -1), cellSize: .nan),
            CaptureGridCell(x: 4, z: -4)
        )
    }
}
