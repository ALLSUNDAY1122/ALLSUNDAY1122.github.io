@preconcurrency import ARKit

enum MeshARPlacementPolicy {
    nonisolated static func isStableTracking(_ state: ARCamera.TrackingState) -> Bool {
        if case .normal = state { return true }
        return false
    }
}
