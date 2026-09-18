@preconcurrency import ARKit
import Foundation
import simd

enum MeshARPlacementPolicy {
    private static let maximumGestureDelta = Float.pi
    private static let minimumPlacementDistance: Float = 0.05
    private static let maximumPlacementDistance: Float = 50
    private static let minimumPlacementDistanceSquared = minimumPlacementDistance * minimumPlacementDistance
    private static let maximumPlacementDistanceSquared = maximumPlacementDistance * maximumPlacementDistance
    private static let affineTolerance: Float = 0.001

    nonisolated static func isStableTracking(_ state: ARCamera.TrackingState) -> Bool {
        if case .normal = state { return true }
        return false
    }

    nonisolated static func shouldUseEstimatedPlane(hasPlacedModel: Bool) -> Bool { !hasPlacedModel }

    nonisolated static func updatedYaw(current: Float, gestureDelta: Float) -> Float {
        guard current.isFinite else { return 0 }
        guard gestureDelta.isFinite, abs(gestureDelta) <= maximumGestureDelta else { return normalizedYaw(current) }
        let normalizedCurrent = normalizedYaw(current)
        return normalizedYaw(normalizedCurrent - gestureDelta)
    }

    nonisolated static func hasFiniteTranslation(_ transform: simd_float4x4) -> Bool {
        let translation = transform.columns.3
        return translation.x.isFinite && translation.y.isFinite && translation.z.isFinite
    }

    nonisolated static func isPlausiblePlacement(_ transform: simd_float4x4, cameraTransform: simd_float4x4) -> Bool {
        guard hasFiniteTranslation(transform), isFiniteAffineTransform(cameraTransform) else { return false }
        let target = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let camera = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let delta = target - camera
        let distanceSquared = simd_length_squared(delta)
        guard distanceSquared.isFinite,
              distanceSquared >= minimumPlacementDistanceSquared,
              distanceSquared <= maximumPlacementDistanceSquared else { return false }

        let cameraZ = SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let forward = -cameraZ
        let forwardLengthSquared = simd_length_squared(forward)
        guard forwardLengthSquared.isFinite, forwardLengthSquared > 0.25, forwardLengthSquared < 4 else { return false }
        let forwardProjection = simd_dot(delta, forward)
        return forwardProjection.isFinite && forwardProjection > 0
    }

    nonisolated static func translationOnlyPlacement(from raycastTransform: simd_float4x4) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        let translation = raycastTransform.columns.3
        guard translation.x.isFinite, translation.y.isFinite, translation.z.isFinite else { return transform }
        transform.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        return transform
    }

    private nonisolated static func isFiniteAffineTransform(_ transform: simd_float4x4) -> Bool {
        for column in 0..<4 {
            for row in 0..<4 where !transform[column][row].isFinite { return false }
        }
        return abs(transform.columns.0.w) <= affineTolerance
            && abs(transform.columns.1.w) <= affineTolerance
            && abs(transform.columns.2.w) <= affineTolerance
            && abs(transform.columns.3.w - 1) <= affineTolerance
    }

    private nonisolated static func normalizedYaw(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        let twoPi = Float.pi * 2
        var result = value.truncatingRemainder(dividingBy: twoPi)
        if result > .pi { result -= twoPi }
        if result < -.pi { result += twoPi }
        return result.isFinite ? result : 0
    }
}
