import Foundation

public enum Lane2LifecycleQuarantineRecoveryFailure: Error, Equatable, Sendable {
    case corruptBarrier
    case exportRecoveryBarrierActive
    case invalidExportRelativePath(String)
    case missingRecoveredArtifact(String)
    case emptyRecoveredArtifact(String)
    case incompleteAttributedRecovery
    case unexpectedRecoveryProject(UUID)
    case conflictingRecoveryDisposition(UUID)
    case unattributedMetadataRequiresAcknowledgement
    case conflictingExistingExportMetadata(UUID)
}

public struct Lane2ExportMetadataQuarantineBarrier: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let createdAt: Date
    public let corruptExportShardRelativePaths: [String]
    public let affectedProjectUUIDs: [UUID]
    public let hasUnattributedShard: Bool

    public init(
        schemaVersion: Int = 1,
        createdAt: Date = Date(),
        corruptExportShardRelativePaths: [String],
        affectedProjectUUIDs: [UUID],
        hasUnattributedShard: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.corruptExportShardRelativePaths = Array(Set(corruptExportShardRelativePaths)).sorted()
        self.affectedProjectUUIDs = Array(Set(affectedProjectUUIDs)).sorted { $0.uuidString < $1.uuidString }
        self.hasUnattributedShard = hasUnattributedShard
    }
}

public struct Lane2RecoveredExportArtifact: Hashable, Sendable {
    public let projectUUID: UUID
    public let relativePath: String
    public let mediaType: String

    public init(projectUUID: UUID, relativePath: String, mediaType: String) {
        self.projectUUID = projectUUID
        self.relativePath = relativePath
        self.mediaType = mediaType
    }
}

public struct Lane2ExportMetadataRecoveryResolution: Sendable {
    public let restoredArtifacts: [Lane2RecoveredExportArtifact]
    public let acknowledgedEmptyProjectUUIDs: Set<UUID>
    public let acknowledgeUnattributedMetadataLoss: Bool

    public init(
        restoredArtifacts: [Lane2RecoveredExportArtifact] = [],
        acknowledgedEmptyProjectUUIDs: Set<UUID> = [],
        acknowledgeUnattributedMetadataLoss: Bool = false
    ) {
        self.restoredArtifacts = restoredArtifacts
        self.acknowledgedEmptyProjectUUIDs = acknowledgedEmptyProjectUUIDs
        self.acknowledgeUnattributedMetadataLoss = acknowledgeUnattributedMetadataLoss
    }
}

public struct Lane2LifecycleCanonicalRecoveryReport: Equatable, Sendable {
    public let quarantinedRelativePaths: [String]
    public let exportRecoveryBarrier: Lane2ExportMetadataQuarantineBarrier?
    public let ownershipReconciled: Bool

    public init(
        quarantinedRelativePaths: [String],
        exportRecoveryBarrier: Lane2ExportMetadataQuarantineBarrier?,
        ownershipReconciled: Bool
    ) {
        self.quarantinedRelativePaths = quarantinedRelativePaths.sorted()
        self.exportRecoveryBarrier = exportRecoveryBarrier
        self.ownershipReconciled = ownershipReconciled
    }
}

public struct Lane2ExportMetadataRecoveryCompletionReport: Equatable, Sendable {
    public let restoredProjectUUIDs: [UUID]
    public let acknowledgedEmptyProjectUUIDs: [UUID]
    public let acknowledgedUnattributedMetadataLoss: Bool

    public init(
        restoredProjectUUIDs: [UUID],
        acknowledgedEmptyProjectUUIDs: [UUID],
        acknowledgedUnattributedMetadataLoss: Bool
    ) {
        self.restoredProjectUUIDs = restoredProjectUUIDs.sorted { $0.uuidString < $1.uuidString }
        self.acknowledgedEmptyProjectUUIDs = acknowledgedEmptyProjectUUIDs.sorted { $0.uuidString < $1.uuidString }
        self.acknowledgedUnattributedMetadataLoss = acknowledgedUnattributedMetadataLoss
    }
}

