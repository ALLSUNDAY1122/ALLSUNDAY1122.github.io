import XCTest
import simd

final class CaptureMotionQualityTests: XCTestCase {
    func testCloseObjectRejectsFastTranslationThatWouldBlurOverlap() {
        var current = matrix_identity_float4x4
        current.columns.3.x = 0.30

        let decision = CapturePolicy.frameDecision(
            previous: matrix_identity_float4x4,
            current: current,
            subjectDistance: 0.60,
            previousTimestamp: 1.0,
            currentTimestamp: 1.20
        )
        XCTAssertEqual(decision, .tooFast)
    }

    func testSameTranslationIsAcceptedWhenPerformedSlowly() {
        var current = matrix_identity_float4x4
        current.columns.3.x = 0.30

        let decision = CapturePolicy.frameDecision(
            previous: matrix_identity_float4x4,
            current: current,
            subjectDistance: 0.60,
            previousTimestamp: 1.0,
            currentTimestamp: 1.80
        )
        XCTAssertEqual(decision, .accept)
    }

    func testFastRotationIsRejectedEvenWithUsefulTranslation() {
        var current = simd_float4x4(simd_quatf(angle: 0.8, axis: SIMD3<Float>(0, 1, 0)))
        current.columns.3.x = 0.08

        let decision = CapturePolicy.frameDecision(
            previous: matrix_identity_float4x4,
            current: current,
            subjectDistance: 1.0,
            previousTimestamp: 1.0,
            currentTimestamp: 1.25
        )
        XCTAssertEqual(decision, .tooFast)
    }

    func testSceneAllowsFasterTranslationThanCloseObject() {
        XCTAssertGreaterThan(
            CapturePolicy.maximumTranslationSpeed(subjectDistance: 2.5),
            CapturePolicy.maximumTranslationSpeed(subjectDistance: 0.5)
        )
    }

    func testLargePoseJumpStillClassifiesAsRelocalizationBeforeSpeed() {
        var current = matrix_identity_float4x4
        current.columns.3.x = 1.5

        let decision = CapturePolicy.frameDecision(
            previous: matrix_identity_float4x4,
            current: current,
            subjectDistance: 1.0,
            previousTimestamp: 1.0,
            currentTimestamp: 1.2
        )
        XCTAssertEqual(decision, .relocalizationJump)
    }

    func testRejectsSeverelyDarkFrame() {
        let stats = CaptureImageQualityStats(
            meanLuma: 24,
            darkFraction: 0.82,
            highlightFraction: 0,
            lumaStandardDeviation: 10,
            laplacianScore: 4,
            sampleCount: 512
        )
        XCTAssertEqual(CaptureImageQualityPolicy.rejection(for: stats), .tooDark)
    }

    func testRejectsSeverelyClippedHighlights() {
        let stats = CaptureImageQualityStats(
            meanLuma: 228,
            darkFraction: 0,
            highlightFraction: 0.76,
            lumaStandardDeviation: 12,
            laplacianScore: 5,
            sampleCount: 512
        )
        XCTAssertEqual(CaptureImageQualityPolicy.rejection(for: stats), .tooBright)
    }

    func testRejectsOnlyClearlySoftLowDetailFrame() {
        let stats = CaptureImageQualityStats(
            meanLuma: 112,
            darkFraction: 0.02,
            highlightFraction: 0.02,
            lumaStandardDeviation: 9,
            laplacianScore: 1.2,
            sampleCount: 512
        )
        XCTAssertEqual(CaptureImageQualityPolicy.rejection(for: stats), .tooSoft)
    }

    func testAcceptsNormallyExposedDetailedFrame() {
        let stats = CaptureImageQualityStats(
            meanLuma: 116,
            darkFraction: 0.08,
            highlightFraction: 0.04,
            lumaStandardDeviation: 34,
            laplacianScore: 8,
            sampleCount: 512
        )
        XCTAssertNil(CaptureImageQualityPolicy.rejection(for: stats))
    }

    func testSmallQualitySampleFailsOpen() {
        let stats = CaptureImageQualityStats(
            meanLuma: 10,
            darkFraction: 1,
            highlightFraction: 0,
            lumaStandardDeviation: 0,
            laplacianScore: 0,
            sampleCount: 12
        )
        XCTAssertNil(CaptureImageQualityPolicy.rejection(for: stats))
    }
}
