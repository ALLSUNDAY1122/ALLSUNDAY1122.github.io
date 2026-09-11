import SplatIO
import simd
import XCTest

final class SplatCameraGeometryTests: XCTestCase {
    func testRobustFramingKeepsLargeSceneAtLiveViewerDistanceCap() {
        let points = stride(from: -10, through: 10, by: 2).map { x in
            SplatPoint(
                position: SIMD3<Float>(Float(x), 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(128, 128, 128)),
                opacity: .linearFloat(1),
                scale: .linearFloat(SIMD3<Float>(repeating: 0.1)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        }

        let framing = SplatCameraGeometry.robustFraming(for: points)

        XCTAssertEqual(framing.center.x, 0, accuracy: 0.0001)
        XCTAssertEqual(framing.distance, 18, accuracy: 0.0001)
        XCTAssertEqual(framing.radius, 10, accuracy: 0.0001)
    }

    func testPortraitVideoMovesBackWhenHorizontalFOVIsLimiting() {
        let framing = SplatCameraGeometry.Framing(
            center: .zero,
            distance: 2.8,
            radius: 1
        )
        let fovY: Float = 55 * .pi / 180

        let portraitDistance = SplatCameraGeometry.aspectFittedDistance(
            framing: framing,
            fovY: fovY,
            aspect: 9.0 / 16.0
        )
        let landscapeDistance = SplatCameraGeometry.aspectFittedDistance(
            framing: framing,
            fovY: fovY,
            aspect: 16.0 / 9.0
        )

        XCTAssertGreaterThan(portraitDistance, framing.distance)
        XCTAssertEqual(landscapeDistance, framing.distance, accuracy: 0.0001)
    }

    func testAspectFittedDistanceContainsRobustSphereInPortraitFrame() {
        let framing = SplatCameraGeometry.Framing(
            center: .zero,
            distance: 5.6,
            radius: 2
        )
        let fovY: Float = 55 * .pi / 180
        let aspect: Float = 9.0 / 16.0
        let distance = SplatCameraGeometry.aspectFittedDistance(
            framing: framing,
            fovY: fovY,
            aspect: aspect
        )
        let halfHorizontalFOV = atan(tan(fovY * 0.5) * aspect)
        let visibleHalfWidthAtSphereTangent = distance * sin(halfHorizontalFOV)

        XCTAssertGreaterThanOrEqual(visibleHalfWidthAtSphereTangent, framing.radius * 1.09)
    }

    func testCameraSpaceDisplayCorrectionKeepsTranslatedTargetCentered() {
        let center = SIMD3<Float>(4.0, -2.5, 1.25)
        let eye = SplatCameraGeometry.eye(
            center: center,
            distance: 4,
            yaw: 0.7,
            pitch: 0.15
        )
        let baseView = SplatCameraGeometry.lookAt(
            eye: eye,
            center: center,
            up: SIMD3<Float>(0, 1, 0)
        )
        let correctedView = SplatCameraGeometry.rotationZ(.pi) * baseView
        let targetInCamera = correctedView * SIMD4<Float>(center, 1)

        // The display correction rotates camera axes, not the translated world. The scene target
        // therefore remains exactly on the optical axis even when its world-space center is not 0.
        XCTAssertEqual(targetInCamera.x, 0, accuracy: 0.0001)
        XCTAssertEqual(targetInCamera.y, 0, accuracy: 0.0001)
    }

    func testPerspectiveRemainsFiniteForTransientZeroAspect() {
        let matrix = SplatCameraGeometry.perspective(
            fovY: .pi / 3,
            aspect: 0,
            near: 0.01,
            far: 100
        )

        XCTAssertTrue(isFinite(matrix))
    }

    func testPerspectiveRemainsFiniteForNonFiniteInputs() {
        let matrix = SplatCameraGeometry.perspective(
            fovY: .nan,
            aspect: .nan,
            near: .nan,
            far: .nan
        )

        XCTAssertTrue(isFinite(matrix))
    }

    func testLookAtRemainsFiniteWhenEyeEqualsCenter() {
        let center = SIMD3<Float>(1, 2, 3)
        let matrix = SplatCameraGeometry.lookAt(
            eye: center,
            center: center,
            up: SIMD3<Float>(0, 1, 0)
        )

        XCTAssertTrue(isFinite(matrix))
    }

    func testLookAtRemainsFiniteWhenUpIsParallelToXAxisView() {
        let matrix = SplatCameraGeometry.lookAt(
            eye: SIMD3<Float>(1, 0, 0),
            center: .zero,
            up: SIMD3<Float>(1, 0, 0)
        )

        XCTAssertTrue(isFinite(matrix))
        let x = SIMD3<Float>(matrix.columns.0.x, matrix.columns.1.x, matrix.columns.2.x)
        let y = SIMD3<Float>(matrix.columns.0.y, matrix.columns.1.y, matrix.columns.2.y)
        let z = SIMD3<Float>(matrix.columns.0.z, matrix.columns.1.z, matrix.columns.2.z)
        XCTAssertEqual(simd_length(x), 1, accuracy: 0.0001)
        XCTAssertEqual(simd_length(y), 1, accuracy: 0.0001)
        XCTAssertEqual(simd_length(z), 1, accuracy: 0.0001)
    }

    func testLookAtRemainsFiniteForNonFiniteEyeAndCenter() {
        let matrix = SplatCameraGeometry.lookAt(
            eye: SIMD3<Float>(.nan, .infinity, -.infinity),
            center: SIMD3<Float>(.nan, 0, 0),
            up: SIMD3<Float>(0, 1, 0)
        )

        XCTAssertTrue(isFinite(matrix))
    }

    private func isFinite(_ matrix: simd_float4x4) -> Bool {
        for column in 0..<4 {
            for row in 0..<4 where !matrix[column][row].isFinite {
                return false
            }
        }
        return true
    }
}
