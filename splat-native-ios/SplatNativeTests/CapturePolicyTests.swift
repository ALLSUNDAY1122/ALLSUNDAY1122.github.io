import XCTest
import simd
@testable import SplatNative

final class CapturePolicyTests: XCTestCase {
    func testRotationInPlaceNeverCountsAsUsefulCaptureMotion() {
        let previous = matrix_identity_float4x4
        let rotation = simd_float4x4(simd_quatf(angle: 0.55, axis: SIMD3<Float>(0, 1, 0)))

        XCTAssertFalse(CapturePolicy.shouldAcceptFrame(
            previous: previous,
            current: rotation,
            subjectDistance: 0.60,
            previousTimestamp: 1.0,
            currentTimestamp: 1.5
        ))
    }

    func testSmallObjectUsesSmallerTranslationBaseline() {
        XCTAssertEqual(CapturePolicy.minimumTranslation(subjectDistance: 0.40), 0.018, accuracy: 0.0001)
        XCTAssertEqual(CapturePolicy.minimumTranslation(subjectDistance: 3.0), 0.12, accuracy: 0.0001)

        var current = matrix_identity_float4x4
        current.columns.3.x = 0.025
        XCTAssertTrue(CapturePolicy.shouldAcceptFrame(
            previous: matrix_identity_float4x4,
            current: current,
            subjectDistance: 0.40,
            previousTimestamp: 1.0,
            currentTimestamp: 1.4
        ))
    }

    func testRelocalizationSizedPoseJumpIsRejected() {
        var current = matrix_identity_float4x4
        current.columns.3.x = 1.8
        XCTAssertFalse(CapturePolicy.shouldAcceptFrame(
            previous: matrix_identity_float4x4,
            current: current,
            subjectDistance: 1.0,
            previousTimestamp: 1.0,
            currentTimestamp: 1.5
        ))
    }

    func testObjectCoverageRequiresHeightDiversity() {
        XCTAssertFalse(CapturePolicy.objectCoverageSatisfied(orbitSectors: 8, elevationBands: 1))
        XCTAssertTrue(CapturePolicy.objectCoverageSatisfied(orbitSectors: 8, elevationBands: 2))
    }

    func testSceneCoverageCanPassWithoutObjectCenteredOrbit() {
        XCTAssertTrue(CapturePolicy.sceneCoverageSatisfied(
            viewDirectionSectors: 5,
            spatialCells: 5,
            pathLength: 0.80
        ))
        XCTAssertFalse(CapturePolicy.sceneCoverageSatisfied(
            viewDirectionSectors: 5,
            spatialCells: 2,
            pathLength: 0.80
        ))
    }

    func testCoverageScoreSupportsObjectAndSceneStrategies() {
        let objectScore = CapturePolicy.coverageScore(
            orbitSectors: 8,
            elevationBands: 2,
            viewDirectionSectors: 1,
            spatialCells: 1,
            pathLength: 0.1
        )
        let sceneScore = CapturePolicy.coverageScore(
            orbitSectors: 1,
            elevationBands: 1,
            viewDirectionSectors: 5,
            spatialCells: 5,
            pathLength: 0.8
        )
        XCTAssertEqual(objectScore, 1, accuracy: 0.001)
        XCTAssertEqual(sceneScore, 1, accuracy: 0.001)
    }
}
