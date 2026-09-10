import Foundation

/// Owns short-lived files handed to the iOS share sheet.
/// Exported interchange/video files are not part of the durable scan project and should not
/// silently accumulate beside `result.splat` after the share activity has completed.
enum SplatTransientExportWorkspace {
    private static let prefix = "scanlab-export-"
    private static let ownershipMarker = ".scanlab-transient-export"
    private static let staleAge: TimeInterval = 24 * 60 * 60

    static func create(
        rootDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) throws -> URL {
        // A terminated app never receives the share-sheet completion callback, so its transient
        // export directory would otherwise survive indefinitely. Only prune our own old prefix and
        // keep recent directories intact so another active share/export cannot be disturbed.
        cleanupStaleExports(
            in: rootDirectory,
            olderThan: staleAge,
            now: Date(),
            fileManager: fileManager
        )

        let url = rootDirectory
            .appendingPathComponent("\(prefix)\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        do {
            try Data().write(to: markerURL(for: url), options: .atomic)
        } catch {
            try? fileManager.removeItem(at: url)
            throw error
        }
        return url
    }

    static func remove(
        _ url: URL?,
        fileManager: FileManager = .default
    ) {
        guard let url,
              isOwnedWorkspace(url, fileManager: fileManager) else { return }
        // Cleanup is intentionally fail-closed. Cancellation/dismissal must never turn a mistakenly
        // propagated project URL into a recursive delete target; only a directory created by this
        // helper and carrying its ownership marker can be removed.
        try? fileManager.removeItem(at: url)
    }

    static func cleanupStaleExports(
        in rootDirectory: URL,
        olderThan age: TimeInterval,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) {
        guard age >= 0,
              let entries = try? fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        let cutoff = now.addingTimeInterval(-age)
        for entry in entries where entry.lastPathComponent.hasPrefix(prefix) {
            guard isOwnedWorkspace(entry, fileManager: fileManager),
                  let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified <= cutoff else { continue }
            try? fileManager.removeItem(at: entry)
        }
    }

    private static func markerURL(for workspaceURL: URL) -> URL {
        workspaceURL.appendingPathComponent(ownershipMarker, isDirectory: false)
    }

    private static func isOwnedWorkspace(
        _ url: URL,
        fileManager: FileManager
    ) -> Bool {
        guard url.isFileURL,
              url.lastPathComponent.hasPrefix(prefix) else { return false }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return false }
        var markerIsDirectory: ObjCBool = false
        return fileManager.fileExists(
            atPath: markerURL(for: url).path,
            isDirectory: &markerIsDirectory
        ) && !markerIsDirectory.boolValue
    }
}
