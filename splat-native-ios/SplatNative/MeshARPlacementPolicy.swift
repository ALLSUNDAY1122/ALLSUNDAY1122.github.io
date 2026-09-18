@preconcurrency import ARKit
import Foundation
import simd

enum MeshARPlacementPolicy {
    private static let maximumGestureDelta = Float.pi
    private static let minimumPlacementDistance: Float = 0.10
    private static let maximumPlacementDistance: Float = 20
    private static let minimumPlacementDistanceSquared = minimumPlacementDistance * minimumPlacementDistance
    private static let maximumPlacementDistanceSquared = maximumPlacementDistance * maximumPlacementDistance
    private static let minimumForwardProjection: Float = 0.05
    private static let minimumForwardCosineSquared: Float = 0.25
    private static let affineTolerance: Float = 0.001
    private static let minimumCameraAxisLengthSquared: Float = 0.9801
    private static let maximumCameraAxisLengthSquared: Float = 1.0201
    private static let maximumCameraAxisDot: Float = 0.02
    private static let minimumCameraDeterminant: Float = 0.97
    private static let maximumCameraDeterminant: Float = 1.03

    nonisolated static func isStableTracking(_ state: ARCamera.TrackingState) -> Bool { if case .normal = state { return true }; return false }
    nonisolated static func shouldUseEstimatedPlane(hasPlacedModel: Bool) -> Bool { !hasPlacedModel }
    nonisolated static func updatedYaw(current: Float, gestureDelta: Float) -> Float {
        guard current.isFinite else { return 0 }; guard gestureDelta.isFinite, abs(gestureDelta) <= maximumGestureDelta else { return normalizedYaw(current) }
        return normalizedYaw(normalizedYaw(current) - gestureDelta)
    }
    nonisolated static func hasFiniteTranslation(_ transform: simd_float4x4) -> Bool {
        let translation = transform.columns.3; return translation.x.isFinite && translation.y.isFinite && translation.z.isFinite
    }
    nonisolated static func isPlausiblePlacement(_ transform: simd_float4x4, cameraTransform: simd_float4x4) -> Bool {
        guard isRigidTransform(transform), isRigidTransform(cameraTransform) else { return false }
        let target = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let camera = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let delta = target - camera; let distanceSquared = simd_length_squared(delta)
        guard distanceSquared.isFinite, distanceSquared >= minimumPlacementDistanceSquared, distanceSquared <= maximumPlacementDistanceSquared else { return false }
        let cameraZ = SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let forwardLength = simd_length(cameraZ); guard forwardLength.isFinite, forwardLength > 0 else { return false }
        let forwardProjection = simd_dot(delta, -cameraZ / forwardLength)
        guard forwardProjection.isFinite, forwardProjection >= minimumForwardProjection else { return false }
        let forwardFractionSquared = (forwardProjection * forwardProjection) / distanceSquared
        return forwardFractionSquared.isFinite && forwardFractionSquared >= minimumForwardCosineSquared
    }
    nonisolated static func translationOnlyPlacement(from raycastTransform: simd_float4x4) -> simd_float4x4 {
        var transform = matrix_identity_float4x4; guard isRigidTransform(raycastTransform) else { return transform }
        let translation = raycastTransform.columns.3; transform.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1); return transform
    }
    private nonisolated static func isRigidTransform(_ transform: simd_float4x4) -> Bool {
        guard isFiniteAffineTransform(transform) else { return false }
        let x = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z), y = SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z), z = SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let lengths = [simd_length_squared(x), simd_length_squared(y), simd_length_squared(z)]
        guard lengths.allSatisfy({ $0.isFinite && $0 >= minimumCameraAxisLengthSquared && $0 <= maximumCameraAxisLengthSquared }) else { return false }
        let xy = simd_dot(x, y), xz = simd_dot(x, z), yz = simd_dot(y, z)
        guard xy.isFinite && xz.isFinite && yz.isFinite, abs(xy) <= maximumCameraAxisDot, abs(xz) <= maximumCameraAxisDot, abs(yz) <= maximumCameraAxisDot else { return false }
        let determinant = simd_dot(x, simd_cross(y, z)); return determinant.isFinite && determinant >= minimumCameraDeterminant && determinant <= maximumCameraDeterminant
    }
    private nonisolated static func isFiniteAffineTransform(_ transform: simd_float4x4) -> Bool {
        for column in 0..<4 { for row in 0..<4 where !transform[column][row].isFinite { return false } }
        return abs(transform.columns.0.w) <= affineTolerance && abs(transform.columns.1.w) <= affineTolerance && abs(transform.columns.2.w) <= affineTolerance && abs(transform.columns.3.w - 1) <= affineTolerance
    }
    private nonisolated static func normalizedYaw(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }; let twoPi = Float.pi * 2; var result = value.truncatingRemainder(dividingBy: twoPi)
        if result > .pi { result -= twoPi }; if result < -.pi { result += twoPi }; return result.isFinite ? result : 0
    }
}
