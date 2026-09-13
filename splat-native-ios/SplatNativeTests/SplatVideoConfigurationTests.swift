import XCTest

final class SplatVideoConfigurationTests: XCTestCase {
    func testVideoQualityDimensionsAreStableAndEncoderFriendly() {
        let high = SplatVideoConfiguration.Quality.high1080p
        XCTAssertEqual(high.dimensions(for: .portrait9x16).width, 1080)
        XCTAssertEqual(high.dimensions(for: .portrait9x16).height, 1920)
        XCTAssertEqual(high.dimensions(for: .square1x1).width, 1080)
        XCTAssertEqual(high.dimensions(for: .square1x1).height, 1080)
        XCTAssertEqual(high.dimensions(for: .landscape16x9).width, 1920)
        XCTAssertEqual(high.dimensions(for: .landscape16x9).height, 1080)

        let lightweight = SplatVideoConfiguration.Quality.compatible720p
        XCTAssertEqual(lightweight.dimensions(for: .portrait9x16).width, 720)
        XCTAssertEqual(lightweight.dimensions(for: .portrait9x16).height, 1280)
        XCTAssertEqual(lightweight.dimensions(for: .square1x1).width, 720)
        XCTAssertEqual(lightweight.dimensions(for: .square1x1).height, 720)
        XCTAssertEqual(lightweight.dimensions(for: .landscape16x9).width, 1280)
        XCTAssertEqual(lightweight.dimensions(for: .landscape16x9).height, 720)

        for quality in SplatVideoConfiguration.Quality.allCases {
            for ratio in SplatVideoConfiguration.AspectRatio.allCases {
                let dimensions = quality.dimensions(for: ratio)
                XCTAssertEqual(dimensions.width % 2, 0)
                XCTAssertEqual(dimensions.height % 2, 0)
            }
            let portrait = quality.dimensions(for: .portrait9x16)
            let landscape = quality.dimensions(for: .landscape16x9)
            XCTAssertEqual(portrait.width * 16, portrait.height * 9)
            XCTAssertEqual(landscape.width * 9, landscape.height * 16)
        }
    }

    func test1080pIsTheDefaultAnd720pIsAnExplicitFallback() {
        var config = SplatVideoConfiguration()
        XCTAssertEqual(config.quality, .high1080p)
        XCTAssertEqual(config.dimensions.width, 1080)
        XCTAssertEqual(config.dimensions.height, 1920)

        config.quality = .compatible720p
        XCTAssertEqual(config.dimensions.width, 720)
        XCTAssertEqual(config.dimensions.height, 1280)
    }

    func testVideoBackgroundDefaultsDarkAndAllChoicesAreValidSRGBComponents() {
        let config = SplatVideoConfiguration()
        XCTAssertEqual(config.backgroundStyle, .dark)
        XCTAssertEqual(config.backgroundStyle.rgb.red, 0.025, accuracy: 0.0001)
        XCTAssertEqual(config.backgroundStyle.rgb.green, 0.030, accuracy: 0.0001)
        XCTAssertEqual(config.backgroundStyle.rgb.blue, 0.040, accuracy: 0.0001)

        for background in SplatVideoConfiguration.BackgroundStyle.allCases {
            let rgb = background.rgb
            for component in [rgb.red, rgb.green, rgb.blue] {
                XCTAssertTrue(component.isFinite)
                XCTAssertGreaterThanOrEqual(component, 0)
                XCTAssertLessThanOrEqual(component, 1)
            }
        }
        XCTAssertGreaterThan(
            SplatVideoConfiguration.BackgroundStyle.light.rgb.red,
            SplatVideoConfiguration.BackgroundStyle.neutral.rgb.red
        )
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
        let expectedLastYaw = 2 * Float.pi * Float(config.totalFrames - 1) / Float(config.totalFrames)
        XCTAssertEqual(orbitStart.yaw, 0, accuracy: 0.0001)
        XCTAssertEqual(orbitEnd.yaw, expectedLastYaw, accuracy: 0.0001)
        XCTAssertLessThan(orbitEnd.yaw, 2 * .pi)
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
        XCTAssertEqual(pushEnd.distanceMultiplier, 1.00, accuracy: 0.0001)

        config.cameraMotion = .depthOrbit
        let depthStart = config.cameraSample(progress: 0)
        let depthQuarter = config.cameraSample(progress: 0.25)
        XCTAssertEqual(depthStart.distanceMultiplier, 1.36, accuracy: 0.0001)
        XCTAssertLessThan(depthQuarter.distanceMultiplier, depthStart.distanceMultiplier)
        XCTAssertNotEqual(depthQuarter.pitch, depthStart.pitch)

        config.cameraMotion = .spiralRise
        let spiralStart = config.cameraSample(progress: 0)
        let spiralEnd = config.cameraSample(progress: 1)
        XCTAssertEqual(spiralStart.pitch, -0.28, accuracy: 0.0001)
        XCTAssertEqual(spiralEnd.pitch, 0.28, accuracy: 0.0001)
        XCTAssertGreaterThan(spiralStart.distanceMultiplier, spiralEnd.distanceMultiplier)
        XCTAssertEqual(spiralEnd.distanceMultiplier, 1.00, accuracy: 0.0001)
        XCTAssertGreaterThan(spiralEnd.yaw - spiralStart.yaw, 6.2)

        config.cameraMotion = .topApproach
        let topStart = config.cameraSample(progress: 0)
        let topEnd = config.cameraSample(progress: 1)
        XCTAssertEqual(topStart.pitch, 0.62, accuracy: 0.0001)
        XCTAssertEqual(topEnd.pitch, 0.10, accuracy: 0.0001)
        XCTAssertGreaterThan(topStart.distanceMultiplier, topEnd.distanceMultiplier)
        XCTAssertEqual(topEnd.distanceMultiplier, 1.00, accuracy: 0.0001)

        config.cameraMotion = .lowReveal
        let lowStart = config.cameraSample(progress: 0)
        let lowEnd = config.cameraSample(progress: 1)
        XCTAssertEqual(lowStart.pitch, -0.24, accuracy: 0.0001)
        XCTAssertEqual(lowEnd.pitch, 0.38, accuracy: 0.0001)
        XCTAssertGreaterThan(lowStart.distanceMultiplier, lowEnd.distanceMultiplier)
        XCTAssertEqual(lowEnd.distanceMultiplier, 1.00, accuracy: 0.0001)

        config.cameraMotion = .fixed
        let fixed = config.cameraSample(progress: 0.75)
        XCTAssertEqual(fixed.yaw, 0, accuracy: 0.0001)
        XCTAssertEqual(fixed.pitch, 0, accuracy: 0.0001)
        XCTAssertEqual(fixed.distanceMultiplier, 1, accuracy: 0.0001)
    }

