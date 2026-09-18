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
        try Task.checkCancellation()
        guard !data.isEmpty else { throw ScanWorldMapArchiveStoreError.emptyArchive }
        let parent = targetURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanWorldMapArchiveStoreError.missingParentDirectory
        }
        guard let parentValues = try? parent.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ), parentValues.isDirectory == true, parentValues.isSymbolicLink != true else {
            throw ScanWorldMapArchiveStoreError.unsafeParentDirectory
        }

        let candidateURL = parent.appendingPathComponent(
            ".\(targetURL.lastPathComponent).\(UUID().uuidString).candidate",
            isDirectory: false
        )
        defer { try? FileManager.default.removeItem(at: candidateURL) }

        try data.write(to: candidateURL, options: .atomic)
        try Task.checkCancellation()

        do {
            let handle = try FileHandle(forWritingTo: candidateURL)
            defer { try? handle.close() }
            try handle.synchronize()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ScanWorldMapArchiveStoreError.verificationFailed
        }
        try Task.checkCancellation()

        let values = try candidateURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true,
              try fileContentsEqual(data, at: candidateURL) else {
            throw ScanWorldMapArchiveStoreError.verificationFailed
        }
        try Task.checkCancellation()

        if FileManager.default.fileExists(atPath: targetURL.path) {
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

    private static func fileContentsEqual(_ expected: Data, at url: URL) throws -> Bool {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            return false
        }
        defer { try? handle.close() }

        var offset = 0
        while offset < expected.count {
            try Task.checkCancellation()
            let requestedCount = min(verificationChunkByteCount, expected.count - offset)
            let chunk: Data
            do {
                chunk = try handle.read(upToCount: requestedCount) ?? Data()
            } catch {
                return false
            }
            guard !chunk.isEmpty,
                  chunk.count <= requestedCount,
                  chunk.elementsEqual(expected[offset..<(offset + chunk.count)]) else {
                return false
            }
            offset += chunk.count
        }

        try Task.checkCancellation()
        do {
            return try handle.read(upToCount: 1)?.isEmpty ?? true
        } catch {
            return false
        }
    }
}
