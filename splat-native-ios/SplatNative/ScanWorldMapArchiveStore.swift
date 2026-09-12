import Foundation

enum ScanWorldMapArchiveStoreError: LocalizedError {
    case emptyArchive
    case missingParentDirectory
    case unsafeExistingArchive
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .emptyArchive: return "WorldMap archiveが空です"
        case .missingParentDirectory: return "WorldMap保存先projectがありません"
        case .unsafeExistingArchive: return "既存WorldMap archiveが安全な通常ファイルではありません"
        case .verificationFailed: return "保存したWorldMap archiveを検証できません"
        }
    }
}

enum ScanWorldMapArchiveStore {
    static func write(_ data: Data, to targetURL: URL) throws {
        guard !data.isEmpty else { throw ScanWorldMapArchiveStoreError.emptyArchive }
        let parent = targetURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanWorldMapArchiveStoreError.missingParentDirectory
        }

        // Keep the last resumable WorldMap untouched until the replacement has survived an exact
        // read-back. The capture transition deliberately falls back to an existing map when a
        // refresh fails, so validating a sibling candidate first keeps that fallback truthful.
        let candidateURL = parent.appendingPathComponent(
            ".\(targetURL.lastPathComponent).\(UUID().uuidString).candidate",
            isDirectory: false
        )
        defer { try? FileManager.default.removeItem(at: candidateURL) }

        try data.write(to: candidateURL, options: .atomic)
        let values = try candidateURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              values.fileSize == data.count,
              let persisted = try? Data(contentsOf: candidateURL, options: .mappedIfSafe),
              persisted == data else {
            throw ScanWorldMapArchiveStoreError.verificationFailed
        }

        if FileManager.default.fileExists(atPath: targetURL.path) {
            // A saved project must stay self-contained. Replacing a symlink/special node risks
            // making the resumable WorldMap depend on bytes outside the project archive and gives
            // platform-specific replace semantics a chance to affect the alias target. Fail closed.
            guard let targetValues = try? targetURL.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            ), targetValues.isRegularFile == true, targetValues.isSymbolicLink != true else {
                throw ScanWorldMapArchiveStoreError.unsafeExistingArchive
            }
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: candidateURL)
        } else {
            try FileManager.default.moveItem(at: candidateURL, to: targetURL)
        }
    }
}