    func testAllCameraMotionsStayFiniteAndNeverInvadeAspectFitDistance() {
        for motion in SplatVideoConfiguration.CameraMotion.allCases {
            var config = SplatVideoConfiguration()
            config.cameraMotion = motion
            for step in 0...120 {
                let sample = config.cameraSample(progress: Double(step) / 120)
                XCTAssertTrue(sample.yaw.isFinite, "nonfinite yaw for \(motion)")
                XCTAssertTrue(sample.pitch.isFinite, "nonfinite pitch for \(motion)")
                XCTAssertTrue(sample.distanceMultiplier.isFinite, "nonfinite distance for \(motion)")
                XCTAssertGreaterThanOrEqual(
                    sample.distanceMultiplier,
                    1.0 - 0.0001,
                    "camera moved inside aspect-fit framing floor for \(motion) at step \(step)"
                )
                XCTAssertLessThan(sample.distanceMultiplier, 1.6, "unsafe far distance for \(motion)")
                XCTAssertLessThanOrEqual(abs(sample.pitch), 0.75, "excessive pitch for \(motion)")
            }
        }
    }

    func testOrbit360UsesUniformUniqueSamplesAcrossTheLoopSeam() {
        var config = SplatVideoConfiguration()
        config.cameraMotion = .orbit360
        config.speed = .fast
        config.framesPerSecond = 30

        let frameCount = config.totalFrames
        let first = config.cameraSample(progress: 0)
        let second = config.cameraSample(progress: 1.0 / Double(frameCount - 1))
        let last = config.cameraSample(progress: 1)
        let angularStep = 2 * Float.pi / Float(frameCount)

        XCTAssertEqual(second.yaw - first.yaw, angularStep, accuracy: 0.0001)
        XCTAssertEqual((2 * Float.pi) - last.yaw, angularStep, accuracy: 0.0001)
        XCTAssertNotEqual(first.yaw, last.yaw)
    }

    func testFiniteCameraMovesEaseAtTheirEndpoints() {
        var config = SplatVideoConfiguration()

        config.cameraMotion = .pushIn
        let pushQuarter = config.cameraSample(progress: 0.25)
        let pushHalf = config.cameraSample(progress: 0.5)
        let pushThreeQuarter = config.cameraSample(progress: 0.75)
        XCTAssertEqual(pushQuarter.distanceMultiplier, 1.2109375, accuracy: 0.0001)
        XCTAssertEqual(pushHalf.distanceMultiplier, 1.125, accuracy: 0.0001)
        XCTAssertEqual(pushThreeQuarter.distanceMultiplier, 1.0390625, accuracy: 0.0001)

        config.cameraMotion = .orbit180
        let orbitQuarter = config.cameraSample(progress: 0.25)
        let orbitHalf = config.cameraSample(progress: 0.5)
        let orbitThreeQuarter = config.cameraSample(progress: 0.75)
        XCTAssertLessThan(orbitQuarter.yaw, -.pi / 4)
        XCTAssertEqual(orbitHalf.yaw, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(orbitThreeQuarter.yaw, .pi / 4)
    }

    func testCameraMotionSanitizesNonfiniteProgress() {
        for motion in SplatVideoConfiguration.CameraMotion.allCases {
            var config = SplatVideoConfiguration()
            config.cameraMotion = motion

            for progress in [Double.nan, Double.infinity, -Double.infinity] {
                let sample = config.cameraSample(progress: progress)
                XCTAssertTrue(sample.yaw.isFinite)
                XCTAssertTrue(sample.pitch.isFinite)
                XCTAssertTrue(sample.distanceMultiplier.isFinite)
                XCTAssertEqual(sample, config.cameraSample(progress: 0))
            }
        }
    }
}