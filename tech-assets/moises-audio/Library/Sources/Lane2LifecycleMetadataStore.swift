import Foundation

public enum Lane2LifecycleOperation: String, Codable, Hashable, Sendable {
    case importAudio
    case exportAudio
    case storagePreflight
}

public enum Lane2ExportState: String, Codable, Hashable, Sendable {
    case ready
    case deleting
}

public struct Lane2ProjectOwnershipRecord: Codable, Hashable, Sendable {
    public let projectUUID: UUID
    public let sourceAssetUUID: UUID
    public let sourceRelativePath: String
    public let updatedAt: Date
}

public struct Lane2ExportRecord: Codable, Hashable, Sendable {
    public let id: UUID
    public let projectUUID: UUID
    public let relativePath: String
    public let mediaType: String
    public let createdAt: Date
    public let state: Lane2ExportState
}

public struct Lane2FailureRecord: Codable, Hashable, Sendable {
    public let attemptUUID: UUID
    public let projectUUID: UUID?
    public let operation: Lane2LifecycleOperation
    public let stableCode: String
    public let retryable: Bool
    public let createdAt: Date
}

public struct Lane2LifecycleSnapshot: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let projects: [Lane2ProjectOwnershipRecord]
    public let exports: [Lane2ExportRecord]
    public let failures: [Lane2FailureRecord]

    public init(
        schemaVersion: Int = 1,
        projects: [Lane2ProjectOwnershipRecord] = [],
        exports: [Lane2ExportRecord] = [],
        failures: [Lane2FailureRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.projects = projects
        self.exports = exports
        self.failures = failures
    }
}

public enum Lane2LifecycleMetadataFailure: Error, Equatable, Sendable {
    case corruptDocument
    case unsupportedSchema(Int)
    case invalidRelativePath(String)
    case corruptShard(String)
    case quarantineFailed(String)
}

public struct Lane2LifecycleQuarantineReport: Equatable, Sendable {
    public let quarantinedRelativePaths: [String]

    public init(quarantinedRelativePaths: [String]) {
        self.quarantinedRelativePaths = quarantinedRelativePaths.sorted()
    }
}

