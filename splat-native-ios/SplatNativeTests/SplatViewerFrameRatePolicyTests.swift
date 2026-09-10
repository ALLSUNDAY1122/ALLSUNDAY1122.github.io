import XCTest

final class SplatViewerFrameRatePolicyTests: XCTestCase {
    func testNominalAndFairPreserveSmoothSixtyFPS() {
        XCTAssertEqual(SplatViewerFrameRatePolicy.preferredFramesPerSecond(for: .nominal), 60)
        XCTAssertEqual(SplatViewerFrameRatePolicy.preferredFramesPerSecond(for: .fair), 60)
    }

    func testThermalPressureReducesContinuousViewerLoad() {
        XCTAssertEqual(SplatViewerFrameRatePolicy.preferredFramesPerSecond(for: .serious), 30)
        XCTAssertEqual(SplatViewerFrameRatePolicy.preferredFramesPerSecond(for: .critical), 20)
    }
}
