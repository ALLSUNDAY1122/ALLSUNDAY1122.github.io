import XCTest

final class SplatVideoConfigurationOverflowTests: XCTestCase {
    func testNormalFrameCountIsUnchanged() {
        var configuration = SplatVideoConfiguration()
        configuration.speed = .normal
        configuration.framesPerSecond = 30

        XCTAssertEqual(configuration.totalFrames, 240)
    }

    func testNegativeFrameRateUsesOneFPSFloor() {
        var configuration = SplatVideoConfiguration()
        configuration.speed = .fast
        configuration.framesPerSecond = Int.min

        XCTAssertEqual(configuration.totalFrames, 4)
    }

    func testHugeFrameRateSaturatesInsteadOfTrapping() {
        var configuration = SplatVideoConfiguration()
        configuration.speed = .slow
        configuration.framesPerSecond = Int.max

        XCTAssertEqual(configuration.totalFrames, Int.max)
    }
}
