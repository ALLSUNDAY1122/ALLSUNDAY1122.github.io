import CryptoKit
import Foundation

/// Integrity gate for C-owned archived Mesh results.
///
/// `MeshProjectStore` snapshots B's finished `.meshproject` before B may delete its working copy.
/// This sidecar binds the archived result to the C library manifest and then re-hashes the result
/// whenever a saved Mesh is opened or exported. Byte length alone is not sufficient because a
/// same-size replacement can still be a different 3D asset.
enum MeshProjectIntegrity {
    static let evidenceFileName = "mesh-result.sha256.json"

    struct Evidence: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1

        let schemaVersion: Int
        let resultFileName: String
        let resultByteCount: Int64
        let sourceResultModificationDate: Date
        let archivedAt: Date
        let sha256: String
        let sealedAt: Date

        init(
            manifest: MeshProjectStore.LibraryManifest,
            sha256: String,
            sealedAt: Date = Date()
        ) {
            self.schemaVersion = Self.currentSchemaVersion
            self.resultFileName = manifest.resultFileName
            self.resultByteCount = manifest.resultByteCount
            self.sourceResultModificationDate = manifest.sourceResultModificationDate
            self.archivedAt = manifest.archivedAt
            self.sha256 = sha256
            self.sealedAt = sealedAt
        }

        func matches(_ manifest: MeshProjectStore.LibraryManifest) -> Bool {
            schemaVersion == Self.currentSchemaVersion &&
                resultFileName == manifest.resultFileName &&
                resultByteCount == manifest.resultByteCount &&
                abs(sourceResultModificationDate.timeIntervalSince(manifest.sourceResultModificationDate)) < 0.001 &&
                abs(archivedAt.timeIntervalSince(manifest.archivedAt)) < 0.001 &&
                !sha256.isEmpty
        }
    }

    enum IntegrityError: LocalizedError, Equatable {
        case manifestMissing
        case resultMissing
        case resultChangedAfterArchive
        case resultChangedDuringVerification
        case hashMismatch

        var errorDescription: String? {
            switch self {
            case .manifestMissing:
                return "保存済みMeshの完成記録を確認できません。"
            case .resultMissing:
                return "保存済みMeshの3Dデータが見つかりません。"
            case .resultChangedAfterArchive:
                return "保存後にMeshデータが変更されています。元のスキャンから保存し直してください。"
            case .resultChangedDuringVerification:
                return "Meshデータの確認中に内容が変化しました。もう一度開いてください。"
            case .hashMismatch:
                return "保存済みMeshの内容が完成時の記録と一致しません。元のスキャンから保存し直してください。"
            }
        }
    }

    @discardableResult
    static func verifyOrSeal(
        summary: MeshProjectSummary,
        fileManager: FileManager = .default
    ) throws -> URL {
        let manifestURL = summary.projectURL.appendingPathComponent(MeshProjectStore.libraryManifestFileName)
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw IntegrityError.manifestMissing
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(MeshProjectStore.LibraryManifest.self, from: manifestData),
              manifest.schemaVersion == MeshProjectStore.LibraryManifest.currentSchemaVersion else {
            throw IntegrityError.manifestMissing
        }

        let resultURL = summary.projectURL.appendingPathComponent(manifest.resultFileName)
        let standardizedProject = summary.projectURL.standardizedFileURL.resolvingSymlinksInPath()
        let standardizedResult = resultURL.standardizedFileURL.resolvingSymlinksInPath()
        let projectPrefix = standardizedProject.path.hasSuffix("/")
            ? standardizedProject.path
            : standardizedProject.path + "/"
        guard standardizedResult.path.hasPrefix(projectPrefix) else {
            throw IntegrityError.resultMissing
        }

        let before = try snapshot(resultURL, fileManager: fileManager)
        guard before.byteCount == manifest.resultByteCount else {
            throw IntegrityError.hashMismatch
        }

        let evidenceURL = summary.projectURL.appendingPathComponent(evidenceFileName)
        if let data = try? Data(contentsOf: evidenceURL),
           let evidence = try? decoder.decode(Evidence.self, from: data),
           evidence.matches(manifest) {
            let hash = try sha256Hex(fileURL: resultURL)
            let after = try snapshot(resultURL, fileManager: fileManager)
            guard after == before else { throw IntegrityError.resultChangedDuringVerification }
            guard hash == evidence.sha256 else { throw IntegrityError.hashMismatch }
            return resultURL
        }

        // The store writes archivedAt after snapshotting the result and also records the exact
        // source result mtime. Refuse to create a first trust seal if those bytes were replaced
        // after archival, even if a replacement happens to have the same byte count.
        guard abs(before.modificationDate.timeIntervalSince(manifest.sourceResultModificationDate)) < 0.001,
              before.modificationDate <= manifest.archivedAt.addingTimeInterval(0.001) else {
            throw IntegrityError.resultChangedAfterArchive
        }

        let hash = try sha256Hex(fileURL: resultURL)
        let after = try snapshot(resultURL, fileManager: fileManager)
        guard after == before else { throw IntegrityError.resultChangedDuringVerification }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Evidence(manifest: manifest, sha256: hash)).write(to: evidenceURL, options: .atomic)
        return resultURL
    }

    private struct FileSnapshot: Equatable {
        let byteCount: Int64
        let modificationDate: Date
    }

    private static func snapshot(_ url: URL, fileManager: FileManager) throws -> FileSnapshot {
        guard fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date,
              size.int64Value > 0 else {
            throw IntegrityError.resultMissing
        }
        return FileSnapshot(byteCount: size.int64Value, modificationDate: modificationDate)
    }

    private static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
