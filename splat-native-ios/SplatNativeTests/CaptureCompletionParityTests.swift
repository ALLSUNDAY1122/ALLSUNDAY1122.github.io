import XCTest

final class CaptureCompletionParityTests: XCTestCase {
    func testBroadObjectOrbitCanCompleteWithSingleElevationBand() {
        XCTAssertTrue(
            CapturePolicy.objectCoverageSatisfied(
                orbitSectors: 8,
                elevationBands: 1
            )
        )
    }

    func testObjectCaptureStillRequiresBroadOrbit() {
        XCTAssertFalse(
            CapturePolicy.objectCoverageSatisfied(
                orbitSectors: 7,
                elevationBands: 2
            )
        )
    }

    func testObjectCaptureStillRequiresDetectedElevationBand() {
        XCTAssertFalse(
            CapturePolicy.objectCoverageSatisfied(
                orbitSectors: 8,
                elevationBands: 0
            )
        )
    }

    func testSecondElevationBandRemainsQualityBonusRatherThanHardStop() {
        XCTAssertEqual(
            CapturePolicy.coverageScore(
                subjectDistance: 0.75,
                orbitSectors: 8,
                elevationBands: 1,
                viewDirectionSectors: 0,
                spatialCells: 0,
                pathLength: 0
            ),
            0.91,
            accuracy: 0.001
        )
    }
}
