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
}
