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
}
