import Foundation

extension SplatExportAdmission {
    /// Completion evidence verification hashes the completed `.splat`, which can be hundreds of
    /// megabytes. Export screens are MainActor-isolated, so running synchronous preflight directly
    /// from their Task can freeze buttons/progress/cancellation until SHA-256 finishes.
    ///
    /// Keep the exact same fail-closed verification semantics, but execute filesystem/hash work on
    /// an unstructured worker and return only the trusted URL to the caller's actor.
    static func preflightAsync(
        sourceURL: URL,
        kind: Kind,
        availableCapacityOverride: Int64? = nil
    ) async throws -> URL {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let trusted = try preflight(
                sourceURL: sourceURL,
                kind: kind,
                availableCapacityOverride: availableCapacityOverride
            )
            try Task.checkCancellation()
            return trusted
        }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
