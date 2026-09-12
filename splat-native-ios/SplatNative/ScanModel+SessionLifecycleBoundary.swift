@preconcurrency import ARKit

/// Stable HQ-owned contract for AR session and application lifecycle handling.
///
/// Session interruption/relocalization behavior remains an integration concern;
/// owner lanes should call this surface rather than duplicating lifecycle state.
@MainActor
protocol ScanSessionLifecycleBoundary: AnyObject {
    func attach(session: ARSession)
    func handleSessionInterrupted()
    func handleSessionInterruptionEnded()
    func handleApplicationBecameInactive()
    func handleApplicationBecameActive()
}

extension ScanModel: ScanSessionLifecycleBoundary {}
