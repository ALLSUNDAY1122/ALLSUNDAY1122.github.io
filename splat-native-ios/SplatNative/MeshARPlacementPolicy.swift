@preconcurrency import ARKit
import Foundation

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
}
