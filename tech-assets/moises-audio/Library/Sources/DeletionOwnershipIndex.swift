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

private struct Lane2DeletionOwnershipActiveShards: Codable, Sendable {
    static let schemaVersion = 2
    let schemaVersion: Int
    let shardIndices: [Int]
}

private struct Lane2LegacyOwnershipMigrationSlice: Sendable {
    let records: [Lane2DeletionOwnershipRecord]
    let hasMore: Bool
}

private struct Lane2ShardedOwnershipSlice: Sendable {
    let records: [Lane2DeletionOwnershipRecord]
    let hasMore: Bool
}

private struct Lane2BoundedOwnershipShardItem: Sendable {
    let projectUUID: UUID
    let url: URL
}

private struct Lane2BoundedOwnershipShardURLSlice: Sendable {
    let items: [Lane2BoundedOwnershipShardItem]
    let hasMore: Bool
    let directoryWasEmpty: Bool
}

/// Durable ownership evidence written before project tombstoning. AW32 stores current records in
/// deterministic shard directories and keeps a tiny active-shard manifest, so ownership-only recovery
/// no longer walks every record filename on each launch. AW45 bounds per-shard hot-path enumeration.
/// HQ path-authority hardening additionally rejects symlink, dangling-link and non-directory ancestors
/// before record/manifest enumeration, persistence or deletion. Validation and I/O remain separate
/// syscalls; descriptor-level TOCTOU closure is not claimed.
public struct Lane2DeletionOwnershipIndex: Sendable {
    public static let shardCount = 256
    public static let defaultShardVisitLimit = 4
    public static let defaultShardDirectoryScanBudget = 1024

