import XCTest
import simd

final class MeshCaptureCoveragePolicyTests: XCTestCase {
    func testThresholdsStayFiniteForMalformedHugeInput() {
        XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: .greatestFiniteMagnitude), 0.015, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: .greatestFiniteMagnitude), 0.10, accuracy: 0.0001)
    }

    func testThresholdsUseExpectedScalingForNormalInput() {
        XCTAssertEqual(MeshCaptureCoveragePolicy.translationThreshold(pathThresholdMeters: 2), 0.04, accuracy: 0.0001)
        XCTAssertEqual(MeshCaptureCoveragePolicy.verticalSpanThreshold(pathThresholdMeters: 2), 0.24, accuracy: 0.0001)
    }

    func testForwardNormalizationRejectsNonFiniteAndNormalizesLargeFiniteVector() {
        XCTAssertNil(MeshCaptureCoveragePolicy.normalizedForwardDirection(SIMD3<Float>(.nan, 0, 1)))
        let normalized = MeshCaptureCoveragePolicy.normalizedForwardDirection(SIMD3<Float>(Float.greatestFiniteMagnitude, 0, 0))
        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized?.x ?? 0, 1, accuracy: 0.0001)
    }
}