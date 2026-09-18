@preconcurrency import ARKit
import Foundation
import simd

enum MeshARPlacementPolicy {
    private static let maximumGestureDelta = Float.pi
    private static let minimumPlacementDistance: Float = 0.05
    private static let maximumPlacementDistance: Float = 50

    nonisolated static func isStableTracking(_ state: ARCamera.TrackingState) -> Bool {
        if case .normal = state { return true }
        return false
    }

    nonisolated static func shouldUseEstimatedPlane(hasPlacedModel: Bool) -> Bool {
        !hasPlacedModel
    }

    nonisolated static func updatedYaw(current: Float, gestureDelta: Float) -> Float {
        guard current.isFinite else { return 0 }
        guard gestureDelta.isFinite, abs(gestureDelta) <= maximumGestureDelta else { return current }
        let twoPi = Float.pi * 2
        var value = (current - gestureDelta).truncatingRemainder(dividingBy: twoPi)
        if value > .pi { value -= twoPi }
        if value < -.pi { value += twoPi }
        return value.isFinite ? value : current
    }

    nonisolated static func hasFiniteTranslation(_ transform: simd_float4x4) -> Bool {
        let translation = transform.columns.3
        return translation.x.isFinite && translation.y.isFinite && translation.z.isFinite
    }

    nonisolated static func isPlausiblePlacement(_ transform: simd_float4x4, cameraTransform: simd_float4x4) -> Bool {
        guard hasFiniteTranslation(transform), hasFiniteTranslation(cameraTransform) else { return false }
        let target = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let camera = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let distance = simd_distance(target, camera)
        return distance.isFinite && distance >= minimumPlacementDistance && distance <= maximumPlacementDistance
    }

    nonisolated static func translationOnlyPlacement(from raycastTransform: simd_float4x4) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        let translation = raycastTransform.columns.3
        guard translation.x.isFinite, translation.y.isFinite, translation.z.isFinite else { return transform }
        transform.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        return transform
    }
}