    public let rootURL: URL
    public let recoveryDirectoryName: String

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery") {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
    }

    public func ensureLayout() throws {
        try pathAuthority.ensureLayout()
    }

    @discardableResult
    public func persist(_ record: Lane2DeletionOwnershipRecord) throws -> URL {
        try ensureLayout()
        let legacyURL = legacyRecordURL(projectUUID: record.projectUUID)
        let shardIndex = Self.shardIndex(for: record.projectUUID)
        let shardedURL = shardedRecordURL(projectUUID: record.projectUUID)

        if try pathAuthority.recordExists(legacyURL) {
            let existing = try loadRecord(at: legacyURL, expectedProjectUUID: record.projectUUID)
            try requireSameIdentity(existing, record)
        }
        if try pathAuthority.recordExists(shardedURL, shardIndex: shardIndex) {
            let existing = try loadRecord(at: shardedURL, expectedProjectUUID: record.projectUUID)
            try requireSameIdentity(existing, record)
            try activateShard(shardIndex)
            if try pathAuthority.recordExists(legacyURL) {
                try pathAuthority.requireExistingRegularFile(
                    legacyURL,
                    within: ownershipDirectoryURL
                )
                try FileManager.default.removeItem(at: legacyURL)
            }
            return shardedURL
        }

        let written = try persistSharded(record)
        if try pathAuthority.recordExists(legacyURL) {
            try pathAuthority.requireExistingRegularFile(
                legacyURL,
                within: ownershipDirectoryURL
            )
            try FileManager.default.removeItem(at: legacyURL)
        }
        return written
    }

    public func record(projectUUID: UUID) throws -> Lane2DeletionOwnershipRecord? {
        let shardIndex = Self.shardIndex(for: projectUUID)
        let shardedURL = shardedRecordURL(projectUUID: projectUUID)
        let legacyURL = legacyRecordURL(projectUUID: projectUUID)
        let sharded = try pathAuthority.recordExists(shardedURL, shardIndex: shardIndex)
            ? try loadRecord(at: shardedURL, expectedProjectUUID: projectUUID)
            : nil
        let legacy = try pathAuthority.recordExists(legacyURL)
            ? try loadRecord(at: legacyURL, expectedProjectUUID: projectUUID)
            : nil
        if let sharded, let legacy {
            try requireSameIdentity(sharded, legacy)
        }
        return sharded ?? legacy
    }

    /// Compatibility API for tests/admin tooling. This intentionally materializes all records and is
    /// not used by CrashSafe recovery. Duplicate flat/sharded copies from a migration crash must agree.
    public func pendingRecords() throws -> [Lane2DeletionOwnershipRecord] {
        try ensureLayout()
        var byID: [UUID: Lane2DeletionOwnershipRecord] = [:]
        for url in try legacyDirectRecordURLs() {
            let expected = try projectUUID(fromRecordURL: url)
            byID[expected] = try loadRecord(at: url, expectedProjectUUID: expected)
        }
        for shard in try loadActiveShards() {
            for url in try shardRecordURLs(shardIndex: shard) {
                let expected = try projectUUID(fromRecordURL: url)
                let record = try loadRecord(at: url, expectedProjectUUID: expected)
                if let existing = byID[expected] {
                    try requireSameIdentity(existing, record)
                } else {
                    byID[expected] = record
                }
            }
        }
        return byID.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.projectUUID.uuidString < rhs.projectUUID.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public func pendingRecordSlice(
        limit: Int,
        excludingProjectUUIDs: Set<UUID> = []
    ) throws -> Lane2DeletionOwnershipSlice {
        try ensureLayout()
        let boundedLimit = Lane2IndexedRecoveryBudget(
            ownershipOnlyPerPass: limit
        ).ownershipOnlyPerPass

        let legacyMigration = try migrateLegacyFlatSlice(limit: boundedLimit)
        let migratedIDs = Set(legacyMigration.records.map(\.projectUUID))
        var records = legacyMigration.records.filter {
            !excludingProjectUUIDs.contains($0.projectUUID)
        }
        if records.count > boundedLimit {
            records = Array(records.prefix(boundedLimit))
        }

        var shardedHasMore = false
        let remaining = boundedLimit - records.count
        if remaining > 0 {
            let sharded = try shardedRecordSlice(
                limit: remaining,
                excludingProjectUUIDs: excludingProjectUUIDs.union(migratedIDs)
            )
            records.append(contentsOf: sharded.records)
            shardedHasMore = sharded.hasMore
        } else {
            shardedHasMore = !(try loadActiveShards()).isEmpty
        }

        return Lane2DeletionOwnershipSlice(
            records: records,
            hasMore: legacyMigration.hasMore || shardedHasMore,
            limit: boundedLimit
        )
    }

    public func remove(projectUUID: UUID) throws {
        try ensureLayout()
        let legacyURL = legacyRecordURL(projectUUID: projectUUID)
        if try pathAuthority.recordExists(legacyURL) {
            try pathAuthority.requireExistingRegularFile(
                legacyURL,
                within: ownershipDirectoryURL
            )
            try FileManager.default.removeItem(at: legacyURL)
        }

        let shardIndex = Self.shardIndex(for: projectUUID)
        let shardedURL = shardedRecordURL(projectUUID: projectUUID)
        if try pathAuthority.recordExists(shardedURL, shardIndex: shardIndex) {
            try pathAuthority.requireExistingRegularFile(
                shardedURL,
                within: shardDirectoryURL(shardIndex)
            )
            try FileManager.default.removeItem(at: shardedURL)
        }
        try retireShardIfEmpty(shardIndex)
    }

    public var isLegacyScanComplete: Bool {
        (try? pathAuthority.metadataExists(legacyScanMarkerURL)) == true
    }

    public func markLegacyScanComplete() throws {
        try ensureLayout()
        _ = try pathAuthority.requireRegularFileOrMissing(
            legacyScanMarkerURL,
            within: ownershipDirectoryURL
        )
        try Data("L2-AW22 legacy tombstone scan complete\n".utf8)
            .write(to: legacyScanMarkerURL, options: [.atomic])
        try pathAuthority.requireExistingRegularFile(
            legacyScanMarkerURL,
            within: ownershipDirectoryURL
        )
    }

    public static func shardIndex(for projectUUID: UUID) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in projectUUID.uuidString.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(shardCount))
    }

    private func migrateLegacyFlatSlice(limit: Int) throws -> Lane2LegacyOwnershipMigrationSlice {
        let sentinelLimit = max(limit, 1) + 1
        let candidates = try boundedLegacyRecordURLs(limit: sentinelLimit)
        let hasMore = candidates.count > limit
        var migrated: [Lane2DeletionOwnershipRecord] = []
        migrated.reserveCapacity(min(limit, candidates.count))

        for url in candidates.prefix(limit) {
            let expected = try projectUUID(fromRecordURL: url)
            let record = try loadRecord(at: url, expectedProjectUUID: expected)
            _ = try persistSharded(record)
            try pathAuthority.requireExistingRegularFile(
                url,
                within: ownershipDirectoryURL
            )
            try FileManager.default.removeItem(at: url)
            migrated.append(record)
        }
        return Lane2LegacyOwnershipMigrationSlice(records: migrated, hasMore: hasMore)
    }

    private func shardedRecordSlice(
        limit: Int,
        excludingProjectUUIDs: Set<UUID>
    ) throws -> Lane2ShardedOwnershipSlice {
        guard limit > 0 else {
            return Lane2ShardedOwnershipSlice(records: [], hasMore: !(try loadActiveShards()).isEmpty)
        }
        let active = try loadActiveShards()
        guard !active.isEmpty else {
            return Lane2ShardedOwnershipSlice(records: [], hasMore: false)
        }

        var records: [Lane2DeletionOwnershipRecord] = []
        var visitedShards = 0
        var hasMore = false

        for (offset, shardIndex) in active.enumerated() {
            guard visitedShards < Self.defaultShardVisitLimit, records.count < limit else {
                hasMore = true
                break
            }
            visitedShards += 1
            let remaining = limit - records.count
            let scan = try boundedShardRecordURLSlice(
                shardIndex: shardIndex,
                limit: remaining,
                excludingProjectUUIDs: excludingProjectUUIDs
            )
            if scan.directoryWasEmpty {
                try retireShardIfEmpty(shardIndex)
                continue
            }
            if scan.hasMore { hasMore = true }
            for item in scan.items {
                records.append(try loadRecord(at: item.url, expectedProjectUUID: item.projectUUID))
            }
            if records.count >= limit {
                if offset + 1 < active.count { hasMore = true }
                break
            }
        }
        if visitedShards < active.count { hasMore = true }
        return Lane2ShardedOwnershipSlice(records: records, hasMore: hasMore)
    }

    private func persistSharded(_ record: Lane2DeletionOwnershipRecord) throws -> URL {
        let shardIndex = Self.shardIndex(for: record.projectUUID)
        let url = shardedRecordURL(projectUUID: record.projectUUID)
        if try pathAuthority.recordExists(url, shardIndex: shardIndex) {
            let existing = try loadRecord(at: url, expectedProjectUUID: record.projectUUID)
            try requireSameIdentity(existing, record)
            return url
        }

        // The active-shard signal is durable before the record write. A crash in this gap can only
        // leave an empty active shard; it cannot leave a recovery record that the manifest hides.
        try activateShard(shardIndex)
        try pathAuthority.ensureShardDirectory(shardIndex)
        if try pathAuthority.requireRegularFileOrMissing(
            url,
            within: shardDirectoryURL(shardIndex)
        ) {
            let existing = try loadRecord(at: url, expectedProjectUUID: record.projectUUID)
            try requireSameIdentity(existing, record)
            return url
        }
        let data = try Self.encoder.encode(record)
        try data.write(to: url, options: [.atomic])
        try pathAuthority.requireExistingRegularFile(
            url,
            within: shardDirectoryURL(shardIndex)
        )
        return url
    }

    private func activateShard(_ shardIndex: Int) throws {
        var active = try loadActiveShards()
        guard !active.contains(shardIndex) else { return }
        active.append(shardIndex)
        try writeActiveShards(active)
    }

    private func retireShardIfEmpty(_ shardIndex: Int) throws {
        let directory = shardDirectoryURL(shardIndex)
        guard try pathAuthority.requireShardDirectoryIfPresent(shardIndex) else {
            var active = try loadActiveShards()
            if active.removeAllOccurrences(of: shardIndex) {
                try writeActiveShards(active)
            }
            return
        }

        if try shardContainsAnyValidatedRecord(shardIndex: shardIndex) {
            return
        }

        var active = try loadActiveShards()
        if active.removeAllOccurrences(of: shardIndex) {
            try writeActiveShards(active)
        }
        if try pathAuthority.requireShardDirectoryIfPresent(shardIndex) {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func loadActiveShards() throws -> [Int] {
        let url = activeShardsURL
        guard try pathAuthority.metadataExists(url) else {
            guard try pathAuthority.requireShardRootIfPresent() else { return [] }
            let entries = try FileManager.default.contentsOfDirectory(
                at: shardDirectoryRootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            guard entries.isEmpty else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(".active-shards-v2.json")
            }
            return []
        }
        do {
            let manifest = try Self.decoder.decode(
                Lane2DeletionOwnershipActiveShards.self,
                from: Data(contentsOf: url)
            )
            guard manifest.schemaVersion == Lane2DeletionOwnershipActiveShards.schemaVersion else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            let sorted = manifest.shardIndices.sorted()
            guard sorted == Array(Set(sorted)).sorted(),
                  sorted.allSatisfy({ (0..<Self.shardCount).contains($0) }) else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            return sorted
        } catch let error as Lane2DeletionOwnershipIndexFailure {
            throw error
        } catch {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
        }
    }

    private func writeActiveShards(_ shardIndices: [Int]) throws {
        try ensureLayoutDirectoriesOnly()
        let normalized = Array(Set(shardIndices)).sorted()
        guard normalized.allSatisfy({ (0..<Self.shardCount).contains($0) }) else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(".active-shards-v2.json")
        }
        let manifest = Lane2DeletionOwnershipActiveShards(
            schemaVersion: Lane2DeletionOwnershipActiveShards.schemaVersion,
            shardIndices: normalized
        )
        let data = try Self.encoder.encode(manifest)
        _ = try pathAuthority.requireRegularFileOrMissing(
            activeShardsURL,
            within: ownershipDirectoryURL,
            label: ".active-shards-v2.json"
        )
        try data.write(to: activeShardsURL, options: [.atomic])
        try pathAuthority.requireExistingRegularFile(
            activeShardsURL,
            within: ownershipDirectoryURL,
            label: ".active-shards-v2.json"
        )
    }

    private func boundedLegacyRecordURLs(limit: Int) throws -> [URL] {
        guard try pathAuthority.requireOwnershipDirectoryIfPresent() else { return [] }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var enumerationFailed = false
        guard let enumerator = FileManager.default.enumerator(
            at: ownershipDirectoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in
                enumerationFailed = true
                return false
            }
        ) else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt("DeleteOwnership")
        }
        var urls: [URL] = []
        urls.reserveCapacity(limit)
        for case let url as URL in enumerator {
            guard url.pathExtension == "json" else { continue }
            try pathAuthority.requireExistingRegularFile(
                url,
                within: ownershipDirectoryURL,
                label: url.lastPathComponent
            )
            _ = try projectUUID(fromRecordURL: url)
            urls.append(url)
            if urls.count >= limit { break }
        }
        if enumerationFailed {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt("DeleteOwnership")
        }
        return urls
    }

    private func boundedShardRecordURLSlice(
        shardIndex: Int,
        limit: Int,
        excludingProjectUUIDs: Set<UUID>
    ) throws -> Lane2BoundedOwnershipShardURLSlice {
        let directory = shardDirectoryURL(shardIndex)
        guard try pathAuthority.requireShardDirectoryIfPresent(shardIndex) else {
            return Lane2BoundedOwnershipShardURLSlice(items: [], hasMore: false, directoryWasEmpty: true)
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var enumerationFailed = false
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in
                enumerationFailed = true
                return false
            }
        ) else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(String(format: "%02x", shardIndex))
        }

        var sawAny = false
        var inspected = 0
        var eligible: [Lane2BoundedOwnershipShardItem] = []
        eligible.reserveCapacity(min(max(limit, 0), Self.defaultShardDirectoryScanBudget))

        while inspected < Self.defaultShardDirectoryScanBudget,
              let value = enumerator.nextObject() {
            guard let url = value as? URL else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(String(format: "%02x", shardIndex))
            }
            sawAny = true
            inspected += 1
            guard url.pathExtension == "json" else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            try pathAuthority.requireExistingRegularFile(
                url,
                within: directory,
                label: url.lastPathComponent
            )
            let projectUUID = try projectUUID(fromRecordURL: url)
            guard Self.shardIndex(for: projectUUID) == shardIndex else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            if !excludingProjectUUIDs.contains(projectUUID) {
                eligible.append(Lane2BoundedOwnershipShardItem(projectUUID: projectUUID, url: url))
            }
        }
        if enumerationFailed {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(String(format: "%02x", shardIndex))
        }

        let sentinelExists = enumerator.nextObject() != nil
        let sorted = eligible.sorted { $0.projectUUID.uuidString < $1.projectUUID.uuidString }
        let bounded = Array(sorted.prefix(max(limit, 0)))
        let hasMore = sentinelExists || sorted.count > bounded.count
        return Lane2BoundedOwnershipShardURLSlice(
            items: bounded,
            hasMore: hasMore,
            directoryWasEmpty: !sawAny
        )
    }

    private func shardContainsAnyValidatedRecord(shardIndex: Int) throws -> Bool {
        let directory = shardDirectoryURL(shardIndex)
        guard try pathAuthority.requireShardDirectoryIfPresent(shardIndex) else { return false }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var enumerationFailed = false
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in
                enumerationFailed = true
                return false
            }
        ) else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(String(format: "%02x", shardIndex))
        }
        guard let value = enumerator.nextObject() else {
            if enumerationFailed {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(String(format: "%02x", shardIndex))
            }
            return false
        }
        guard let url = value as? URL, url.pathExtension == "json" else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(String(format: "%02x", shardIndex))
        }
        try pathAuthority.requireExistingRegularFile(
            url,
            within: directory,
            label: url.lastPathComponent
        )
        let projectUUID = try projectUUID(fromRecordURL: url)
        guard Self.shardIndex(for: projectUUID) == shardIndex else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
        }
        return true
    }

    private func legacyDirectRecordURLs() throws -> [URL] {
        guard try pathAuthority.requireOwnershipDirectoryIfPresent() else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: ownershipDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .map { url in
            try pathAuthority.requireExistingRegularFile(
                url,
                within: ownershipDirectoryURL,
                label: url.lastPathComponent
            )
            _ = try projectUUID(fromRecordURL: url)
            return url
        }
    }

    private func shardRecordURLs(shardIndex: Int) throws -> [URL] {
        let directory = shardDirectoryURL(shardIndex)
        guard try pathAuthority.requireShardDirectoryIfPresent(shardIndex) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .map { url in
            guard url.pathExtension == "json" else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            try pathAuthority.requireExistingRegularFile(
                url,
                within: directory,
                label: url.lastPathComponent
            )
            let projectUUID = try projectUUID(fromRecordURL: url)
            guard Self.shardIndex(for: projectUUID) == shardIndex else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
            }
            return url
        }
    }

    private func requireSameIdentity(
        _ lhs: Lane2DeletionOwnershipRecord,
        _ rhs: Lane2DeletionOwnershipRecord
    ) throws {
        guard lhs.projectUUID == rhs.projectUUID,
              lhs.sourceAssetUUID == rhs.sourceAssetUUID,
              lhs.artifactRelativePaths == rhs.artifactRelativePaths else {
            throw Lane2DeletionOwnershipIndexFailure.identityConflict(rhs.projectUUID)
        }
    }

    private var pathAuthority: Lane2DeletionOwnershipPathAuthority {
        Lane2DeletionOwnershipPathAuthority(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName
        )
    }

    private var ownershipDirectoryURL: URL {
        pathAuthority.ownershipDirectoryURL
    }

    private var shardDirectoryRootURL: URL {
        pathAuthority.shardDirectoryRootURL
    }

    private var activeShardsURL: URL {
        ownershipDirectoryURL.appendingPathComponent(".active-shards-v2.json", isDirectory: false)
    }

    private var legacyScanMarkerURL: URL {
        ownershipDirectoryURL.appendingPathComponent(".legacy-scan-v1-complete", isDirectory: false)
    }

    private func legacyRecordURL(projectUUID: UUID) -> URL {
        ownershipDirectoryURL.appendingPathComponent(projectUUID.uuidString + ".json", isDirectory: false)
    }

    private func shardedRecordURL(projectUUID: UUID) -> URL {
        shardDirectoryURL(Self.shardIndex(for: projectUUID))
            .appendingPathComponent(projectUUID.uuidString + ".json", isDirectory: false)
    }

    private func shardDirectoryURL(_ shardIndex: Int) -> URL {
        pathAuthority.shardDirectoryURL(shardIndex)
    }

    private func ensureLayoutDirectoriesOnly() throws {
        try pathAuthority.ensureLayout()
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
            try pathAuthority.requireExistingRegularFile(
                url,
                within: url.deletingLastPathComponent(),
                label: url.lastPathComponent
            )
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

private extension Array where Element == Int {
    mutating func removeAllOccurrences(of value: Int) -> Bool {
        let original = count
        removeAll { $0 == value }
        return count != original
    }
}
