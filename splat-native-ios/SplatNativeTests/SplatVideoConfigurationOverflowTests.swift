import XCTest

final class SplatVideoConfigurationOverflowTests: XCTestCase {
    func testNormalFrameCountIsUnchanged() {
        var configuration = SplatVideoConfiguration()
        configuration.speed = .normal
        configuration.framesPerSecond = 30

        XCTAssertEqual(configuration.framesPerSecond, 30)
        XCTAssertEqual(configuration.totalFrames, 240)
    }

    func testNegativeFrameRateUsesOneFPSFloor() {
        var configuration = SplatVideoConfiguration()
        configuration.speed = .fast
        configuration.framesPerSecond = Int.min

        XCTAssertEqual(configuration.framesPerSecond, 1)
        XCTAssertEqual(configuration.totalFrames, 4)
    }

    func testHugeFrameRateUsesEncoderSafeCeiling() {
        var configuration = SplatVideoConfiguration()
        configuration.speed = .slow
        configuration.framesPerSecond = Int.max

        XCTAssertEqual(configuration.framesPerSecond, 120)
        XCTAssertEqual(configuration.totalFrames, 1_440)
        XCTAssertEqual(SplatVideoConfiguration.safeFramesPerSecond(Int.max), 120)
    }
}
