import Foundation

extension SplatPreviousResultEvidence {
    /// Performs the potentially large completion hash and backup verification away from MainActor.
    /// Cancellation is forwarded to the worker; synchronous hash loops already check cancellation
    /// between 1 MiB chunks so dismissing the result screen can release I/O promptly.
    static func preserveBeforeReprocessAsync(
        sourceURL: URL
    ) async throws {
        // Keep the detached task's capture list fully Sendable under Swift 6. FileManager is created
        // inside the worker rather than transferred from the caller's task-isolated context.
        let worker = Task.detached(priority: .userInitiated) { [sourceURL] in
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