/// Durable fail-closed guard around lifecycle-metadata quarantine.
///
/// Export sidecars are not reconstructible from the frozen Project Library contract. Before the
/// production recovery path moves a corrupt export shard, this guard writes an atomic barrier
/// outside the v2 tree. The barrier therefore survives both shard quarantine and legacy-v1 rebuild.
/// Export mutation/cleanup/orphan sweeping must remain blocked until an explicit recovery resolution
/// restores known artifacts or acknowledges unrecoverable metadata loss.
public actor Lane2LifecycleQuarantineRecovery {
    private let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public func barrier() throws -> Lane2ExportMetadataQuarantineBarrier? {
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            guard try boundary.nodeExists(recoveryDirectoryURL, fileManager: fileManager) else { return nil }
            try boundary.requireDirectory(recoveryDirectoryURL, fileManager: fileManager)
            guard try boundary.requireRegularFileOrMissing(
                barrierURL,
                within: recoveryDirectoryURL,
                fileManager: fileManager
            ) else { return nil }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let value = try decoder.decode(
                Lane2ExportMetadataQuarantineBarrier.self,
                from: Data(contentsOf: barrierURL)
            )
            guard value.schemaVersion == 1 else {
                throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
            }
            return value
        } catch let failure as Lane2LifecycleQuarantineRecoveryFailure {
            throw failure
        } catch {
            throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
        }
    }

    public func requireExportMetadataConsistent() throws {
        if try barrier() != nil {
            throw Lane2LifecycleQuarantineRecoveryFailure.exportRecoveryBarrierActive
        }
    }

    /// Scans current v2 export sidecars using the same durable invariants as the metadata store.
    /// If any shard is corrupt, an atomic barrier is persisted BEFORE the caller moves any shard.
    @discardableResult
    public func prepareBarrierForCurrentCorruptExportShards(
        now: Date = Date()
    ) throws -> Lane2ExportMetadataQuarantineBarrier? {
        let descriptors = try corruptExportShardDescriptors()
        guard !descriptors.isEmpty else { return try barrier() }

        let existing = try barrier()
        let merged = Lane2ExportMetadataQuarantineBarrier(
            createdAt: existing?.createdAt ?? now,
            corruptExportShardRelativePaths:
                (existing?.corruptExportShardRelativePaths ?? []) + descriptors.map(\.relativePath),
            affectedProjectUUIDs:
                (existing?.affectedProjectUUIDs ?? []) + descriptors.compactMap(\.projectUUID),
            hasUnattributedShard:
                (existing?.hasUnattributedShard ?? false) || descriptors.contains { $0.projectUUID == nil }
        )
        try writeBarrier(merged)
        return merged
    }

    /// A malformed legacy v1 document cannot reliably prove that it contained no exports.
    /// Persist a global/unattributed barrier before the legacy document is moved/reinitialized.
    @discardableResult
    public func prepareBarrierForLegacyCorruption(
        now: Date = Date()
    ) throws -> Lane2ExportMetadataQuarantineBarrier {
        let legacyPath = ".LibraryLifecycle/lane2-lifecycle-v1.json"
        let existing = try barrier()
        let merged = Lane2ExportMetadataQuarantineBarrier(
            createdAt: existing?.createdAt ?? now,
            corruptExportShardRelativePaths:
                (existing?.corruptExportShardRelativePaths ?? []) + [legacyPath],
            affectedProjectUUIDs: existing?.affectedProjectUUIDs ?? [],
            hasUnattributedShard: true
        )
        try writeBarrier(merged)
        return merged
    }

    public func validate(
        resolution: Lane2ExportMetadataRecoveryResolution,
        against barrier: Lane2ExportMetadataQuarantineBarrier
    ) throws {
        let affected = Set(barrier.affectedProjectUUIDs)
        let restoredProjects = Set(resolution.restoredArtifacts.map(\.projectUUID))
        let empty = resolution.acknowledgedEmptyProjectUUIDs

        if !restoredProjects.isDisjoint(with: empty) {
            if let conflict = restoredProjects.intersection(empty).first {
                throw Lane2LifecycleQuarantineRecoveryFailure.conflictingRecoveryDisposition(conflict)
            }
        }

        if !barrier.hasUnattributedShard {
            let unexpected = restoredProjects.union(empty).subtracting(affected)
            if let project = unexpected.first {
                throw Lane2LifecycleQuarantineRecoveryFailure.unexpectedRecoveryProject(project)
            }
        }

        guard affected.isSubset(of: restoredProjects.union(empty)) else {
            throw Lane2LifecycleQuarantineRecoveryFailure.incompleteAttributedRecovery
        }
        if barrier.hasUnattributedShard && !resolution.acknowledgeUnattributedMetadataLoss {
            throw Lane2LifecycleQuarantineRecoveryFailure.unattributedMetadataRequiresAcknowledgement
        }

        for artifact in resolution.restoredArtifacts {
            try Self.validateExport(relativePath: artifact.relativePath)
            guard !artifact.mediaType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(artifact.relativePath)
            }
        }
        let keys = resolution.restoredArtifacts.map {
            "\($0.projectUUID.uuidString)|\($0.relativePath)"
        }
        guard Set(keys).count == keys.count else {
            throw Lane2LifecycleQuarantineRecoveryFailure.incompleteAttributedRecovery
        }
    }

    public func requireRecoveredArtifactsReady(
        _ artifacts: [Lane2RecoveredExportArtifact]
    ) throws {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        for artifact in artifacts {
            try Self.validateExport(relativePath: artifact.relativePath)
            let url = rootURL.appendingPathComponent(artifact.relativePath).standardizedFileURL
            let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
            guard url.path.hasPrefix(rootPath) else {
                throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(artifact.relativePath)
            }
            do {
                try boundary.requireExistingRegularFile(
                    url,
                    within: rootURL,
                    fileManager: fileManager
                )
            } catch {
                throw Lane2LifecycleQuarantineRecoveryFailure.missingRecoveredArtifact(artifact.relativePath)
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) > 0 else {
                throw Lane2LifecycleQuarantineRecoveryFailure.emptyRecoveredArtifact(artifact.relativePath)
            }
        }
    }

    public func clearBarrier() throws {
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            guard try boundary.nodeExists(recoveryDirectoryURL, fileManager: fileManager) else { return }
            try boundary.requireDirectory(recoveryDirectoryURL, fileManager: fileManager)
            guard try boundary.requireRegularFileOrMissing(
                barrierURL,
                within: recoveryDirectoryURL,
                fileManager: fileManager
            ) else { return }
            try fileManager.removeItem(at: barrierURL)
        } catch let failure as Lane2LifecycleQuarantineRecoveryFailure {
            throw failure
        } catch {
            throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
        }
    }

    private struct CorruptExportDescriptor {
        let relativePath: String
        let projectUUID: UUID?
    }

    private func corruptExportShardDescriptors() throws -> [CorruptExportDescriptor] {
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        do {
            guard try boundary.nodeExists(exportsDirectoryURL, fileManager: fileManager) else { return [] }
            try boundary.requireDirectory(exportsDirectoryURL, fileManager: fileManager)
        } catch {
            throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: exportsDirectoryURL,
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
        }

        var result: [CorruptExportDescriptor] = []
        for url in urls {
            let projectUUID = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            do {
                try boundary.requireExistingRegularFile(
                    url,
                    within: exportsDirectoryURL,
                    fileManager: fileManager
                )
                try validateExportShard(at: url, expectedProjectUUID: projectUUID)
            } catch {
                result.append(
                    CorruptExportDescriptor(
                        relativePath: relativeName(url),
                        projectUUID: projectUUID
                    )
                )
            }
        }
        return result
    }

    private func validateExportShard(at url: URL, expectedProjectUUID: UUID?) throws {
        guard let expectedProjectUUID else {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativeName(url))
        }
        do {
            try LibraryManagedPathBoundary(rootURL: rootURL).requireExistingRegularFile(
                url,
                within: exportsDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativeName(url))
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([Lane2ExportRecord].self, from: Data(contentsOf: url))
        guard records.allSatisfy({ $0.projectUUID == expectedProjectUUID }) else {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativeName(url))
        }
        guard Set(records.map(\.id)).count == records.count else {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativeName(url))
        }
        try records.forEach { try Self.validateGeneric(relativePath: $0.relativePath) }
    }

    private func writeBarrier(_ value: Lane2ExportMetadataQuarantineBarrier) throws {
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            try boundary.ensureDirectory(recoveryDirectoryURL, fileManager: fileManager)
            _ = try boundary.requireRegularFileOrMissing(
                barrierURL,
                within: recoveryDirectoryURL,
                fileManager: fileManager
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(value).write(to: barrierURL, options: [.atomic])
            try boundary.requireExistingRegularFile(
                barrierURL,
                within: recoveryDirectoryURL,
                fileManager: fileManager
            )
        } catch let failure as Lane2LifecycleQuarantineRecoveryFailure {
            throw failure
        } catch {
            throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
        }
    }

    private var lifecycleDirectoryURL: URL {
        rootURL.appendingPathComponent(".LibraryLifecycle", isDirectory: true)
    }

    private var exportsDirectoryURL: URL {
        lifecycleDirectoryURL
            .appendingPathComponent("v2", isDirectory: true)
            .appendingPathComponent("exports", isDirectory: true)
    }

    private var recoveryDirectoryURL: URL {
        lifecycleDirectoryURL.appendingPathComponent("Recovery", isDirectory: true)
    }

    private var barrierURL: URL {
        recoveryDirectoryURL.appendingPathComponent(
            "export-metadata-quarantine-barrier.json",
            isDirectory: false
        )
    }

    private func relativeName(_ url: URL) -> String {
        let root = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : url.lastPathComponent
    }

    private static func validateExport(relativePath: String) throws {
        try validateGeneric(relativePath: relativePath)
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard normalized.hasPrefix("Exports/") else {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativePath)
        }
    }

    private static func validateGeneric(relativePath: String) throws {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2LifecycleQuarantineRecoveryFailure.invalidExportRelativePath(relativePath)
        }
    }
}
