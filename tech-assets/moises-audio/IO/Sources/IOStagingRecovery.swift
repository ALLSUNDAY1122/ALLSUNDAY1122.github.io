import Foundation

public enum IOStagingRecoveryError: Error, Equatable, Sendable {
    case invalidGraceInterval
    case enumerationFailed
    case cleanupFailed
}

public struct IOStagingRecovery: Sendable {
    private let fileStore: IOFileStore

    public init(fileStore: IOFileStore) {
        self.fileStore = fileStore
    }

    /// Removes only stale direct children of the app-owned Staging directory.
    /// A grace interval prevents a concurrent/just-interrupted import from being mistaken for an orphan.
    /// The method never traverses into a staged directory or follows a symlink target.
    @discardableResult
    public func sweep(
        olderThan graceInterval: TimeInterval,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> [String] {
        guard graceInterval.isFinite, graceInterval >= 0 else {
            throw IOStagingRecoveryError.invalidGraceInterval
        }
        try fileStore.prepareDirectories(fileManager: fileManager)

        let candidates: [URL]
        do {
            candidates = try fileManager.contentsOfDirectory(
                at: fileStore.stagingURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw IOStagingRecoveryError.enumerationFailed
        }

        let cutoff = now.addingTimeInterval(-graceInterval)
        var removed: [String] = []

        for candidate in candidates {
            let values: URLResourceValues
            do {
                values = try candidate.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey
                ])
            } catch {
                continue
            }

            guard values.isRegularFile == true || values.isSymbolicLink == true else {
                continue
            }
            guard let modified = values.contentModificationDate, modified <= cutoff else {
                continue
            }

            do {
                try fileManager.removeItem(at: candidate)
                removed.append(candidate.lastPathComponent)
            } catch {
                throw IOStagingRecoveryError.cleanupFailed
            }
        }

        return removed.sorted()
    }
}
