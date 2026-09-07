import Foundation

#if canImport(AVFoundation)
@preconcurrency import AVFoundation

/// Narrow Swift 6 compatibility boundary for AVAssetExportSession's legacy
/// iOS 17-compatible completion and cancellation API. Apple marks the session
/// non-Sendable, but its callbacks cross @Sendable closure boundaries.
/// Keep the unchecked assertion private to Lane2 IO instead of weakening the
/// surrounding actors or globally retroactively conforming the Apple type.
final class IOAVAssetExportSessionHandle: @unchecked Sendable {
    private let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }

    func exportAsynchronously(completionHandler: @escaping @Sendable () -> Void) {
        session.exportAsynchronously(completionHandler: completionHandler)
    }

    var status: AVAssetExportSession.Status {
        session.status
    }

    func cancel() {
        session.cancelExport()
    }
}
#endif
