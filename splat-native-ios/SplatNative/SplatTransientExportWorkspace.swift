import Foundation

/// Owns short-lived files handed to the iOS share sheet.
/// Exported interchange/video files are not part of the durable scan project and should not
/// silently accumulate beside `result.splat` after the share activity has completed.
enum SplatTransientExportWorkspace {
    private static let prefix = "scanlab-export-"
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
        return url
    }

    static func remove(
        _ url: URL?,
        fileManager: FileManager = .default
    ) {
        guard let url else { return }
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
            guard let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey]),
                  values.isDirectory == true,
                  let modified = values.contentModificationDate,
                  modified <= cutoff else { continue }
            try? fileManager.removeItem(at: entry)
        }
    }
}
