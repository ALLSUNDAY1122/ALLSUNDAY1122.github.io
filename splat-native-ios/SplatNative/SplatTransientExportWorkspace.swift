import Foundation

/// Owns short-lived files handed to the iOS share sheet.
/// Exported interchange/video files are not part of the durable scan project and should not
/// silently accumulate beside `result.splat` after the share activity has completed.
enum SplatTransientExportWorkspace {
    private static let prefix = "scanlab-export-"
    private static let ownershipMarker = ".scanlab-transient-export"
    private static let staleAge: TimeInterval = 24 * 60 * 60
    private static let maximumMarkerByteCount = 4 * 1024

    static func create(
        rootDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) throws -> URL {
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
            let marker = Data(canonicalPath(of: url).utf8)
            guard !marker.isEmpty, marker.count <= maximumMarkerByteCount else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            let markerURL = markerURL(for: url)
            try marker.write(to: markerURL, options: .atomic)
            let markerHandle = try FileHandle(forWritingTo: markerURL)
            defer { try? markerHandle.close() }
            try markerHandle.synchronize()
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
              url.lastPathComponent.hasPrefix(prefix),
              let workspaceValues = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
              ),
              workspaceValues.isDirectory == true,
              workspaceValues.isSymbolicLink != true else { return false }

        let marker = markerURL(for: url)
        guard let markerValues = try? marker.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        ), markerValues.isRegularFile == true,
           markerValues.isSymbolicLink != true,
           let markerSize = markerValues.fileSize,
           markerSize >= 0,
           markerSize <= maximumMarkerByteCount,
           fileManager.fileExists(atPath: marker.path) else {
            return false
        }

        let markerHandle: FileHandle
        do { markerHandle = try FileHandle(forReadingFrom: marker) } catch { return false }
        defer { try? markerHandle.close() }
        guard let data = try? markerHandle.read(upToCount: maximumMarkerByteCount + 1),
              let data,
              data.count <= maximumMarkerByteCount else { return false }
        if data.isEmpty {
            return canonicalPath(of: url.deletingLastPathComponent())
                == canonicalPath(of: fileManager.temporaryDirectory)
        }
        guard let recordedPath = String(data: data, encoding: .utf8) else { return false }
        return recordedPath == canonicalPath(of: url)
    }

    private static func canonicalPath(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
