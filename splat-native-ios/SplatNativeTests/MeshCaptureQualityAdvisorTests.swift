import XCTest

final class MeshCaptureQualityAdvisorTests: XCTestCase {
    func testCoverageTranslationThresholdScalesWithSceneSize() {
        XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: 0.55), 0.015, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: 1.0), 0.020, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: 1.8), 0.036, accuracy: 0.0001)
    }

    func testCoverageThresholdAlwaysRequiresPhysicalTranslation() {
        for threshold: Float in [0, 0.55, 1.0, 1.8] {
            XCTAssertGreaterThan(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: threshold), 0)
        }
    }
}
