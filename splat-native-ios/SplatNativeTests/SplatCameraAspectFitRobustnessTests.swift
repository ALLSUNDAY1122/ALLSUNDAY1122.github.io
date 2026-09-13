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
        XCTAssertLessThanOrEqual(distance, SplatCameraGeometry.maximumCameraDistance)
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
        XCTAssertLessThanOrEqual(distance, SplatCameraGeometry.maximumCameraDistance)
    }

    func testPortraitAspectFitCanMoveBeyondInitialSixtyUnitFramingFloor() {
        let framing = SplatCameraGeometry.Framing(
            center: .zero,
            distance: 60,
            radius: 40
        )

        let distance = SplatCameraGeometry.aspectFittedDistance(
            framing: framing,
            fovY: 55 * .pi / 180,
            aspect: 9.0 / 16.0
        )

        XCTAssertGreaterThan(distance, 60)
        XCTAssertLessThanOrEqual(distance, SplatCameraGeometry.maximumCameraDistance)
    }
}