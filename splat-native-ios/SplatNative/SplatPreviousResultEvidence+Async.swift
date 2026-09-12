import Foundation

extension SplatPreviousResultEvidence {
    /// Performs the potentially large completion hash and backup verification away from MainActor.
    /// Cancellation is forwarded to the worker; synchronous hash loops already check cancellation
    /// between 1 MiB chunks so dismissing the result screen can release I/O promptly.
    static func preserveBeforeReprocessAsync(
        sourceURL: URL
    ) async throws {
        // Make the detached operation explicitly Sendable under Swift 6. Its only captured value is
        // Foundation.URL (Sendable); FileManager is created inside the detached worker.
        let operation: @Sendable () throws -> Void = { [sourceURL] in
            try Task.checkCancellation()
            try preserveBeforeReprocess(sourceURL: sourceURL, fileManager: .default)
            try Task.checkCancellation()
        }
        let worker = Task.detached(priority: .userInitiated, operation: operation)

        try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
