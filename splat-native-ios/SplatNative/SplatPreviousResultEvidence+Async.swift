import Foundation

extension SplatPreviousResultEvidence {
    /// Performs the potentially large completion hash and backup verification away from MainActor.
    /// Cancellation is forwarded to the worker; synchronous hash loops already check cancellation
    /// between 1 MiB chunks so dismissing the result screen can release I/O promptly.
    static func preserveBeforeReprocessAsync(
        sourceURL: URL
    ) async throws {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            try preserveBeforeReprocess(sourceURL: sourceURL, fileManager: .default)
            try Task.checkCancellation()
        }

        try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
