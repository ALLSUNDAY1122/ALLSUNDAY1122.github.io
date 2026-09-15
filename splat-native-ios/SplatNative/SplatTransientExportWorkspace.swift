import Foundation

/// Owns short-lived files handed to the iOS share sheet.
/// Exported interchange/video files are not part of the durable scan project and should not
/// silently accumulate beside `result.splat` after the share activity has completed.
enum SplatTransientExportWorkspace {
    static func create(
        rootDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) throws -> URL {
        let url = rootDirectory
            .appendingPathComponent("scanlab-export-\(UUID().uuidString)", isDirectory: true)
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
}
