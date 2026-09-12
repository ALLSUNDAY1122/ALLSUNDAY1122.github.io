import XCTest

final class SplatCameraAspectFitRobustnessTests: XCTestCase {
    func testAspectFitSanitizesNonfiniteInputs() {
        let framing = SplatCameraGeometry.Framing(
            center: .zero,
            distance: .nan,
            radius: .infinity
        )

        let distance = SplatCameraGeometry.aspectFittedDistance(
            framing: framing,
            fovY: .nan,
            aspect: .nan,
            margin: .infinity
        )

        XCTAssertTrue(distance.isFinite)
        XCTAssertGreaterThanOrEqual(distance, 0.35)
        XCTAssertLessThanOrEqual(distance, 60)
    }

    func testAspectFitSanitizesNegativeRadiusAndDistance() {
        let framing = SplatCameraGeometry.Framing(
            center: .zero,
            distance: -10,
            radius: -5
        )

        let distance = SplatCameraGeometry.aspectFittedDistance(
            framing: framing,
            fovY: 0,
            aspect: -1,
            margin: -2
        )

        XCTAssertTrue(distance.isFinite)
        XCTAssertGreaterThanOrEqual(distance, 0.35)
        XCTAssertLessThanOrEqual(distance, 60)
    }
}
