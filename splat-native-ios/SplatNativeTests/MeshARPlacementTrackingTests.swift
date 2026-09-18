import ARKit
import XCTest

final class MeshARPlacementTrackingTests: XCTestCase {
    func testNormalTrackingAllowsPlacement() { XCTAssertTrue(MeshARPlacementPolicy.isStableTracking(.normal)) }
    func testLimitedTrackingRejectsPlacement() {
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.limited(.initializing)))
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.limited(.excessiveMotion)))
        XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.limited(.insufficientFeatures)))
    }
    func testUnavailableTrackingRejectsPlacement() { XCTAssertFalse(MeshARPlacementPolicy.isStableTracking(.notAvailable)) }
    func testEstimatedPlaneFallbackOnlyAppliesBeforeInitialPlacement() {
        XCTAssertTrue(MeshARPlacementPolicy.shouldUseEstimatedPlane(hasPlacedModel: false))
        XCTAssertFalse(MeshARPlacementPolicy.shouldUseEstimatedPlane(hasPlacedModel: true))
    }
    func testYawUpdatePreservesGestureDirection() {
        XCTAssertEqual(MeshARPlacementPolicy.updatedYaw(current: 0, gestureDelta: 0.25), -0.25, accuracy: 0.0001)
    }
    func testYawUpdateRemainsBoundedAfterLargeAccumulation() {
        let yaw = MeshARPlacementPolicy.updatedYaw(current: 1_000_000, gestureDelta: -1)
        XCTAssertTrue(yaw.isFinite)
        XCTAssertLessThanOrEqual(abs(yaw), .pi)
    }
    func testRejectedGestureStillNormalizesAccumulatedYaw() {
        let yaw = MeshARPlacementPolicy.updatedYaw(current: 1_000_000, gestureDelta: .infinity)
        XCTAssertTrue(yaw.isFinite)
        XCTAssertLessThanOrEqual(abs(yaw), .pi)
    }
    func testYawUpdateRejectsNonFiniteInputWithoutSnappingValidOrientation() {
        XCTAssertEqual(MeshARPlacementPolicy.updatedYaw(current: .infinity, gestureDelta: 0.1), 0)
        XCTAssertEqual(MeshARPlacementPolicy.updatedYaw(current: 0.1, gestureDelta: .nan), 0.1, accuracy: 0.0001)
    }
    func testPlacementTranslationRequiresFiniteCoordinates() {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(1, 2, 3, 1)
        XCTAssertTrue(MeshARPlacementPolicy.hasFiniteTranslation(transform))
        transform.columns.3.x = .nan
        XCTAssertFalse(MeshARPlacementPolicy.hasFiniteTranslation(transform))
        transform = matrix_identity_float4x4
        transform.columns.3.z = .infinity
        XCTAssertFalse(MeshARPlacementPolicy.hasFiniteTranslation(transform))
    }
    func testPlausiblePlacementRejectsNearCameraExcessiveDistanceAndBehindCamera() {
        let camera = matrix_identity_float4x4
        var target = matrix_identity_float4x4
        target.columns.3.z = -0.01
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
        target.columns.3.z = -1
        XCTAssertTrue(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
        target.columns.3.z = -51
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
        target.columns.3.z = 1
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
    }
    func testPlausiblePlacementRejectsMalformedCameraForwardAxis() {
        var camera = matrix_identity_float4x4
        var target = matrix_identity_float4x4
        target.columns.3.z = -1
        camera.columns.2.z = .nan
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
        camera = matrix_identity_float4x4
        camera.columns.2 = SIMD4<Float>(0, 0, 0, 0)
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
    }
    func testPlausiblePlacementRejectsShearedCameraBasis() {
        var camera = matrix_identity_float4x4
        var target = matrix_identity_float4x4
        target.columns.3.z = -1
        camera.columns.1.x = 0.2
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
    }
    func testPlausiblePlacementRejectsReflectedCameraBasis() {
        var camera = matrix_identity_float4x4
        var target = matrix_identity_float4x4
        target.columns.3.z = -1
        camera.columns.0.x = -1
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
    }
    func testPlausiblePlacementRejectsExtremeEdgeOfCameraCone() {
        let camera = matrix_identity_float4x4
        var target = matrix_identity_float4x4
        target.columns.3 = SIMD4<Float>(2, 0, -0.2, 1)
        XCTAssertFalse(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
        target.columns.3 = SIMD4<Float>(0.5, 0, -1, 1)
        XCTAssertTrue(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
    }
    func testForwardProjectionIsIndependentOfSmallCameraAxisScale() {
        var camera = matrix_identity_float4x4
        var target = matrix_identity_float4x4
        target.columns.3 = SIMD4<Float>(0.5, 0, -1, 1)
        camera.columns.2.z = 1.05
        XCTAssertTrue(MeshARPlacementPolicy.isPlausiblePlacement(target, cameraTransform: camera))
    }
    func testTranslationOnlyPlacementPreservesPositionAndRemovesRaycastTilt() {
        var raycast = matrix_identity_float4x4
        raycast.columns.0 = SIMD4<Float>(0, 1, 0, 0)
        raycast.columns.1 = SIMD4<Float>(-1, 0, 0, 0)
        raycast.columns.3 = SIMD4<Float>(1.25, -0.5, 2.75, 1)
        let placement = MeshARPlacementPolicy.translationOnlyPlacement(from: raycast)
        XCTAssertEqual(placement.columns.0, matrix_identity_float4x4.columns.0)
        XCTAssertEqual(placement.columns.1, matrix_identity_float4x4.columns.1)
        XCTAssertEqual(placement.columns.2, matrix_identity_float4x4.columns.2)
        XCTAssertEqual(placement.columns.3, SIMD4<Float>(1.25, -0.5, 2.75, 1))
    }
    func testInvalidTranslationProducesIdentityFallback() {
        var raycast = matrix_identity_float4x4
        raycast.columns.3.x = .nan
        XCTAssertEqual(MeshARPlacementPolicy.translationOnlyPlacement(from: raycast), matrix_identity_float4x4)
    }
}
