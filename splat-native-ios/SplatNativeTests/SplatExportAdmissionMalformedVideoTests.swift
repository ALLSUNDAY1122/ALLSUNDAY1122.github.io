import XCTest

final class SplatExportAdmissionMalformedVideoTests: XCTestCase {
    func testNaNVideoDurationUsesFiniteOneSecondFloor() {
        let sourceBytes: Int64 = 10 * 1_024 * 1_024
        let malformed = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            kind: .video(width: 1_920, height: 1_080, framesPerSecond: 30, duration: .nan)
        )
        let oneSecond = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            kind: .video(width: 1_920, height: 1_080, framesPerSecond: 30, duration: 1)
        )

        XCTAssertEqual(malformed, oneSecond)
        XCTAssertGreaterThan(malformed, sourceBytes)
    }

    func testInfiniteVideoDurationSaturatesInsteadOfTrapping() {
        let required = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 1,
            kind: .video(width: Int.max, height: Int.max, framesPerSecond: Int.max, duration: .infinity)
        )

        XCTAssertEqual(required, Int64.max)
    }
}
