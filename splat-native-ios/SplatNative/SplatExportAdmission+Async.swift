import Foundation

extension SplatExportAdmission {
    /// Completion evidence verification hashes the completed `.splat`, which can be hundreds of
    /// megabytes. Export screens are MainActor-isolated, so running synchronous preflight directly
    /// from their Task can freeze buttons/progress/cancellation until SHA-256 finishes.
    ///
    /// Keep the exact same fail-closed verification semantics, but execute filesystem/hash work on
    /// an unstructured worker and return only the trusted URL to legacy callers.
    static func preflightAsync(
        sourceURL: URL,
        kind: Kind,
        availableCapacityOverride: Int64? = nil
    ) async throws -> URL {
        try await preflightResultAsync(
            sourceURL: sourceURL,
            kind: kind,
            availableCapacityOverride: availableCapacityOverride
        ).trustedURL
    }

    /// Returns the freshly verified completion digest together with the trusted URL so downstream
    /// video/export admission can derive content-addressed assets without hashing the same large
    /// completed result again.
    static func preflightResultAsync(
        sourceURL: URL,
        kind: Kind,
        availableCapacityOverride: Int64? = nil
    ) async throws -> Result {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let result = try preflightResult(
                sourceURL: sourceURL,
                kind: kind,
                availableCapacityOverride: availableCapacityOverride
            )
            try Task.checkCancellation()
            return result
        }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
