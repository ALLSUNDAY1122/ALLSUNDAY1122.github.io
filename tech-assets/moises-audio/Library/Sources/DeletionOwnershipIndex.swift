import Foundation

public struct Lane2DeletionOwnershipRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let projectUUID: UUID
    public let sourceAssetUUID: UUID
    public let artifactRelativePaths: [String]
    public let createdAt: Date

    public init(
        projectUUID: UUID,
        sourceAssetUUID: UUID,
        artifactRelativePaths: [String],
        createdAt: Date = Date()
    ) throws {
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: projectUUID,
            sourceAssetUUID: sourceAssetUUID,
            artifactRelativePaths: artifactRelativePaths
        )
        let validated = try Lane2TombstonedMetadataCompactionPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPaths: []
        )
        self.schemaVersion = 1
        self.projectUUID = projectUUID
        self.sourceAssetUUID = sourceAssetUUID
        self.artifactRelativePaths = validated.artifactRelativePathsToDelete
        self.createdAt = Date(timeIntervalSince1970: floor(createdAt.timeIntervalSince1970))
    }

    public var compactionCandidate: Lane2TombstonedProjectCompactionCandidate {
        Lane2TombstonedProjectCompactionCandidate(
            projectUUID: projectUUID,
            sourceAssetUUID: sourceAssetUUID,
            artifactRelativePaths: artifactRelativePaths
        )
    }
}

public enum Lane2DeletionOwnershipIndexFailure: Error, Equatable, Sendable {
    case recordCorrupt(String)
    case identityConflict(UUID)
    case recordIdentityMismatch(expected: UUID, actual: UUID)
    case unsupportedSchema(Int)
}

/// Durable ownership evidence written before project tombstoning. Normal recovery can therefore
/// authorize journal deletion without globally materializing every tombstoned Core Data project.
public struct Lane2DeletionOwnershipIndex: Sendable {
    public let rootURL: URL
    public let recoveryDirectoryName: String

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery") {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
    }

    public func ensureLayout() throws {
        try FileManager.default.createDirectory(
            at: ownershipDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    public func persist(_ record: Lane2DeletionOwnershipRecord) throws -> URL {
        try ensureLayout()
        let url = recordURL(projectUUID: record.projectUUID)
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try loadRecord(at: url, expectedProjectUUID: record.projectUUID)
            guard existing.projectUUID == record.projectUUID,
                  existing.sourceAssetUUID == record.sourceAssetUUID,
                  existing.artifactRelativePaths == record.artifactRelativePaths else {
                throw Lane2DeletionOwnershipIndexFailure.identityConflict(record.projectUUID)
            }
            return url
        }
        let data = try Self.encoder.encode(record)
        try data.write(to: url, options: [.atomic])
        return url
    }

    public func record(projectUUID: UUID) throws -> Lane2DeletionOwnershipRecord? {
        let url = recordURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try loadRecord(at: url, expectedProjectUUID: projectUUID)
    }

    /// Compatibility API for tests/admin tooling. CrashSafe recovery must use pendingRecordSlice so
    /// an already-indexed historical backlog cannot materialize every ownership payload in one pass.
    public func pendingRecords() throws -> [Lane2DeletionOwnershipRecord] {
        try ensureLayout()
        return try directRecordURLs()
            .map { url in
                let expected = try projectUUID(fromRecordURL: url)
                return try loadRecord(at: url, expectedProjectUUID: expected)
            }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.projectUUID.uuidString < rhs.projectUUID.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// Bounded deterministic selection used by AW25 recovery. It scans directory entries but retains
    /// at most `limit + 1` URLs and decodes at most `limit` ownership payloads. Journal-backed project
    /// IDs are excluded because those records are read directly and prioritized separately.
    public func pendingRecordSlice(
        limit: Int,
        excludingProjectUUIDs: Set<UUID> = []
    ) throws -> Lane2DeletionOwnershipSlice {
        try ensureLayout()
        let boundedLimit = Lane2IndexedRecoveryBudget(
            ownershipOnlyPerPass: limit
        ).ownershipOnlyPerPass
        let sentinelLimit = boundedLimit + 1
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: ownershipDirectoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in true }
        ) else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt("DeleteOwnership")
        }

        var selected: [(projectUUID: UUID, url: URL)] = []
        selected.reserveCapacity(sentinelLimit)

        for case let url as URL in enumerator {
            guard url.pathExtension == "json" else { continue }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            let projectUUID = try projectUUID(fromRecordURL: url)
            guard !excludingProjectUUIDs.contains(projectUUID) else { continue }

            selected.append((projectUUID, url))
            selected.sort { lhs, rhs in
                lhs.projectUUID.uuidString < rhs.projectUUID.uuidString
            }
            if selected.count > sentinelLimit {
                selected.removeLast()
            }
        }

        let hasMore = selected.count > boundedLimit
        let records = try selected.prefix(boundedLimit).map { item in
            try loadRecord(at: item.url, expectedProjectUUID: item.projectUUID)
        }
        return Lane2DeletionOwnershipSlice(
            records: records,
            hasMore: hasMore,
            limit: boundedLimit
        )
    }

    public func remove(projectUUID: UUID) throws {
        let url = recordURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public var isLegacyScanComplete: Bool {
        FileManager.default.fileExists(atPath: legacyScanMarkerURL.path)
    }

    public func markLegacyScanComplete() throws {
        try ensureLayout()
        try Data("L2-AW22 legacy tombstone scan complete\n".utf8)
            .write(to: legacyScanMarkerURL, options: [.atomic])
    }

    private var ownershipDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("DeleteOwnership", isDirectory: true)
    }

    private var legacyScanMarkerURL: URL {
        ownershipDirectoryURL.appendingPathComponent(".legacy-scan-v1-complete", isDirectory: false)
    }

    private func recordURL(projectUUID: UUID) -> URL {
        ownershipDirectoryURL.appendingPathComponent(projectUUID.uuidString + ".json", isDirectory: false)
    }

    private func directRecordURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: ownershipDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .map { url in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            _ = try projectUUID(fromRecordURL: url)
            return url
        }
    }

    private func projectUUID(fromRecordURL url: URL) throws -> UUID {
        let filename = url.deletingPathExtension().lastPathComponent
        guard let projectUUID = UUID(uuidString: filename),
              filename == projectUUID.uuidString,
              url.lastPathComponent == projectUUID.uuidString + ".json" else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
        }
        return projectUUID
    }

    private func loadRecord(
        at url: URL,
        expectedProjectUUID: UUID
    ) throws -> Lane2DeletionOwnershipRecord {
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            let record = try Self.decoder.decode(
                Lane2DeletionOwnershipRecord.self,
                from: Data(contentsOf: url)
            )
            guard record.schemaVersion == 1 else {
                throw Lane2DeletionOwnershipIndexFailure.unsupportedSchema(record.schemaVersion)
            }
            guard record.projectUUID == expectedProjectUUID else {
                throw Lane2DeletionOwnershipIndexFailure.recordIdentityMismatch(
                    expected: expectedProjectUUID,
                    actual: record.projectUUID
                )
            }
            _ = try Lane2TombstonedMetadataCompactionPolicy.plan(
                candidate: record.compactionCandidate,
                liveReferencedArtifactPaths: []
            )
            return record
        } catch let error as Lane2DeletionOwnershipIndexFailure {
            throw error
        } catch {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
