import XCTest
@testable import HomeCourtCVCore

final class ShotEventDetectorTests: XCTestCase {
    func testDetectsSingleArcCrossingRim() {
        let detector = ShotEventDetector(
            rimRegion: RimRegion(
                centerX: 0.5,
                centerY: 0.4,
                halfWidth: 0.08,
                halfHeight: 0.08
            )
        )
        let points = [
            TrackedPoint(time: 0.0, x: 0.30, y: 0.58),
            TrackedPoint(time: 0.1, x: 0.36, y: 0.49),
            TrackedPoint(time: 0.2, x: 0.42, y: 0.38),
            TrackedPoint(time: 0.3, x: 0.47, y: 0.31),
            TrackedPoint(time: 0.4, x: 0.50, y: 0.36),
            TrackedPoint(time: 0.5, x: 0.51, y: 0.41),
            TrackedPoint(time: 0.6, x: 0.52, y: 0.49)
        ]

        XCTAssertEqual(detector.detect(in: points).count, 1)
    }

    func testRejectsFlatTrajectory() {
        let detector = ShotEventDetector(
            rimRegion: RimRegion(
                centerX: 0.5,
                centerY: 0.4,
                halfWidth: 0.08,
                halfHeight: 0.08
            )
        )
        let points = (0..<7).map { index in
            TrackedPoint(
                time: Double(index) * 0.1,
                x: 0.3 + Double(index) * 0.03,
                y: 0.4
            )
        }

        XCTAssertTrue(detector.detect(in: points).isEmpty)
    }
}
