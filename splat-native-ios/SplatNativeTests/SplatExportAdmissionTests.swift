import XCTest

final class SplatExportAdmissionTests: XCTestCase {
    func testPLYReservesMoreWorkingSpaceThanSPZ() {
        let sourceBytes: Int64 = 96 * 1_024 * 1_024
        let ply = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: .ply)
        let spz = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: .spz)

        XCTAssertGreaterThan(ply, spz)
        XCTAssertGreaterThan(ply, sourceBytes)
        XCTAssertGreaterThan(spz, sourceBytes)
    }

    func testVideoEstimateGrowsWithDurationAndResolution() {
        let shortPortrait = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 64 * 1_024 * 1_024,
            kind: .video(width: 720, height: 1280, framesPerSecond: 30, duration: 4)
        )
        let longHD = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 64 * 1_024 * 1_024,
            kind: .video(width: 1920, height: 1080, framesPerSecond: 30, duration: 12)
        )

        XCTAssertGreaterThan(longHD, shortPortrait)
    }

    func testEstimateSaturatesInsteadOfOverflowing() {
        let required = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: Int64.max,
            kind: .ply
        )
        XCTAssertEqual(required, Int64.max)
    }
}
