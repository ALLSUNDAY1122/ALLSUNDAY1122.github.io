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
        return (try? loadManifest(shardIndex)) != nil
    }

    public func loadCommittedEntries(_ shardIndex: Int) throws -> [Lane2ManagedArtifactSegmentEntry]? {
        guard Self.validShard(shardIndex) else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.invalidShard(shardIndex)
        }
        guard let manifest = try loadManifest(shardIndex) else { return nil }
        var entries: [Lane2ManagedArtifactSegmentEntry] = []
        for segmentIndex in 0..<manifest.segmentCount {
            let url = segmentURL(
                shardIndex: shardIndex,
                generation: manifest.generation,
                segmentIndex: segmentIndex
            )
            try requireSegmentFile(url)
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
        do {
            guard try boundary.nodeExists(legacyURL, fileManager: fileManager) else {
                return Lane2ManagedArtifactSegmentedMigrationResult(
                    shardIndex: shardIndex,
                    entryCount: 0,
                    segmentCount: 0,
                    migrated: false
                )
            }
            try boundary.requireExistingRegularFile(
                legacyURL,
                within: shardsDirectoryURL,
                fileManager: fileManager
            )
        } catch {
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

        do {
            guard try boundary.nodeExists(segmentedDirectoryURL, fileManager: fileManager) else { return 0 }
            try boundary.requireDirectory(segmentedDirectoryURL, fileManager: fileManager)
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(segmentedDirectoryURL.lastPathComponent)
        }

        let committed = try loadManifest(shardIndex)
        var committedNames = Set<String>()
        if let committed {
            for segmentIndex in 0..<committed.segmentCount {
                committedNames.insert(
                    segmentURL(
                        shardIndex: shardIndex,
                        generation: committed.generation,
                        segmentIndex: segmentIndex
                    ).lastPathComponent
                )
            }
        }

        let prefix = String(format: "%02x.", shardIndex)
        let manifestName = String(format: "%02x.manifest.json", shardIndex)
        var removed = 0
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: segmentedDirectoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: []
            )
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(segmentedDirectoryURL.lastPathComponent)
        }

        for url in children {
            let candidate = url.standardizedFileURL
            guard candidate.deletingLastPathComponent() == segmentedDirectoryURL.standardizedFileURL else {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
            let name = candidate.lastPathComponent
            guard name.hasPrefix(prefix), name.hasSuffix(".json") else { continue }
            if name == manifestName || committedNames.contains(name) { continue }

            do {
                try boundary.requireExistingRegularFile(
                    candidate,
                    within: segmentedDirectoryURL,
                    fileManager: fileManager
                )
                try fileManager.removeItem(at: candidate)
            } catch {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(name)
            }
            removed += 1
        }
        return removed
    }

    private func publishGeneration(shardIndex: Int, entries: [Lane2ManagedArtifactSegmentEntry]) throws {
        do {
            try boundary.ensureDirectory(segmentedDirectoryURL, fileManager: fileManager)
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(segmentedDirectoryURL.lastPathComponent)
        }

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
            let url = segmentURL(
                shardIndex: shardIndex,
                generation: generation,
                segmentIndex: segmentIndex
            )
            do {
                try boundary.requireSafeDestination(url, within: segmentedDirectoryURL, fileManager: fileManager)
                try stableEncoder.encode(segment).write(to: url, options: [.atomic])
                try boundary.requireExistingRegularFile(url, within: segmentedDirectoryURL, fileManager: fileManager)
            } catch {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
        }

        let manifest = Manifest(
            schemaVersion: Self.schemaVersion,
            shardIndex: shardIndex,
            generation: generation,
            segmentCount: segmentCount,
            entryCount: ordered.count
        )
        let encodedManifest = try stableEncoder.encode(manifest)
        let pendingURL = pendingManifestURL(shardIndex)
        do {
            _ = try boundary.requireRegularFileOrMissing(
                pendingURL,
                within: segmentedDirectoryURL,
                fileManager: fileManager
            )
            try encodedManifest.write(to: pendingURL, options: [.atomic])
            try boundary.requireExistingRegularFile(
                pendingURL,
                within: segmentedDirectoryURL,
                fileManager: fileManager
            )
            let pending = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: pendingURL))
            guard pending.schemaVersion == manifest.schemaVersion,
                  pending.shardIndex == manifest.shardIndex,
                  pending.generation == manifest.generation,
                  pending.segmentCount == manifest.segmentCount,
                  pending.entryCount == manifest.entryCount else {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.verificationFailed(shardIndex)
            }
        } catch let failure as Lane2ManagedArtifactSegmentedMigrationFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(pendingURL.lastPathComponent)
        }

        var verifiedCount = 0
        for segmentIndex in 0..<segmentCount {
            let url = segmentURL(shardIndex: shardIndex, generation: generation, segmentIndex: segmentIndex)
            try requireSegmentFile(url)
            let decoded: Segment
            do {
                decoded = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
            } catch {
                throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
            }
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

        // Migration reaches authority only via an atomic write to a previously absent final manifest.
        // The fixed pending file is evidence/staging only and can be cleaned after publication.
        let finalURL = manifestURL(shardIndex)
        do {
            try boundary.requireSafeDestination(finalURL, within: segmentedDirectoryURL, fileManager: fileManager)
            try encodedManifest.write(to: finalURL, options: [.atomic])
            try boundary.requireExistingRegularFile(finalURL, within: segmentedDirectoryURL, fileManager: fileManager)
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(finalURL.lastPathComponent)
        }

        // Once final authority is visible, failure to retire a still-regular pending file is not a
        // reason to roll authority back. Unsafe replacement is never removed and remains visible to
        // the next bounded cleanup pass.
        if (try? boundary.nodeExists(pendingURL, fileManager: fileManager)) == true,
           (try? boundary.requireExistingRegularFile(
               pendingURL,
               within: segmentedDirectoryURL,
               fileManager: fileManager
           )) != nil {
            try? fileManager.removeItem(at: pendingURL)
        }
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return nil }
            try boundary.requireExistingRegularFile(
                url,
                within: segmentedDirectoryURL,
                fileManager: fileManager
            )
        } catch {
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
              manifest.entryCount >= 0,
              manifest.segmentCount == Self.segmentCount(for: manifest.entryCount) else {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptManifest(url.lastPathComponent)
        }
        return manifest
    }

    private func requireSegmentFile(_ url: URL) throws {
        do {
            try boundary.requireExistingRegularFile(
                url,
                within: segmentedDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw Lane2ManagedArtifactSegmentedMigrationFailure.corruptSegment(url.lastPathComponent)
        }
    }

    private var boundary: LibraryManagedPathBoundary {
        LibraryManagedPathBoundary(rootURL: rootURL)
    }

    private var v1DirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }

    private var shardsDirectoryURL: URL {
        v1DirectoryURL.appendingPathComponent("Shards", isDirectory: true)
    }

    private var segmentedDirectoryURL: URL {
        v1DirectoryURL.appendingPathComponent("Segmented", isDirectory: true)
    }

    private func legacyShardURL(_ shardIndex: Int) -> URL {
        shardsDirectoryURL.appendingPathComponent(String(format: "%02x.json", shardIndex), isDirectory: false)
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
        let quotient = entryCount / entriesPerSegment
        return quotient + (entryCount % entriesPerSegment == 0 ? 0 : 1)
    }

    private static func entryOrder(
        _ lhs: Lane2ManagedArtifactSegmentEntry,
        _ rhs: Lane2ManagedArtifactSegmentEntry
    ) -> Bool {
        lhs.relativePath < rhs.relativePath
    }
}
