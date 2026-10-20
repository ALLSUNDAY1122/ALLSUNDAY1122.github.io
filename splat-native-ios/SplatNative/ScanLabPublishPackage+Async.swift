import Foundation

private struct ScanLabPublishPackageWorkerResult: @unchecked Sendable {
    // ScanLabPublishPackage is an immutable value made only of URLs, a manifest, and scalar
    // manifest fields. Keep the unchecked boundary local instead of weakening the package type's
    // Sendable contract globally.
    let package: ScanLabPublishPackage
}

extension ScanLabPublishPackageBuilder {
    /// Package validation may decode and hash an SPZ up to the 128 MiB publish limit. The publish
    /// flow lives on ScanLabBackend's MainActor, so doing that work inline can freeze progress UI,
    /// buttons, and cancellation while the filesystem/hash pass runs.
    ///
    /// Preserve the exact synchronous fail-closed package contract while moving the expensive
    /// filesystem/decode/hash work to a user-initiated worker. Parent cancellation is propagated
    /// to the worker before and after the synchronous package build. If cancellation lands while
    /// the builder is running or in the completion handoff race, remove the completed temporary
    /// package before surfacing CancellationError so abandoned publish workspaces do not accumulate.
    static func buildAsync(
        from sourceURL: URL,
        maximumBytes: Int = 128 * 1024 * 1024
    ) async throws -> ScanLabPublishPackage {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let package = try build(from: sourceURL, maximumBytes: maximumBytes)
            do {
                try Task.checkCancellation()
            } catch {
                cleanup(package)
                throw error
            }
            return ScanLabPublishPackageWorkerResult(package: package)
        }

        let result = try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }

        do {
            try Task.checkCancellation()
            return result.package
        } catch {
            cleanup(result.package)
            throw error
        }
    }
}
