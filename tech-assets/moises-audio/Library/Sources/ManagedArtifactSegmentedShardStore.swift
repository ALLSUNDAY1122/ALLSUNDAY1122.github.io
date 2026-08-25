import Foundation

public struct Lane2ManagedArtifactSegmentEntry: Codable, Hashable, Sendable {
    public let relativePath: String
    public let modificationTime: TimeInterval

    public init(relativePath: String, modificationTime: TimeInterval) {
        self.relativePath = relativePath
        self.modificationTime = modificationTime
    }
}

public struct Lane2ManagedArtifactSegmentedMigrationResult: Hashable, Sendable {
    public let shardIndex: Int
    public let entryCount: Int
    public let segmentCount: Int
    public let migrated: Bool
}

public enum Lane2ManagedArtifactSegmentedMigrationFailure: Error, Equatable, Sendable {
    case invalidShard(Int)
    case corruptLegacyShard(String)
    case corruptManifest(String)
    case corruptSegment(String)
    case verificationFailed(Int)
}

/// AW39 migration substrate for AW29's v1 single-JSON shard layout.
///
/// Authority changes only when the generation manifest is atomically published. Legacy bytes are
/// intentionally retained, so a crash before manifest publication keeps the v1 shard authoritative.
/// A committed generation is fully read-back verified before its manifest becomes visible.
public struct Lane2ManagedArtifactSegmentedShardStore: Sendable {
    public static let schemaVersion = 1
    public static let shardCount = 256
    public static let entriesPerSegment = 512