/// Lane-local durable metadata for IO lifecycle details that do not exist in frozen Shared contracts.
///
/// Storage revision 2 keeps one small ownership shard per project, one export shard per project,
/// and one bounded failure-history document. This avoids rewriting the entire library sidecar for
/// ordinary single-project edits while preserving the public API and the legacy v1 document.
///
/// Migration is idempotent and crash-safe: v2 is authoritative only after its marker is written.
/// A corrupt shard fails closed in normal reads. Recovery APIs preserve raw corrupt bytes in a
/// quarantine directory; they never remove user audio/project content.
public actor Lane2LifecycleMetadataStore {
    public let rootURL: URL
    public let documentURL: URL

    private struct V2Marker: Codable, Sendable {
        let schemaVersion: Int
    }

    private let storageSchemaVersion = 2
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.documentURL = self.rootURL
            .appendingPathComponent(".LibraryLifecycle", isDirectory: true)
            .appendingPathComponent("lane2-lifecycle-v1.json", isDirectory: false)
        self.fileManager = fileManager
    }

    public func snapshot() throws -> Lane2LifecycleSnapshot {
        try ensureV2Ready()
        return Lane2LifecycleSnapshot(
            projects: try loadProjects(),
            exports: try loadAllExports(),
            failures: try loadFailures()
        )
    }

    public func upsertProjectOwnership(
        projectUUID: UUID,
        sourceAssetUUID: UUID,
        sourceRelativePath: String,
        now: Date = Date()
    ) throws {
        try Self.validate(relativePath: sourceRelativePath)
        try ensureV2Ready()
        let record = Lane2ProjectOwnershipRecord(
            projectUUID: projectUUID,
            sourceAssetUUID: sourceAssetUUID,
            sourceRelativePath: sourceRelativePath,
            updatedAt: now
        )
        try writeCodable(record, to: projectShardURL(projectUUID: projectUUID))
    }

    public func recordExports(
        projectUUID: UUID,
        artifacts: [(relativePath: String, mediaType: String)],
        now: Date = Date()
    ) throws -> [Lane2ExportRecord] {
        try artifacts.forEach { try Self.validate(relativePath: $0.relativePath) }
        try ensureV2Ready()
        let records = artifacts.map {
            Lane2ExportRecord(
                id: UUID(),
                projectUUID: projectUUID,
                relativePath: $0.relativePath,
                mediaType: $0.mediaType,
                createdAt: now,
                state: .ready
            )
        }
        let existing = try loadExports(projectUUID: projectUUID)
        let updated = (existing + records).sorted(by: Self.exportOrder)
        try writeExports(updated, projectUUID: projectUUID)
        return records
    }

    /// Marks exports as deleting before any file is removed. Relaunch can resume safely.
    public func beginExportCleanup(projectUUID: UUID) throws -> [Lane2ExportRecord] {
        try ensureV2Ready()
        let existing = try loadExports(projectUUID: projectUUID)
        let selected = existing.map { record in
            Lane2ExportRecord(
                id: record.id,
                projectUUID: record.projectUUID,
                relativePath: record.relativePath,
                mediaType: record.mediaType,
                createdAt: record.createdAt,
                state: .deleting
            )
        }
        if !selected.isEmpty {
            try writeExports(selected, projectUUID: projectUUID)
        }
        return selected
    }

    public func pendingExportCleanup() throws -> [Lane2ExportRecord] {
        try ensureV2Ready()
        return try loadAllExports().filter { $0.state == .deleting }
    }

    public func finishExportCleanup(exportID: UUID) throws {
        try ensureV2Ready()
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        for fileURL in try jsonFiles(in: exportsDirectoryURL) {
            let projectUUID = try shardUUID(from: fileURL)
            let existing = try loadExports(projectUUID: projectUUID)
            guard existing.contains(where: { $0.id == exportID }) else { continue }
            let updated = existing.filter { $0.id != exportID }
            if updated.isEmpty {
                do {
                    try boundary.requireExistingRegularFile(
                        fileURL,
                        within: exportsDirectoryURL,
                        fileManager: fileManager
                    )
                    try fileManager.removeItem(at: fileURL)
                } catch {
                    throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(fileURL))
                }
            } else {
                try writeExports(updated, projectUUID: projectUUID)
            }
            return
        }
    }

    public func recordFailure(_ record: Lane2FailureRecord, maximumHistory: Int = 64) throws {
        try ensureV2Ready()
        let history = try loadFailures().filter { $0.attemptUUID != record.attemptUUID } + [record]
        let bounded = Array(history.suffix(max(maximumHistory, 1)))
        try writeCodable(bounded, to: failureHistoryURL)
    }

    public func latestFailure(projectUUID: UUID?) throws -> Lane2FailureRecord? {
        try ensureV2Ready()
        return try loadFailures().last { projectUUID == nil || $0.projectUUID == projectUUID }
    }

    public func removeProjectMetadata(projectUUID: UUID) throws {
        try ensureV2Ready()
        let url = projectShardURL(projectUUID: projectUUID)
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return }
            try boundary.requireExistingRegularFile(
                url,
                within: projectsDirectoryURL,
                fileManager: fileManager
            )
            try fileManager.removeItem(at: url)
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
        }
    }

    /// Explicit recovery operation. Valid shards are never moved. Corrupt shard bytes are preserved
    /// verbatim in Quarantine and normal snapshots can resume with the remaining valid metadata.
    @discardableResult
    public func quarantineCorruptShards() throws -> Lane2LifecycleQuarantineReport {
        try ensureV2Ready()
        var moved: [String] = []

        for url in try jsonFiles(in: projectsDirectoryURL) {
            do {
                _ = try loadProjectShard(at: url)
            } catch Lane2LifecycleMetadataFailure.corruptShard {
                moved.append(try quarantine(url))
            }
        }
        for url in try jsonFiles(in: exportsDirectoryURL) {
            do {
                _ = try loadExportShard(at: url)
            } catch Lane2LifecycleMetadataFailure.corruptShard {
                moved.append(try quarantine(url))
            }
        }
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        if (try? boundary.nodeExists(failureHistoryURL, fileManager: fileManager)) == true {
            do {
                _ = try loadFailures()
            } catch Lane2LifecycleMetadataFailure.corruptShard {
                moved.append(try quarantine(failureHistoryURL))
            }
        }
        return Lane2LifecycleQuarantineReport(quarantinedRelativePaths: moved)
    }

    /// Explicit legacy recovery for a malformed v1 sidecar. The raw document is preserved and an
    /// empty v2 sidecar is initialized so canonical Library data can be reconciled back in by the
    /// coordinator. Unsupported future schema is not treated as corruption and remains untouched.
    @discardableResult
    public func quarantineCorruptLegacyDocument() throws -> String? {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            guard try boundary.nodeExists(lifecycleDirectoryURL, fileManager: fileManager) else { return nil }
            try boundary.requireDirectory(lifecycleDirectoryURL, fileManager: fileManager)
            if try boundary.nodeExists(markerURL, fileManager: fileManager) {
                try boundary.requireExistingRegularFile(
                    markerURL,
                    within: v2DirectoryURL,
                    fileManager: fileManager
                )
                return nil
            }
            guard try boundary.requireRegularFileOrMissing(
                documentURL,
                within: lifecycleDirectoryURL,
                fileManager: fileManager
            ) else { return nil }
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptDocument
        }
        do {
            _ = try loadLegacyV1()
            return nil
        } catch Lane2LifecycleMetadataFailure.unsupportedSchema {
            throw try unsupportedSchemaFailureFromLegacy()
        } catch Lane2LifecycleMetadataFailure.corruptDocument {
            let preserved = try quarantine(documentURL)
            try initializeEmptyV2()
            return preserved
        } catch Lane2LifecycleMetadataFailure.invalidRelativePath {
            let preserved = try quarantine(documentURL)
            try initializeEmptyV2()
            return preserved
        }
    }

    private func ensureV2Ready() throws {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            try boundary.ensureRootDirectory(fileManager: fileManager)
            if try boundary.nodeExists(lifecycleDirectoryURL, fileManager: fileManager) {
                try boundary.requireDirectory(lifecycleDirectoryURL, fileManager: fileManager)
            }

            if try boundary.nodeExists(markerURL, fileManager: fileManager) {
                try boundary.requireExistingRegularFile(
                    markerURL,
                    within: v2DirectoryURL,
                    fileManager: fileManager
                )
                let marker: V2Marker
                do {
                    marker = try decode(V2Marker.self, from: markerURL)
                } catch {
                    throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(markerURL))
                }
                guard marker.schemaVersion == storageSchemaVersion else {
                    throw Lane2LifecycleMetadataFailure.unsupportedSchema(marker.schemaVersion)
                }
                return
            }

            if try boundary.nodeExists(documentURL, fileManager: fileManager) {
                try boundary.requireExistingRegularFile(
                    documentURL,
                    within: lifecycleDirectoryURL,
                    fileManager: fileManager
                )
                let legacy = try loadLegacyV1()
                try migrateLegacy(legacy)
            } else {
                try initializeEmptyV2()
            }
        } catch let failure as Lane2LifecycleMetadataFailure {
            throw failure
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(lifecycleDirectoryURL))
        }
    }

    private func migrateLegacy(_ legacy: Lane2LifecycleSnapshot) throws {
        // An unmarked v2 tree is never authoritative; discard only that metadata staging area.
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        if try boundary.nodeExists(v2DirectoryURL, fileManager: fileManager) {
            do {
                try boundary.requireDirectory(v2DirectoryURL, fileManager: fileManager)
                try fileManager.removeItem(at: v2DirectoryURL)
            } catch {
                throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(v2DirectoryURL))
            }
        }
        try createV2Directories()
        for project in legacy.projects {
            try writeCodable(project, to: projectShardURL(projectUUID: project.projectUUID))
        }
        let grouped = Dictionary(grouping: legacy.exports, by: \.projectUUID)
        for (projectUUID, records) in grouped {
            try writeExports(records.sorted(by: Self.exportOrder), projectUUID: projectUUID)
        }
        if !legacy.failures.isEmpty {
            try writeCodable(legacy.failures, to: failureHistoryURL)
        }
        try writeCodable(V2Marker(schemaVersion: storageSchemaVersion), to: markerURL)
    }

    private func initializeEmptyV2() throws {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        if try boundary.nodeExists(v2DirectoryURL, fileManager: fileManager),
           !(try boundary.nodeExists(markerURL, fileManager: fileManager)) {
            do {
                try boundary.requireDirectory(v2DirectoryURL, fileManager: fileManager)
                try fileManager.removeItem(at: v2DirectoryURL)
            } catch {
                throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(v2DirectoryURL))
            }
        }
        try createV2Directories()
        try writeCodable(V2Marker(schemaVersion: storageSchemaVersion), to: markerURL)
    }

    private func loadLegacyV1() throws -> Lane2LifecycleSnapshot {
        do {
            let value = try decode(Lane2LifecycleSnapshot.self, from: documentURL)
            guard value.schemaVersion == 1 else {
                throw Lane2LifecycleMetadataFailure.unsupportedSchema(value.schemaVersion)
            }
            try value.projects.forEach { try Self.validate(relativePath: $0.sourceRelativePath) }
            try value.exports.forEach { try Self.validate(relativePath: $0.relativePath) }
            return value
        } catch let failure as Lane2LifecycleMetadataFailure {
            throw failure
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptDocument
        }
    }

    private func unsupportedSchemaFailureFromLegacy() throws -> Lane2LifecycleMetadataFailure {
        let value = try decode(Lane2LifecycleSnapshot.self, from: documentURL)
        return .unsupportedSchema(value.schemaVersion)
    }

    private func loadProjects() throws -> [Lane2ProjectOwnershipRecord] {
        try jsonFiles(in: projectsDirectoryURL)
            .map(loadProjectShard)
            .sorted { $0.projectUUID.uuidString < $1.projectUUID.uuidString }
    }

    private func loadProjectShard(at url: URL) throws -> Lane2ProjectOwnershipRecord {
        do {
            let record = try decode(Lane2ProjectOwnershipRecord.self, from: url)
            try Self.validate(relativePath: record.sourceRelativePath)
            guard try shardUUID(from: url) == record.projectUUID else {
                throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
            }
            return record
        } catch let failure as Lane2LifecycleMetadataFailure {
            if case .invalidRelativePath = failure {
                throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
            }
            throw failure
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
        }
    }

    private func loadAllExports() throws -> [Lane2ExportRecord] {
        try jsonFiles(in: exportsDirectoryURL)
            .flatMap(loadExportShard)
            .sorted(by: Self.exportOrder)
    }

    private func loadExports(projectUUID: UUID) throws -> [Lane2ExportRecord] {
        let url = exportShardURL(projectUUID: projectUUID)
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return [] }
            try boundary.requireExistingRegularFile(
                url,
                within: exportsDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
        }
        return try loadExportShard(at: url)
    }

    private func loadExportShard(at url: URL) throws -> [Lane2ExportRecord] {
        do {
            let projectUUID = try shardUUID(from: url)
            let records = try decode([Lane2ExportRecord].self, from: url)
            for record in records {
                guard record.projectUUID == projectUUID else {
                    throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
                }
                try Self.validate(relativePath: record.relativePath)
            }
            let ids = Set(records.map(\.id))
            guard ids.count == records.count else {
                throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
            }
            return records.sorted(by: Self.exportOrder)
        } catch let failure as Lane2LifecycleMetadataFailure {
            if case .invalidRelativePath = failure {
                throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
            }
            throw failure
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
        }
    }

    private func writeExports(_ records: [Lane2ExportRecord], projectUUID: UUID) throws {
        guard records.allSatisfy({ $0.projectUUID == projectUUID }) else {
            throw Lane2LifecycleMetadataFailure.corruptShard(projectUUID.uuidString + ".json")
        }
        try records.forEach { try Self.validate(relativePath: $0.relativePath) }
        try writeCodable(records.sorted(by: Self.exportOrder), to: exportShardURL(projectUUID: projectUUID))
    }

    private func loadFailures() throws -> [Lane2FailureRecord] {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            guard try boundary.nodeExists(failureHistoryURL, fileManager: fileManager) else { return [] }
            try boundary.requireExistingRegularFile(
                failureHistoryURL,
                within: v2DirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(failureHistoryURL))
        }
        do {
            return try decode([Lane2FailureRecord].self, from: failureHistoryURL)
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(failureHistoryURL))
        }
    }

    private func quarantine(_ sourceURL: URL) throws -> String {
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            try boundary.requireExistingRegularFile(
                sourceURL,
                within: lifecycleDirectoryURL,
                fileManager: fileManager
            )
            try boundary.ensureDirectory(quarantineDirectoryURL, fileManager: fileManager)
            let destination = quarantineDirectoryURL.appendingPathComponent(
                UUID().uuidString.lowercased() + "-" + sourceURL.lastPathComponent,
                isDirectory: false
            )
            try boundary.requireSafeDestination(
                destination,
                within: quarantineDirectoryURL,
                fileManager: fileManager
            )
            try fileManager.moveItem(at: sourceURL, to: destination)
            try boundary.requireExistingRegularFile(
                destination,
                within: quarantineDirectoryURL,
                fileManager: fileManager
            )
            return relativeName(destination)
        } catch {
            throw Lane2LifecycleMetadataFailure.quarantineFailed(relativeName(sourceURL))
        }
    }

    private func jsonFiles(in directory: URL) throws -> [URL] {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            guard try boundary.nodeExists(directory, fileManager: fileManager) else { return [] }
            try boundary.requireDirectory(directory, fileManager: fileManager)
            let candidates = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for candidate in candidates {
                try boundary.requireExistingRegularFile(
                    candidate,
                    within: directory,
                    fileManager: fileManager
                )
            }
            return candidates
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(directory))
        }
    }

    private func shardUUID(from url: URL) throws -> UUID {
        guard let value = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
        }
        return value
    }

    private func createV2Directories() throws {
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            try boundary.ensureDirectory(projectsDirectoryURL, fileManager: fileManager)
            try boundary.ensureDirectory(exportsDirectoryURL, fileManager: fileManager)
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(v2DirectoryURL))
        }
    }

    private func writeCodable<T: Encodable>(_ value: T, to url: URL) throws {
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            try boundary.ensureDirectory(url.deletingLastPathComponent(), fileManager: fileManager)
            _ = try boundary.requireRegularFileOrMissing(
                url,
                within: url.deletingLastPathComponent(),
                fileManager: fileManager
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(value).write(to: url, options: [.atomic])
            try boundary.requireExistingRegularFile(
                url,
                within: url.deletingLastPathComponent(),
                fileManager: fileManager
            )
        } catch let failure as Lane2LifecycleMetadataFailure {
            throw failure
        } catch {
            throw Lane2LifecycleMetadataFailure.corruptShard(relativeName(url))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        do {
            try LibraryManagedPathBoundary(rootURL: rootURL).requireExistingRegularFile(
                url,
                within: rootURL,
                fileManager: fileManager
            )
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: Data(contentsOf: url))
        } catch let failure as Lane2LifecycleMetadataFailure {
            throw failure
        } catch {
            throw error
        }
    }

    private var lifecycleDirectoryURL: URL { documentURL.deletingLastPathComponent() }
    private var v2DirectoryURL: URL { lifecycleDirectoryURL.appendingPathComponent("v2", isDirectory: true) }
    private var projectsDirectoryURL: URL { v2DirectoryURL.appendingPathComponent("projects", isDirectory: true) }
    private var exportsDirectoryURL: URL { v2DirectoryURL.appendingPathComponent("exports", isDirectory: true) }
    private var markerURL: URL { v2DirectoryURL.appendingPathComponent("schema.json", isDirectory: false) }
    private var failureHistoryURL: URL { v2DirectoryURL.appendingPathComponent("failures.json", isDirectory: false) }
    private var quarantineDirectoryURL: URL { lifecycleDirectoryURL.appendingPathComponent("Quarantine", isDirectory: true) }

    private func projectShardURL(projectUUID: UUID) -> URL {
        projectsDirectoryURL.appendingPathComponent(projectUUID.uuidString + ".json", isDirectory: false)
    }

    private func exportShardURL(projectUUID: UUID) -> URL {
        exportsDirectoryURL.appendingPathComponent(projectUUID.uuidString + ".json", isDirectory: false)
    }

    private func relativeName(_ url: URL) -> String {
        let root = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : url.lastPathComponent
    }

    private static func exportOrder(_ lhs: Lane2ExportRecord, _ rhs: Lane2ExportRecord) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.createdAt < rhs.createdAt
    }

    private static func validate(relativePath: String) throws {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2LifecycleMetadataFailure.invalidRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2LifecycleMetadataFailure.invalidRelativePath(relativePath)
        }
    }
}
