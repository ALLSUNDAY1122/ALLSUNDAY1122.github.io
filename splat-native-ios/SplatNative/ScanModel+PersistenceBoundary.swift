import Foundation
import UIKit

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
    func returnHomePreservingProject()
}

extension ScanModel: ScanPersistenceBoundary {
    /// Leave the currently selected project without deleting its durable on-disk project.
    ///
    /// This deliberately does not call `discardAndReset()`: that method is reserved for
    /// explicit destructive discard flows because it moves the current project to Trash.
    /// Starting or restoring another project will replace the in-memory project binding,
    /// while the current project remains available from the local library.
    func returnHomePreservingProject() {
        session?.pause()
        resultURL = nil
        previewImage = nil
        isCapturePaused = false
        trackingMessage = "保存済みスキャンから再開できます"
        phase = .ready
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
