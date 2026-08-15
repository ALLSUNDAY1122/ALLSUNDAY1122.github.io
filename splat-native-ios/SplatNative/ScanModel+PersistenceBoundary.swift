import Foundation

/// Stable owner-facing contract for persistence, resume and reprocess flows.
///
/// C2 should build library/reopen/process-later behavior against this surface
/// and keep project-store details out of capture/reconstruction lane changes.
@MainActor
protocol ScanPersistenceBoundary: AnyObject {
    var phase: ScanModel.Phase { get }
    var resultURL: URL? { get }
    var canRetryGeneration: Bool { get }

    func restoreSavedProject(id: String)
    func discardAndReset()
    func retryGeneration()
}

extension ScanModel: ScanPersistenceBoundary {}
