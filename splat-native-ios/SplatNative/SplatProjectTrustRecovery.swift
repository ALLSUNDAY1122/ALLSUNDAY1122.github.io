import Foundation

/// Converts legacy/corrupt "finished" state into an explicit reprocess path without deleting raw data.
/// A project is never opened as completed 3D unless the atomic completion evidence verifies.
enum SplatProjectTrustRecovery {
    enum RecoveryError: LocalizedError {
        case trustedResultAlreadyExists
        case rawDataUnavailable

        var errorDescription: String? {
            switch self {
            case .trustedResultAlreadyExists:
                return "完成確認済みの3Dがあるため再生成状態への修復は不要です。"
            case .rawDataUnavailable:
                return "完成確認できない3Dがありますが、安全な再生成に必要なrawデータがありません。"
            }
        }
    }

    static func trustedResultURL(for project: ScanProjectSummary) -> URL? {
        let candidate = project.projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        return try? SplatCompletionVerifier.verify(sourceURL: candidate)
    }

    static func canRecoverForReprocess(
        _ project: ScanProjectSummary,
        store: ScanProjectStore
    ) -> Bool {
        guard project.manifest.stage == .finished,
              trustedResultURL(for: project) == nil,
              hasReprocessableRaw(project, store: store) else {
            return false
        }
        return true
    }

    /// Downgrades only the manifest contract. The suspect result is retained until reconstruction
    /// actually starts; `ScanProjectStore.updateManifest(... .processing)` then removes/replaces it
    /// using the normal atomic reconstruction path. Raw capture data is never deleted here.
    static func prepareForReprocess(
        _ project: ScanProjectSummary,
        store: ScanProjectStore
    ) throws {
        // Strong verification can hash a completed Splat hundreds of megabytes in size. Do it once:
        // calling canRecoverForReprocess here used to repeat the exact same SHA-256 scan immediately
        // before checking raw availability, doubling recovery latency and storage I/O.
        //
        // Do not use trustedResultURL's `try?` here: the strong verifier is cooperatively cancellable,
        // and swallowing CancellationError would reinterpret an abandoned verification as corruption
        // and could then downgrade a healthy finished manifest after the user left the flow.
        let candidate = project.projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        do {
            _ = try SplatCompletionVerifier.verify(sourceURL: candidate)
            throw RecoveryError.trustedResultAlreadyExists
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RecoveryError {
            throw error
        } catch {
            // A real verification failure is the expected prerequisite for trust recovery.
        }

        try Task.checkCancellation()
        guard project.manifest.stage == .finished,
              hasReprocessableRaw(project, store: store) else {
            throw RecoveryError.rawDataUnavailable
        }
        try Task.checkCancellation()

        _ = try store.updateManifest(projectURL: project.projectURL) { manifest in
            manifest.stage = .captured
            manifest.outputs.removeValue(forKey: ScanRepresentationKind.splat.rawValue)
            manifest.lastError = "以前の3Dは完了記録を確認できないため表示せず、保存済みrawデータから安全に再生成します。"
            manifest.rawDataRetained = true
        }
    }

    private static func hasReprocessableRaw(
        _ project: ScanProjectSummary,
        store: ScanProjectStore
    ) -> Bool {
        guard (try? store.loadCheckpoint(projectURL: project.projectURL)) != nil,
              (try? store.reprocessRequest(
                projectURL: project.projectURL,
                representation: .splat
              )) != nil else {
            return false
        }
        return true
    }
}
