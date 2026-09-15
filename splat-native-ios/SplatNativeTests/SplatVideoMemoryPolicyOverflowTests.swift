import XCTest

final class SplatVideoMemoryPolicyOverflowTests: XCTestCase {
    func testSaturatedPeakFormatsWithoutOverflowing() {
        let estimate = SplatVideoMemoryPolicy.Estimate(
            pointCount: Int.max,
            estimatedPeakBytes: UInt64.max,
            budgetBytes: SplatVideoMemoryPolicy.maximumBudgetBytes
        )

        let mib: UInt64 = 1_048_576
        let expectedPeakMegabytes = Int(UInt64.max / mib + 1)
        XCTAssertEqual(estimate.estimatedPeakMegabytes, expectedPeakMegabytes)
        XCTAssertEqual(estimate.budgetMegabytes, 512)
    }

    func testVideoSurfaceReserveSaturatesInsteadOfTrapping() {
        XCTAssertEqual(
            SplatVideoMemoryPolicy.videoSurfaceReserveBytes(width: Int.max, height: Int.max),
            UInt64.max
        )
    }

    func testVideoSurfaceReserveKeepsOrdinaryPresetExact() {
        XCTAssertEqual(
            SplatVideoMemoryPolicy.videoSurfaceReserveBytes(width: 1_920, height: 1_080),
            UInt64(1_920 * 1_080 * 4 * 4)
        )
    }
}
