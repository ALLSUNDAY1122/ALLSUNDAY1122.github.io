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
}

/// Lane-local durable metadata for IO lifecycle details that do not exist in frozen Shared contracts.
/// It never stores external provider URLs, bookmarks, runtime objects, or absolute paths.
public actor Lane2LifecycleMetadataStore {
    public let rootURL: URL
    public let documentURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
        self.documentURL = self.rootURL
            .appendingPathComponent(".LibraryLifecycle", isDirectory: true)
            .appendingPathComponent("lane2-lifecycle-v1.json", isDirectory: false)
    }

    public func snapshot() throws -> Lane2LifecycleSnapshot {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return Lane2LifecycleSnapshot()
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let value = try decoder.decode(Lane2LifecycleSnapshot.self, from: Data(contentsOf: documentURL))
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

    public func upsertProjectOwnership(
        projectUUID: UUID,
        sourceAssetUUID: UUID,
        sourceRelativePath: String,
        now: Date = Date()
    ) throws {
        try Self.validate(relativePath: sourceRelativePath)
        let value = try snapshot()
        var projects = value.projects.filter { $0.projectUUID != projectUUID }
        projects.append(
            Lane2ProjectOwnershipRecord(
                projectUUID: projectUUID,
                sourceAssetUUID: sourceAssetUUID,
                sourceRelativePath: sourceRelativePath,
                updatedAt: now
            )
        )
        try write(
            Lane2LifecycleSnapshot(
                projects: projects.sorted { $0.projectUUID.uuidString < $1.projectUUID.uuidString },
                exports: value.exports,
                failures: value.failures
            )
        )
    }

    public func recordExports(
        projectUUID: UUID,
        artifacts: [(relativePath: String, mediaType: String)],
        now: Date = Date()
    ) throws -> [Lane2ExportRecord] {
        try artifacts.forEach { try Self.validate(relativePath: $0.relativePath) }
        var value = try snapshot()
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
        value = Lane2LifecycleSnapshot(
            projects: value.projects,
            exports: (value.exports + records).sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.createdAt < rhs.createdAt
            },
            failures: value.failures
        )
        try write(value)
        return records
    }

    /// Marks exports as deleting before any file is removed. Relaunch can resume safely.
    public func beginExportCleanup(projectUUID: UUID) throws -> [Lane2ExportRecord] {
        let value = try snapshot()
        var selected: [Lane2ExportRecord] = []
        let updated = value.exports.map { record -> Lane2ExportRecord in
            guard record.projectUUID == projectUUID else { return record }
            let deleting = Lane2ExportRecord(
                id: record.id,
                projectUUID: record.projectUUID,
                relativePath: record.relativePath,
                mediaType: record.mediaType,
                createdAt: record.createdAt,
                state: .deleting
            )
            selected.append(deleting)
            return deleting
        }
        try write(Lane2LifecycleSnapshot(projects: value.projects, exports: updated, failures: value.failures))
        return selected
    }

    public func pendingExportCleanup() throws -> [Lane2ExportRecord] {
        try snapshot().exports.filter { $0.state == .deleting }
    }

    public func finishExportCleanup(exportID: UUID) throws {
        let value = try snapshot()
        try write(
            Lane2LifecycleSnapshot(
                projects: value.projects,
                exports: value.exports.filter { $0.id != exportID },
                failures: value.failures
            )
        )
    }

    public func recordFailure(_ record: Lane2FailureRecord, maximumHistory: Int = 64) throws {
        let value = try snapshot()
        let history = value.failures.filter { $0.attemptUUID != record.attemptUUID } + [record]
        let bounded = Array(history.suffix(max(maximumHistory, 1)))
        try write(Lane2LifecycleSnapshot(projects: value.projects, exports: value.exports, failures: bounded))
    }

    public func latestFailure(projectUUID: UUID?) throws -> Lane2FailureRecord? {
        try snapshot().failures.last { projectUUID == nil || $0.projectUUID == projectUUID }
    }

    public func removeProjectMetadata(projectUUID: UUID) throws {
        let value = try snapshot()
        try write(
            Lane2LifecycleSnapshot(
                projects: value.projects.filter { $0.projectUUID != projectUUID },
                exports: value.exports,
                failures: value.failures
            )
        )
    }

    private func write(_ value: Lane2LifecycleSnapshot) throws {
        let directory = documentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: documentURL, options: [.atomic])
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
