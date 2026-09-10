import XCTest

final class SplatViewerMemoryPolicyTests: XCTestCase {
    func testSmallSH3SceneFitsTypicalDeviceBudget() {
        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 250_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024
        ))
    }

    func testLargeSH3SceneFallsBackBeforeExceedingBudget() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 2_000_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024
        ))
    }

    func testInvalidPointCountNeverSelectsCanonicalAsset() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 0,
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
        ))
    }
}