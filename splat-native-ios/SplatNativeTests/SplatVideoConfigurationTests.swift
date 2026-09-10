import XCTest

final class SplatVideoConfigurationTests: XCTestCase {
    func testAspectRatioDimensionsAreStableAndEncoderFriendly() {
        XCTAssertEqual(SplatVideoConfiguration.AspectRatio.portrait9x16.dimensions.width, 720)
        XCTAssertEqual(SplatVideoConfiguration.AspectRatio.portrait9x16.dimensions.height, 1280)
        XCTAssertEqual(SplatVideoConfiguration.AspectRatio.square1x1.dimensions.width, 720)
        XCTAssertEqual(SplatVideoConfiguration.AspectRatio.square1x1.dimensions.height, 720)
        XCTAssertEqual(SplatVideoConfiguration.AspectRatio.landscape16x9.dimensions.width, 1280)
        XCTAssertEqual(SplatVideoConfiguration.AspectRatio.landscape16x9.dimensions.height, 720)

        for ratio in SplatVideoConfiguration.AspectRatio.allCases {
            XCTAssertEqual(ratio.dimensions.width % 16, 0)
            XCTAssertEqual(ratio.dimensions.height % 16, 0)
        }
    }

    func testSpeedChangesDurationWithoutChangingFrameRate() {
        var config = SplatVideoConfiguration()
        XCTAssertEqual(config.framesPerSecond, 30)

        config.speed = .slow
        XCTAssertEqual(config.duration, 12)
        XCTAssertEqual(config.totalFrames, 360)

        config.speed = .normal
        XCTAssertEqual(config.duration, 8)
        XCTAssertEqual(config.totalFrames, 240)

        config.speed = .fast
        XCTAssertEqual(config.duration, 4)
        XCTAssertEqual(config.totalFrames, 120)
    }

    func testCameraMotionEndpoints() {
        var config = SplatVideoConfiguration()

        config.cameraMotion = .orbit360
        let orbitStart = config.cameraSample(progress: 0)
        let orbitEnd = config.cameraSample(progress: 1)
        XCTAssertEqual(orbitStart.yaw, 0, accuracy: 0.0001)
        XCTAssertEqual(orbitEnd.yaw, 2 * .pi, accuracy: 0.0001)
        XCTAssertEqual(orbitStart.distanceMultiplier, 1, accuracy: 0.0001)

        config.cameraMotion = .orbit180
        let halfStart = config.cameraSample(progress: 0)
        let halfEnd = config.cameraSample(progress: 1)
        XCTAssertEqual(halfStart.yaw, -.pi / 2, accuracy: 0.0001)
        XCTAssertEqual(halfEnd.yaw, .pi / 2, accuracy: 0.0001)

        config.cameraMotion = .pushIn
        let pushStart = config.cameraSample(progress: 0)
        let pushEnd = config.cameraSample(progress: 1)
        XCTAssertGreaterThan(pushStart.distanceMultiplier, pushEnd.distanceMultiplier)
        XCTAssertEqual(pushStart.distanceMultiplier, 1.25, accuracy: 0.0001)
        XCTAssertEqual(pushEnd.distanceMultiplier, 0.80, accuracy: 0.0001)

        config.cameraMotion = .fixed
        let fixed = config.cameraSample(progress: 0.75)
        XCTAssertEqual(fixed.yaw, 0, accuracy: 0.0001)
        XCTAssertEqual(fixed.pitch, 0, accuracy: 0.0001)
        XCTAssertEqual(fixed.distanceMultiplier, 1, accuracy: 0.0001)
    }

    func testFiniteCameraMovesEaseAtTheirEndpoints() {
        var config = SplatVideoConfiguration()

        config.cameraMotion = .pushIn
        let pushQuarter = config.cameraSample(progress: 0.25)
        let pushHalf = config.cameraSample(progress: 0.5)
        let pushThreeQuarter = config.cameraSample(progress: 0.75)
        // Smoothstep(0.25) = 0.15625: the move starts slower than a linear dolly.
        XCTAssertEqual(pushQuarter.distanceMultiplier, 1.1796875, accuracy: 0.0001)
        XCTAssertEqual(pushHalf.distanceMultiplier, 1.025, accuracy: 0.0001)
        XCTAssertEqual(pushThreeQuarter.distanceMultiplier, 0.8703125, accuracy: 0.0001)

        config.cameraMotion = .orbit180
        let orbitQuarter = config.cameraSample(progress: 0.25)
        let orbitHalf = config.cameraSample(progress: 0.5)
        let orbitThreeQuarter = config.cameraSample(progress: 0.75)
        XCTAssertLessThan(orbitQuarter.yaw, -.pi / 4)
        XCTAssertEqual(orbitHalf.yaw, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(orbitThreeQuarter.yaw, .pi / 4)
    }
}