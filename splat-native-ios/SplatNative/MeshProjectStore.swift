import Darwin
import Foundation

struct MeshProjectSummary: Identifiable, Equatable, Sendable {
    let id: String
    let projectURL: URL
    let resultURL: URL
    let captureMode: String
    let scanSize: String
    let createdAt: Date
    let updatedAt: Date
    let rawDataRetained: Bool
    let reprocessSupported: Bool
    let storageBytes: Int64

    var title: String {
        captureMode == "lidar" ? "LiDARメッシュ" : "写真からメッシュ"
    }
}

enum MeshProjectStoreError: LocalizedError {
    case invalidProject
    case resultMissing
    case archiveMissing
    case insufficientStorage(required: Int64, available: Int64)

    var errorDescription: String? {
        switch self {
        case .invalidProject:
            return "Meshプロジェクトを保存済みライブラリとして確認できません。"
        case .resultMissing:
            return "完成したMesh結果が見つかりません。"
        case .archiveMissing:
            return "保存済みMeshが見つかりません。"
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "Meshを安全に保存する空き容量が不足しています（必要 約\(formatter.string(fromByteCount: required)) / 空き 約\(formatter.string(fromByteCount: available))）。"
        }
    }
}

/// Durable C-owned storage for B's finished `.meshproject` working directories.
///
/// B currently deletes its working directory from `MeshScanModel.reset()`. C therefore snapshots
/// a finished project outside B's working root before reset can destroy it. Because both locations
/// are normally on the same APFS volume, regular files are cloned copy-on-write first: deleting or
/// mutating B's working files cannot mutate the archived library while unchanged extents remain
/// storage-efficient. Filesystems that reject clones fall back to a capacity-checked physical copy.
final class MeshProjectStore {
    static let projectExtension = "meshproject"
    static let sourceManifestFileName = "mesh-project.json"
    static let libraryManifestFileName = "mesh-library.json"
    static let libraryDirectoryName = "MeshLibrary"
    static let trashDirectoryName = ".Trash"

    struct LibraryManifest: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1

        var schemaVersion: Int
        var id: String
        var captureMode: String
        var scanSize: String
        var createdAt: Date
        var archivedAt: Date
        var resultFileName: String
        var resultByteCount: Int64
        var sourceResultModificationDate: Date
        var rawDataRetained: Bool
        var reprocessSupported: Bool

