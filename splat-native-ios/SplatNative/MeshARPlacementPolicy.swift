@preconcurrency import ARKit
import Foundation
import simd

enum MeshARPlacementPolicy {
    nonisolated static func isStableTracking(_ state: ARCamera.TrackingState) -> Bool {
        if case .normal = state { return true }
        return false
    }

    nonisolated static func shouldUseEstimatedPlane(hasPlacedModel: Bool) -> Bool {
        !hasPlacedModel
    }

    nonisolated static func updatedYaw(current: Float, gestureDelta: Float) -> Float {
        guard current.isFinite else { return 0 }
        guard gestureDelta.isFinite else { return current }
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

    nonisolated static func translationOnlyPlacement(from raycastTransform: simd_float4x4) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        let translation = raycastTransform.columns.3
        guard translation.x.isFinite, translation.y.isFinite, translation.z.isFinite else { return transform }
        transform.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        return transform
    }
}
