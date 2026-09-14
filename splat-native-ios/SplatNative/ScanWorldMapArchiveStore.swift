import Foundation

enum ScanWorldMapArchiveStoreError: LocalizedError {
    case emptyArchive
    case missingParentDirectory
    case unsafeParentDirectory
    case unsafeExistingArchive
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .emptyArchive: return "WorldMap archiveが空です"
        case .missingParentDirectory: return "WorldMap保存先projectがありません"
        case .unsafeParentDirectory: return "WorldMap保存先projectが安全な通常directoryではありません"
        case .unsafeExistingArchive: return "既存WorldMap archiveが安全な通常ファイルではありません"
        case .verificationFailed: return "保存したWorldMap archiveを検証できません"
        }
    }
}

enum ScanWorldMapArchiveStore {
    private static let verificationChunkByteCount = 1_024 * 1_024

    static func write(_ data: Data, to targetURL: URL) throws {
        guard !data.isEmpty else { throw ScanWorldMapArchiveStoreError.emptyArchive }
        let parent = targetURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanWorldMapArchiveStoreError.missingParentDirectory
        }
        // `fileExists(...isDirectory:)` follows a directory symlink. Without an explicit lstat-style
        // resource check, a damaged/restored project path can redirect the candidate and final
        // WorldMap write outside the scan project while still looking like a valid directory.
        guard let parentValues = try? parent.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ), parentValues.isDirectory == true, parentValues.isSymbolicLink != true else {
            throw ScanWorldMapArchiveStoreError.unsafeParentDirectory
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

        // `Data.write(.atomic)` gives us replacement semantics, but successful return alone does not
        // prove the candidate bytes have crossed the FileHandle durability boundary. Flush the fully
        // written candidate before it can replace the last resumable WorldMap. If synchronization
        // itself fails, preserve the previous archive rather than publishing a less durable generation.
        do {
            let handle = try FileHandle(forWritingTo: candidateURL)
            defer { try? handle.close() }
            try handle.synchronize()
        } catch {
            throw ScanWorldMapArchiveStoreError.verificationFailed
        }

        let values = try candidateURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              values.fileSize == data.count,
              fileContentsEqual(data, at: candidateURL) else {
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

    private static func fileContentsEqual(_ expected: Data, at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        var offset = 0
        while offset < expected.count {
            let requestedCount = min(verificationChunkByteCount, expected.count - offset)
            guard let chunk = try? handle.read(upToCount: requestedCount),
                  !chunk.isEmpty,
                  chunk.count <= requestedCount,
                  chunk.elementsEqual(expected[offset..<(offset + chunk.count)]) else {
                return false
            }
            offset += chunk.count
        }

        guard let trailing = try? handle.read(upToCount: 1) else { return false }
        return trailing.isEmpty
    }
}