        init(
            id: String,
            captureMode: String,
            scanSize: String,
            createdAt: Date,
            archivedAt: Date = Date(),
            resultFileName: String,
            resultByteCount: Int64,
            sourceResultModificationDate: Date,
            rawDataRetained: Bool,
            reprocessSupported: Bool
        ) {
            self.schemaVersion = Self.currentSchemaVersion
            self.id = id
            self.captureMode = captureMode
            self.scanSize = scanSize
            self.createdAt = createdAt
            self.archivedAt = archivedAt
            self.resultFileName = resultFileName
            self.resultByteCount = resultByteCount
            self.sourceResultModificationDate = sourceResultModificationDate
            self.rawDataRetained = rawDataRetained
            self.reprocessSupported = reprocessSupported
        }
    }

    private struct SourceManifest: Decodable {
        let captureMode: String
        let scanSize: String
        let createdAt: Date
    }

    let appRootURL: URL
    let libraryURL: URL
    let trashURL: URL
    private let fileManager: FileManager

    init(appRootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let appRootURL {
            self.appRootURL = appRootURL
        } else {
            self.appRootURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SplatLab", isDirectory: true)
        }
        self.libraryURL = self.appRootURL
            .appendingPathComponent(Self.libraryDirectoryName, isDirectory: true)
        self.trashURL = self.libraryURL
            .appendingPathComponent(Self.trashDirectoryName, isDirectory: true)
        try? ensureDirectories()
    }

    func listProjects() -> [MeshProjectSummary] {
        summaries(in: libraryURL, includeHidden: false)
    }

    func listTrash() -> [MeshProjectSummary] {
        summaries(in: trashURL, includeHidden: true)
    }

    func adoptLegacyCompletedProjects() {
        try? ensureDirectories()
        let children = (try? fileManager.contentsOfDirectory(
            at: appRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for projectURL in children where projectURL.pathExtension.lowercased() == Self.projectExtension {
            guard let resultURL = bestFinishedResult(in: projectURL) else { continue }
            _ = try? archiveFinishedProject(resultURL: resultURL)
        }
    }

    @discardableResult
    func archiveFinishedProject(resultURL: URL) throws -> MeshProjectSummary {
        try ensureDirectories()
        guard resultURL.isFileURL,
              fileManager.fileExists(atPath: resultURL.path) else {
            throw MeshProjectStoreError.resultMissing
        }

        let sourceProjectURL = resultURL.deletingLastPathComponent()
        guard sourceProjectURL.pathExtension.lowercased() == Self.projectExtension else {
            throw MeshProjectStoreError.invalidProject
        }

        if sourceProjectURL.deletingLastPathComponent().standardizedFileURL == libraryURL.standardizedFileURL {
            return try summary(at: sourceProjectURL)
        }

        // A durable library entry must never depend on aliases outside its own project tree.
        // Reject symlinked roots, symlinked descendants, and special filesystem nodes before any
        // metadata is derived or a snapshot begins. Recheck before physical-copy fallback too.
        try validateSnapshotTree(at: sourceProjectURL)

        let relativeResultPath = try relativePath(of: resultURL, inside: sourceProjectURL)
        let resultSnapshot = try regularFileSnapshot(at: resultURL)
        guard resultSnapshot.byteCount > 0 else { throw MeshProjectStoreError.resultMissing }

        let sourceManifest = readSourceManifest(projectURL: sourceProjectURL)
        let projectID = sourceProjectURL.deletingPathExtension().lastPathComponent
        guard !projectID.isEmpty else { throw MeshProjectStoreError.invalidProject }
        let imagesURL = sourceProjectURL.appendingPathComponent("images", isDirectory: true)
        let rawRetained = MeshRawInputValidator.hasAnyRawImageBytes(
            in: imagesURL,
            fileManager: fileManager
        )
        let captureMode = sourceManifest?.captureMode ?? "unknown"
        let scanSize = sourceManifest?.scanSize ?? "unknown"
        let createdAt = sourceManifest?.createdAt
            ?? directoryDate(sourceProjectURL, key: .creationDate)
            ?? resultSnapshot.modificationDate
        let reprocessSupported = captureMode == "photogrammetry" &&
            MeshRawInputValidator.hasMinimumUsableImages(in: imagesURL, fileManager: fileManager)

        let finalURL = libraryURL
            .appendingPathComponent(projectID)
            .appendingPathExtension(Self.projectExtension)

        if let existing = try? readLibraryManifest(projectURL: finalURL),
           existing.resultFileName == relativeResultPath,
           existing.resultByteCount == resultSnapshot.byteCount,
           abs(existing.sourceResultModificationDate.timeIntervalSince(resultSnapshot.modificationDate)) < 0.001,
           let existingSummary = try? summary(at: finalURL) {
            return existingSummary
        }

        let temporaryURL = libraryURL
            .appendingPathComponent(".\(projectID)-\(UUID().uuidString).partial")
            .appendingPathExtension(Self.projectExtension)
        try? fileManager.removeItem(at: temporaryURL)

        do {
            do {
                try cloneSnapshotTree(from: sourceProjectURL, to: temporaryURL)
            } catch {
                try? fileManager.removeItem(at: temporaryURL)
                try validateSnapshotTree(at: sourceProjectURL)
                try preflightPhysicalCopy(of: sourceProjectURL)
                try fileManager.copyItem(at: sourceProjectURL, to: temporaryURL)
            }

            let archivedResultURL = temporaryURL.appendingPathComponent(relativeResultPath)
            let archivedSnapshot = try regularFileSnapshot(at: archivedResultURL)
            guard archivedSnapshot.byteCount == resultSnapshot.byteCount else {
                throw MeshProjectStoreError.resultMissing
            }

            let metadata = LibraryManifest(
                id: projectID,
                captureMode: captureMode,
                scanSize: scanSize,
                createdAt: createdAt,
                resultFileName: relativeResultPath,
                resultByteCount: resultSnapshot.byteCount,
                sourceResultModificationDate: resultSnapshot.modificationDate,
                rawDataRetained: rawRetained,
                reprocessSupported: reprocessSupported
            )
            try writeLibraryManifest(metadata, projectURL: temporaryURL)
            try replaceDirectoryAtomically(temporaryURL: temporaryURL, finalURL: finalURL)
            return try summary(at: finalURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    func moveToTrash(projectURL: URL) throws {
        try ensureDirectories()
        try validateArchivedProjectRoot(projectURL)
        guard projectURL.deletingLastPathComponent().standardizedFileURL == libraryURL.standardizedFileURL,
              fileManager.fileExists(atPath: projectURL.path) else {
            throw MeshProjectStoreError.archiveMissing
        }
        let destination = trashURL.appendingPathComponent(projectURL.lastPathComponent, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: projectURL, to: destination)
    }

    func restoreFromTrash(id: String) throws {
        try ensureDirectories()
        let source = try validatedTrashProjectURL(id: id)
        guard fileManager.fileExists(atPath: source.path) else { throw MeshProjectStoreError.archiveMissing }
        try validateArchivedProjectRoot(source)

        var restoredID = id
        var destination = libraryURL.appendingPathComponent(restoredID).appendingPathExtension(Self.projectExtension)
        if fileManager.fileExists(atPath: destination.path) {
            restoredID = UUID().uuidString
            destination = libraryURL.appendingPathComponent(restoredID).appendingPathExtension(Self.projectExtension)
        }
        try fileManager.moveItem(at: source, to: destination)
        if restoredID != id {
            do {
                var manifest = try readLibraryManifest(projectURL: destination)
                guard manifest.id == id else { throw MeshProjectStoreError.invalidProject }
                manifest.id = restoredID
                try writeLibraryManifest(manifest, projectURL: destination)
            } catch {
                // Collision restore must be all-or-nothing. If the manifest cannot be rebound to
                // the generated ID, return the archive to Trash instead of leaving an invisible
                // library directory whose directory ID and manifest ID disagree.
                if !fileManager.fileExists(atPath: source.path),
                   fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.moveItem(at: destination, to: source)
                }
                throw error
            }
        }
    }

    func permanentlyDeleteFromTrash(id: String) throws {
        let target = try validatedTrashProjectURL(id: id)
        guard fileManager.fileExists(atPath: target.path) else { throw MeshProjectStoreError.archiveMissing }
        try validateArchivedProjectRoot(target)
        try fileManager.removeItem(at: target)
    }

    private func validatedTrashProjectURL(id: String) throws -> URL {
        guard !id.isEmpty, id != ".", id != "..",
              !id.contains("/"), !id.contains("\\"), !id.contains("\0") else {
            throw MeshProjectStoreError.invalidProject
        }
        let candidate = trashURL.appendingPathComponent(id).appendingPathExtension(Self.projectExtension).standardizedFileURL
        guard candidate.deletingLastPathComponent().standardizedFileURL == trashURL.standardizedFileURL,
              candidate.lastPathComponent == "\(id).\(Self.projectExtension)" else {
            throw MeshProjectStoreError.invalidProject
        }
        return candidate
    }

    private func summaries(in directory: URL, includeHidden: Bool) -> [MeshProjectSummary] {
        try? ensureDirectories()
        let children = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )) ?? []
        return children
            .filter { $0.pathExtension.lowercased() == Self.projectExtension }
            .compactMap { try? summary(at: $0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func summary(at projectURL: URL) throws -> MeshProjectSummary {
        try validateArchivedProjectRoot(projectURL)
        let manifest = try readLibraryManifest(projectURL: projectURL)
        let expectedID = projectURL.deletingPathExtension().lastPathComponent
        guard !expectedID.isEmpty, manifest.id == expectedID else {
            throw MeshProjectStoreError.invalidProject
        }
        let resultURL = try archivedResultURL(
            projectURL: projectURL,
            resultFileName: manifest.resultFileName
        )
        let resultSnapshot = try regularFileSnapshot(at: resultURL)
        guard resultSnapshot.byteCount == manifest.resultByteCount,
              resultSnapshot.byteCount > 0 else {
            throw MeshProjectStoreError.resultMissing
        }

        // Manifest flags are a historical snapshot. RAW may have been cleared, partially deleted,
        // or the archive may predate the stricter ImageIO eligibility contract. Recompute both
        // concepts from current bytes: retention is a privacy/storage fact, while reprocessing has
        // the stronger minimum-count + structural-readability requirement.
        let imagesURL = projectURL.appendingPathComponent("images", isDirectory: true)
        let rawRetained = MeshRawInputValidator.hasAnyRawImageBytes(
            in: imagesURL,
            fileManager: fileManager
        )
        let reprocessSupported = manifest.captureMode == "photogrammetry" &&
            MeshRawInputValidator.hasMinimumUsableImages(in: imagesURL, fileManager: fileManager)

        return MeshProjectSummary(
            id: manifest.id,
            projectURL: projectURL,
            resultURL: resultURL,
            captureMode: manifest.captureMode,
            scanSize: manifest.scanSize,
            createdAt: manifest.createdAt,
            updatedAt: manifest.archivedAt,
            rawDataRetained: rawRetained,
            reprocessSupported: reprocessSupported,
            storageBytes: logicalDirectorySize(projectURL)
        )
    }

    private func validateArchivedProjectRoot(_ projectURL: URL) throws {
        guard projectURL.isFileURL,
              projectURL.pathExtension.lowercased() == Self.projectExtension,
              let values = try? projectURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true,
              values.isSymbolicLink != true else {
            throw MeshProjectStoreError.invalidProject
        }
        let parent = projectURL.deletingLastPathComponent().standardizedFileURL
        guard parent == libraryURL.standardizedFileURL || parent == trashURL.standardizedFileURL else {
            throw MeshProjectStoreError.invalidProject
        }
    }

    private func readSourceManifest(projectURL: URL) -> SourceManifest? {
        let url = projectURL.appendingPathComponent(Self.sourceManifestFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SourceManifest.self, from: data)
    }

    private func readLibraryManifest(projectURL: URL) throws -> LibraryManifest {
        let url = projectURL.appendingPathComponent(Self.libraryManifestFileName)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LibraryManifest.self, from: data)
        guard manifest.schemaVersion == LibraryManifest.currentSchemaVersion else {
            throw MeshProjectStoreError.invalidProject
        }
        return manifest
    }

    private func writeLibraryManifest(_ manifest: LibraryManifest, projectURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: projectURL.appendingPathComponent(Self.libraryManifestFileName),
            options: .atomic
        )
    }

    private func bestFinishedResult(in projectURL: URL) -> URL? {
        let preferred = ["mesh-cropped.obj", "mesh-textured.usdz", "mesh.obj"]
        for name in preferred {
            let url = projectURL.appendingPathComponent(name)
            if (try? regularFileSnapshot(at: url).byteCount) ?? 0 > 0 { return url }
        }
        return nil
    }

    private func archivedResultURL(projectURL: URL, resultFileName: String) throws -> URL {
        let trimmed = resultFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let characters = Array(trimmed)
        let isWindowsAbsolute = characters.count >= 3 &&
            characters[1] == ":" &&
            (characters[2] == "\\" || characters[2] == "/")
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~"),
              !isWindowsAbsolute else {
            throw MeshProjectStoreError.invalidProject
        }

        let root = projectURL.standardizedFileURL
        let candidate = root.appendingPathComponent(trimmed).standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPrefix) else {
            throw MeshProjectStoreError.invalidProject
        }

        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        let resolvedPrefix = resolvedRoot.path.hasSuffix("/")
            ? resolvedRoot.path
            : resolvedRoot.path + "/"
        guard resolvedCandidate.path.hasPrefix(resolvedPrefix) else {
            throw MeshProjectStoreError.invalidProject
        }
        return candidate
    }

    private func validateSnapshotTree(at source: URL) throws {
        guard source.isFileURL,
              let rootValues = try? source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true,
              let enumerator = fileManager.enumerator(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: []
              ) else {
            throw MeshProjectStoreError.invalidProject
        }

        for case let itemURL as URL in enumerator {
            let values = try itemURL.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true,
                  values.isDirectory == true || values.isRegularFile == true else {
                throw MeshProjectStoreError.invalidProject
            }
        }
    }

    private func cloneSnapshotTree(from source: URL, to destination: URL) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else { throw MeshProjectStoreError.invalidProject }

        let prefix = source.standardizedFileURL.path.hasSuffix("/")
            ? source.standardizedFileURL.path
            : source.standardizedFileURL.path + "/"

        for case let itemURL as URL in enumerator {
            let standardized = itemURL.standardizedFileURL
            guard standardized.path.hasPrefix(prefix) else { throw MeshProjectStoreError.invalidProject }
            let relative = String(standardized.path.dropFirst(prefix.count))
            guard !relative.isEmpty else { continue }
            let target = destination.appendingPathComponent(relative)
            let values = try standardized.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw MeshProjectStoreError.invalidProject }
            if values.isDirectory == true {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            } else if values.isRegularFile == true {
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let cloned = standardized.withUnsafeFileSystemRepresentation { sourcePath in
                    target.withUnsafeFileSystemRepresentation { destinationPath in
                        guard let sourcePath, let destinationPath else { return false }
                        return clonefile(sourcePath, destinationPath, 0) == 0
                    }
                }
                if !cloned {
                    throw CocoaError(.fileWriteUnknown)
                }
            } else {
                throw MeshProjectStoreError.invalidProject
            }
        }
    }

    private func preflightPhysicalCopy(of source: URL) throws {
        let required = saturatingAdd(logicalDirectorySize(source), 64 * 1_024 * 1_024)
        guard let available = availableCapacity(at: libraryURL) else { return }
        if available < required {
            throw MeshProjectStoreError.insufficientStorage(required: required, available: available)
        }
    }

    private func replaceDirectoryAtomically(temporaryURL: URL, finalURL: URL) throws {
        let backupURL = libraryURL
            .appendingPathComponent(".\(finalURL.lastPathComponent)-\(UUID().uuidString).backup", isDirectory: true)
        var movedOld = false
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.moveItem(at: finalURL, to: backupURL)
            movedOld = true
        }
        do {
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
            if movedOld { try? fileManager.removeItem(at: backupURL) }
        } catch {
            if fileManager.fileExists(atPath: finalURL.path) { try? fileManager.removeItem(at: finalURL) }
            if movedOld, fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.moveItem(at: backupURL, to: finalURL)
            }
            throw error
        }
    }

    private func relativePath(of child: URL, inside parent: URL) throws -> String {
        let parentPath = parent.standardizedFileURL.path.hasSuffix("/")
            ? parent.standardizedFileURL.path
            : parent.standardizedFileURL.path + "/"
        let childPath = child.standardizedFileURL.path
        guard childPath.hasPrefix(parentPath) else { throw MeshProjectStoreError.invalidProject }
        let relative = String(childPath.dropFirst(parentPath.count))
        guard !relative.isEmpty, !relative.hasPrefix("../") else { throw MeshProjectStoreError.invalidProject }
        return relative
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: appRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: true)
    }

    private func regularFileSnapshot(at url: URL) throws -> (byteCount: Int64, modificationDate: Date) {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            throw MeshProjectStoreError.resultMissing
        }
        let modificationDate = (attributes[.modificationDate] as? Date) ?? Date.distantPast
        return (size.int64Value, modificationDate)
    }

    private func directoryDate(_ url: URL, key: FileAttributeKey) -> Date? {
        (try? fileManager.attributesOfItem(atPath: url.path)[key]) as? Date
    }

    private func logicalDirectorySize(_ url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total = saturatingAdd(total, Int64(values.fileSize ?? 0))
        }
        return total
    }

    private func availableCapacity(at url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: url.path),
           let free = attributes[.systemFreeSize] as? NSNumber {
            return free.int64Value
        }
        return nil
    }

    private func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        if lhs > Int64.max - rhs { return Int64.max }
        return lhs + rhs
    }
}