    private struct LegacyShard: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let entries: [Lane2ManagedArtifactSegmentEntry]
    }

    private struct Manifest: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let generation: UUID
        let segmentCount: Int
        let entryCount: Int
    }

    private struct Segment: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let generation: UUID
        let segmentIndex: Int
        let entries: [Lane2ManagedArtifactSegmentEntry]
    }

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    public func hasCommittedShard(_ shardIndex: Int) -> Bool {
        guard Self.validShard(shardIndex) else { return false }
        guard let manifest = try? loadManifest(shardIndex) else { return false }
        return manifest != nil
    }

    public func loadCommittedEntries(_ shardIndex: Int) throws -> [Lane2ManagedArtifactSegmentEntry]? {
        guard Self.validShard(shardIndex) else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.invalidShard(shardIndex)
        }
        guard let manifest = try loadManifest(shardIndex) else { return nil }
        var entries: [Lane2ManagedArtifactSegmentEntry] = []
        entries.reserveCapacity(manifest.entryCount)
        for segmentIndex in 0..<manifest.segmentCount {
            let url = segmentURL(
                shardIndex: shardIndex,
                generation: manifest.generation,
                segmentIndex: segmentIndex
            )
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
            let segment: Segment
            do {
                segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
            } catch {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
            guard segment.schemaVersion == Self.schemaVersion,
                  segment.shardIndex == shardIndex,
                  segment.generation == manifest.generation,
                  segment.segmentIndex == segmentIndex,
                  segment.entries.count <= Self.entriesPerSegment else {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
            entries.append(contentsOf: segment.entries)
        }
        guard entries.count == manifest.entryCount else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.verificationFailed(shardIndex)
        }
        return entries
    }

    @discardableResult
    public func migrateLegacyShardIfNeeded(_ shardIndex: Int) throws -> Lane2ManagedArtifactSegmentedMigrationResult {
        guard Self.validShard(shardIndex) else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.invalidShard(shardIndex)
        }
        if let existing = try loadCommittedEntries(shardIndex) {
            return Lane2ManagedArtifactSegmentedMigrationResult(
                shardIndex: shardIndex,
                entryCount: existing.count,
                segmentCount: Self.segmentCount(for: existing.count),
                migrated: false
            )
        }
        let legacyURL = legacyShardURL(shardIndex)
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return Lane2ManagedArtifactSegmentedMigrationResult(
                shardIndex: shardIndex,
                entryCount: 0,
                segmentCount: 0,
                migrated: false
            )
        }
        let values = try legacyURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptLegacyShard(legacyURL.lastPathComponent)
        }
        let legacy: LegacyShard
        do {
            legacy = try JSONDecoder().decode(LegacyShard.self, from: Data(contentsOf: legacyURL))
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptLegacyShard(legacyURL.lastPathComponent)
        }
        guard legacy.schemaVersion == 1, legacy.shardIndex == shardIndex else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptLegacyShard(legacyURL.lastPathComponent)
        }
        try publishGeneration(shardIndex: shardIndex, entries: legacy.entries)
        let verified = try loadCommittedEntries(shardIndex) ?? []
        guard verified == legacy.entries.sorted(by: Self.entryOrder) else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.verificationFailed(shardIndex)
        }
        return Lane2ManagedArtifactSegmentedMigrationResult(
            shardIndex: shardIndex,
            entryCount: verified.count,
            segmentCount: Self.segmentCount(for: verified.count),
            migrated: true
        )
    }

    public func removeUncommittedGenerations(shardIndex: Int) throws -> Int {
        guard Self.validShard(shardIndex) else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.invalidShard(shardIndex)
        }
        guard fileManager.fileExists(atPath: segmentedDirectoryURL.path) else { return 0 }
        let committedGeneration = try loadManifest(shardIndex)?.generation.uuidString
        let prefix = String(format: "%02x.", shardIndex)
        var removed = 0
        for url in try fileManager.contentsOfDirectory(at: segmentedDirectoryURL, includingPropertiesForKeys: nil) {
            let name = url.lastPathComponent
            guard name.hasPrefix(prefix), name.hasSuffix(".json") else { continue }
            if name == String(format: "%02x.manifest.json", shardIndex) { continue }
            if name == String(format: "%02x.pending.json", shardIndex) {
                try fileManager.removeItem(at: url)
                removed += 1
                continue
            }
            if let committedGeneration, name.contains(committedGeneration) { continue }
            try fileManager.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    private func publishGeneration(shardIndex: Int, entries: [Lane2ManagedArtifactSegmentEntry]) throws {
        try fileManager.createDirectory(at: segmentedDirectoryURL, withIntermediateDirectories: true)
        let generation = UUID()
        let ordered = entries.sorted(by: Self.entryOrder)
        let segmentCount = Self.segmentCount(for: ordered.count)
        for segmentIndex in 0..<segmentCount {
            let start = segmentIndex * Self.entriesPerSegment
            let end = min(start + Self.entriesPerSegment, ordered.count)
            let segment = Segment(
                schemaVersion: Self.schemaVersion,
                shardIndex: shardIndex,
                generation: generation,
                segmentIndex: segmentIndex,
                entries: Array(ordered[start..<end])
            )
            try stableEncoder.encode(segment).write(
                to: segmentURL(shardIndex: shardIndex, generation: generation, segmentIndex: segmentIndex),
                options: [.atomic]
            )
        }
        let pendingURL = pendingManifestURL(shardIndex)
        let manifest = Manifest(
            schemaVersion: Self.schemaVersion,
            shardIndex: shardIndex,
            generation: generation,
            segmentCount: segmentCount,
            entryCount: ordered.count
        )
        try stableEncoder.encode(manifest).write(to: pendingURL, options: [.atomic])

        var verifiedCount = 0
        for segmentIndex in 0..<segmentCount {
            let url = segmentURL(shardIndex: shardIndex, generation: generation, segmentIndex: segmentIndex)
            let decoded = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
            guard decoded.schemaVersion == Self.schemaVersion,
                  decoded.shardIndex == shardIndex,
                  decoded.generation == generation,
                  decoded.segmentIndex == segmentIndex,
                  decoded.entries.count <= Self.entriesPerSegment else {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
            verifiedCount += decoded.entries.count
        }
        guard verifiedCount == ordered.count else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.verificationFailed(shardIndex)
        }

        let finalURL = manifestURL(shardIndex)
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        try fileManager.moveItem(at: pendingURL, to: finalURL)
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(url.lastPathComponent)
        }
        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(url.lastPathComponent)
        }
        guard manifest.schemaVersion == Self.schemaVersion,
              manifest.shardIndex == shardIndex,
              manifest.segmentCount == Self.segmentCount(for: manifest.entryCount),
              manifest.entryCount >= 0 else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(url.lastPathComponent)
        }
        return manifest
    }

    private var v1DirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }

    private var segmentedDirectoryURL: URL {
        v1DirectoryURL.appendingPathComponent("Segmented", isDirectory: true)
    }

    private func legacyShardURL(_ shardIndex: Int) -> URL {
        v1DirectoryURL
            .appendingPathComponent("Shards", isDirectory: true)
            .appendingPathComponent(String(format: "%02x.json", shardIndex), isDirectory: false)
    }

    private func manifestURL(_ shardIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.manifest.json", shardIndex))
    }

    private func pendingManifestURL(_ shardIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.pending.json", shardIndex))
    }

    private func segmentURL(shardIndex: Int, generation: UUID, segmentIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(
            String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, segmentIndex)
        )
    }

    private var stableEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func validShard(_ shardIndex: Int) -> Bool {
        (0..<Self.shardCount).contains(shardIndex)
    }

    private static func segmentCount(for entryCount: Int) -> Int {
        guard entryCount > 0 else { return 0 }
        return (entryCount + entriesPerSegment - 1) / entriesPerSegment
    }

    private static func entryOrder(_ lhs: Lane2ManagedArtifactSegmentEntry, _ rhs: Lane2ManagedArtifactSegmentEntry) -> Bool {
        lhs.relativePath < rhs.relativePath
    }
}
