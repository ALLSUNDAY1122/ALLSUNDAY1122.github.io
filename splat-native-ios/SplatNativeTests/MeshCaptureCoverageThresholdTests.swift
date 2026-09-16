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

    func testNormalizedForwardDirectionAcceptsPlausibleARBasis() {
        let direction = MeshCaptureCoveragePolicy.normalizedForwardDirection(SIMD3<Float>(0.6, 0, -0.8))
        XCTAssertNotNil(direction)
        XCTAssertEqual(simd_length(direction!), 1, accuracy: 0.0001)
    }

    func testNormalizedForwardDirectionRejectsScaledOrMalformedBasis() {
        XCTAssertNil(MeshCaptureCoveragePolicy.normalizedForwardDirection(SIMD3<Float>(60, 0, -80)))
        XCTAssertNil(MeshCaptureCoveragePolicy.normalizedForwardDirection(SIMD3<Float>(0.006, 0, -0.008)))
        XCTAssertNil(MeshCaptureCoveragePolicy.normalizedForwardDirection(SIMD3<Float>(.nan, 0, -1)))
    }
}
