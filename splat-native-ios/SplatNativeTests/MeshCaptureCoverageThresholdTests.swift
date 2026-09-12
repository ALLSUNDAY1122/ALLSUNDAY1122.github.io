import XCTest

final class MeshCaptureCoverageThresholdTests: XCTestCase {
    func testNormalThresholdScalingIsUnchanged() {
        XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: 2), 0.04, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 2), 0.24, accuracy: 0.0001)
    }

    func testMalformedPathThresholdFallsBackToSafetyFloors() {
        for value: Float in [.nan, .infinity, -.infinity, -1, 0] {
            XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: value), 0.015, accuracy: 0.0001)
            XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: value), 0.10, accuracy: 0.0001)
        }
    }
}
