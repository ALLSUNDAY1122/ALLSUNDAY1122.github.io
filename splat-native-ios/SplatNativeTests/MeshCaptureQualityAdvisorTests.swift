import XCTest
@testable import SplatNative

final class MeshCaptureQualityAdvisorTests: XCTestCase {
    func testCoverageTranslationThresholdScalesWithSceneSize() {
        XCTAssertEqual(MeshCaptureQualityAdvisor.coverageTranslationThreshold(size: .small), 0.015, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureQualityAdvisor.coverageTranslationThreshold(size: .medium), 0.020, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureQualityAdvisor.coverageTranslationThreshold(size: .large), 0.036, accuracy: 0.0001)
    }

    func testCoverageThresholdAlwaysRequiresPhysicalTranslation() {
        for size in MeshScanSize.allCases {
            XCTAssertGreaterThan(MeshCaptureQualityAdvisor.coverageTranslationThreshold(size: size), 0)
        }
    }
}
