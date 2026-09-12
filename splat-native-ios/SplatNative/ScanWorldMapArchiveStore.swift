import Foundation

enum ScanWorldMapArchiveStoreError: LocalizedError {
    case emptyArchive
    case missingParentDirectory
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .emptyArchive: return "WorldMap archiveが空です"
        case .missingParentDirectory: return "WorldMap保存先projectがありません"
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

        try data.write(to: targetURL, options: .atomic)
        let values = try targetURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              values.fileSize == data.count else {
            throw ScanWorldMapArchiveStoreError.verificationFailed
        }
    }
}
