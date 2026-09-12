import Foundation

private actor SplatPreviousResultPreservationWorker {
    func preserve(sourcePath: String) throws {
        try Task.checkCancellation()
        let sourceURL = URL(fileURLWithPath: sourcePath)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(
            sourceURL: sourceURL,
            fileManager: FileManager()
        )
        try Task.checkCancellation()
    }
}

extension SplatPreviousResultEvidence {
    /// Performs the potentially large completion hash and backup verification away from MainActor.
    /// A dedicated actor keeps synchronous file/hash work off the UI actor without creating an
    /// unstructured `Task.detached` sending boundary. Cancellation remains part of the caller's
    /// structured task and the synchronous hash loops check it between 1 MiB chunks.
    static func preserveBeforeReprocessAsync(
        sourceURL: URL
    ) async throws {
        let sourcePath = sourceURL.path
        let worker = SplatPreviousResultPreservationWorker()
        try await worker.preserve(sourcePath: sourcePath)
    }
}
