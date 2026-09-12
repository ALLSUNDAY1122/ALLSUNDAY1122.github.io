import Foundation

extension SplatPreviousResultEvidence {
    /// Performs the potentially large completion hash and backup verification away from MainActor.
    /// Cancellation is forwarded to the worker; synchronous hash loops already check cancellation
    /// between 1 MiB chunks so dismissing the result screen can release I/O promptly.
    static func preserveBeforeReprocessAsync(
        sourceURL: URL
    ) async throws {
        // Do not transfer Foundation URL state across the detached-task boundary under Swift 6
        // strict concurrency. A String path is Sendable; rebuild the file URL inside the worker.
        let sourcePath = sourceURL.path
        let worker = Task.detached(priority: .userInitiated) { @Sendable in
            let detachedSourceURL = URL(fileURLWithPath: sourcePath)
            try Task.checkCancellation()
            try preserveBeforeReprocess(sourceURL: detachedSourceURL, fileManager: .default)
            try Task.checkCancellation()
        }

        try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
