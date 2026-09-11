import simd
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

    func testVerticalSpanThresholdRequiresRealHeightChange() {
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 0), 0.10, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 0.55), 0.10, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 1.0), 0.12, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 1.8), 0.216, accuracy: 0.0001)
    }

    func testVerticalSpanThresholdScalesWithoutBecomingZero() {
        let small = MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 0.55)
        let medium = MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 1.0)
        let large = MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 1.8)
        XCTAssertGreaterThan(small, 0)
        XCTAssertGreaterThanOrEqual(medium, small)
        XCTAssertGreaterThan(large, medium)
    }

    func testPlausibleMotionRejectsTrackingDiscontinuities() {
        XCTAssertTrue(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(0))
        XCTAssertTrue(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(0.349))
        XCTAssertTrue(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(0.35))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(0.351))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(.infinity))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(.nan))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isPlausibleSampleDisplacement(-0.01))
    }

    func testCameraPositionRejectsNonfiniteCoordinates() {
        XCTAssertTrue(MeshCaptureCoveragePolicy.isFiniteCameraPosition(SIMD3<Float>(0, 1, -2)))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isFiniteCameraPosition(SIMD3<Float>(.nan, 0, 0)))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isFiniteCameraPosition(SIMD3<Float>(0, .infinity, 0)))
        XCTAssertFalse(MeshCaptureCoveragePolicy.isFiniteCameraPosition(SIMD3<Float>(0, 0, -.infinity)))
    }
}
