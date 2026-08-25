import Foundation

public enum Lane2ManagedArtifactRuntimeAuthority: String, Hashable, Sendable {
    case legacyV1
    case segmentedCommitted
}

public struct Lane2ManagedArtifactRuntimeEntry: Codable, Hashable, Sendable {
    public let relativePath: String
    public let modificationTime: TimeInterval
    public init(relativePath: String, modificationTime: TimeInterval) {
        self.relativePath = relativePath
        self.modificationTime = modificationTime
    }
}

public enum Lane2ManagedArtifactSegmentedRuntimeFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case invalidShard(Int)
    case corruptLegacyShard(String)
    case legacyShardOversized(String)
    case corruptManifest(String)
    case corruptSegment(String)
    case unsafeManagedArtifact(String)
    case verificationFailed(Int)
}

/// AW40 steady-state router for AW29/AW39 managed-artifact inventory.
/// A committed segmented manifest wins over legacy bytes. The first successful mutation of a
/// legacy shard publishes a verified segmented generation and leaves legacy bytes as rollback
/// evidence. Subsequent mutations never rewrite the unbounded legacy JSON shard.
public struct Lane2ManagedArtifactSegmentedRuntime: Sendable {
    public static let shardCount = 256
    public static let entriesPerSegment = 512
    public static let maximumLegacyEncodedBytes = 8 * 1024 * 1024
    public static let managedRootNames = ["Imports", "Stems", "Exports"]

    private struct LegacyShard: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let entries: [Lane2ManagedArtifactRuntimeEntry]
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
        let entries: [Lane2ManagedArtifactRuntimeEntry]
    }

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManager: FileManager

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery", fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    public func authority(forShard shardIndex: Int) throws -> Lane2ManagedArtifactRuntimeAuthority {
        try validateShard(shardIndex)
        return try loadManifest(shardIndex) == nil ? .legacyV1 : .segmentedCommitted
    }

    public func loadShard(_ shardIndex: Int) throws -> [Lane2ManagedArtifactRuntimeEntry] {
        try validateShard(shardIndex)
        if let manifest = try loadManifest(shardIndex) {
            return try loadCommittedEntries(manifest)
        }
        return try loadLegacyEntries(shardIndex)
    }

    /// Future canonical registration hook. Every touched shard becomes segmented after this call.
    public func upsertManaged(relativePaths: [String]) throws {
        var grouped: [Int: [Lane2ManagedArtifactRuntimeEntry]] = [:]
        for raw in Array(Set(relativePaths)).sorted() {
            let path = try Self.normalize(raw)
            guard Self.isManaged(path) else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidRelativePath(raw) }
            guard let snapshot = try snapshot(path) else { continue }
            grouped[Self.shardIndex(path), default: []].append(snapshot)
        }
        for (shardIndex, updates) in grouped {
            var byPath = Dictionary(uniqueKeysWithValues: try loadShard(shardIndex).map { ($0.relativePath, $0) })
            for update in updates { byPath[update.relativePath] = update }
            try publish(shardIndex: shardIndex, entries: byPath.values.sorted(by: Self.entryOrder))
        }
    }

    /// Future canonical deletion hook. Empty segmented shards retain a zero-entry committed manifest,
    /// preventing stale legacy rollback bytes from becoming authoritative again.
    public func removeManaged(relativePaths: [String]) throws {
        var grouped: [Int: Set<String>] = [:]
        for raw in Array(Set(relativePaths)) {
            let path = try Self.normalize(raw)
            guard Self.isManaged(path) else { continue }
            grouped[Self.shardIndex(path), default: []].insert(path)
        }
        for (shardIndex, removals) in grouped {
            let retained = try loadShard(shardIndex).filter { !removals.contains($0.relativePath) }
            try publish(shardIndex: shardIndex, entries: retained)
        }
    }

    /// Bounded orphan traversal: committed shards are scanned one <=512-entry segment at a time.
    /// Legacy fallback is allowed only under AW38's 8 MiB ceiling.
    public func prepareOrphanCandidateSlice(
        priorTraversal: Lane2ManagedArtifactInventoryTraversal,
        gracePeriod: TimeInterval = 3600,
        now: Date = Date(),
        candidateLimit: Int = 128,
        shardVisitLimit: Int = 4
    ) throws -> Lane2ManagedArtifactInventorySlice {
        let effectiveCandidates = max(candidateLimit, 1)
        let effectiveShards = min(max(shardVisitLimit, 1), Self.shardCount)
        var traversal = priorTraversal
        var candidates: [Lane2ManagedArtifactInventoryCandidate] = []
        var scanned = 0
        var visited = 0

        while visited < effectiveShards && candidates.count < effectiveCandidates {
            try validateShard(traversal.shardIndex)
            let after = traversal.afterRelativePath
            var completedShard = true
            let ordered = try scanEntriesBoundedly(shardIndex: traversal.shardIndex)
            for entry in ordered where after == nil || entry.relativePath > after! {
                scanned += 1
                traversal = Lane2ManagedArtifactInventoryTraversal(shardIndex: traversal.shardIndex, afterRelativePath: entry.relativePath)
                if now.timeIntervalSince1970 - entry.modificationTime >= gracePeriod {
                    candidates.append(Lane2ManagedArtifactInventoryCandidate(relativePath: entry.relativePath, recordedModificationTime: entry.modificationTime))
                    if candidates.count >= effectiveCandidates {
                        completedShard = false
                        break
                    }
                }
            }
            visited += 1
            if completedShard {
                traversal = Lane2ManagedArtifactInventoryTraversal(shardIndex: (traversal.shardIndex + 1) % Self.shardCount)
            } else {
                break
            }
        }
        return Lane2ManagedArtifactInventorySlice(
            candidates: candidates,
            scannedInventoryEntries: scanned,
            visitedShards: visited,
            candidateLimit: effectiveCandidates,
            shardVisitLimit: effectiveShards,
            priorTraversal: priorTraversal,
            nextTraversal: traversal
        )
    }

    private func scanEntriesBoundedly(shardIndex: Int) throws -> [Lane2ManagedArtifactRuntimeEntry] {
        if let manifest = try loadManifest(shardIndex) {
            var result: [Lane2ManagedArtifactRuntimeEntry] = []
            // Each individual decode is bounded to entriesPerSegment. The returned array is retained
            // only for the current shard; canonical wiring can further stream this in a later wave.
            for index in 0..<manifest.segmentCount {
                result.append(contentsOf: try loadSegment(manifest: manifest, segmentIndex: index).entries)
            }
            guard result.count == manifest.entryCount else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.verificationFailed(shardIndex) }
            return result.sorted(by: Self.entryOrder)
        }
        return try loadLegacyEntries(shardIndex)
    }

    private func snapshot(_ relativePath: String) throws -> Lane2ManagedArtifactRuntimeEntry? {
        let url = try absoluteURL(relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.unsafeManagedArtifact(relativePath)
        }
        return Lane2ManagedArtifactRuntimeEntry(relativePath: relativePath, modificationTime: (values.contentModificationDate ?? .distantPast).timeIntervalSince1970)
    }

    private func loadLegacyEntries(_ shardIndex: Int) throws -> [Lane2ManagedArtifactRuntimeEntry] {
        let url = legacyShardURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptLegacyShard(url.lastPathComponent) }
        guard max(values.fileSize ?? 0, 0) <= Self.maximumLegacyEncodedBytes else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.legacyShardOversized(url.lastPathComponent) }
        let legacy: LegacyShard
        do { legacy = try JSONDecoder().decode(LegacyShard.self, from: Data(contentsOf: url)) }
        catch { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptLegacyShard(url.lastPathComponent) }
        guard legacy.schemaVersion == 1, legacy.shardIndex == shardIndex else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptLegacyShard(url.lastPathComponent) }
        return try validate(entries: legacy.entries, shardIndex: shardIndex)
    }

    private func loadCommittedEntries(_ manifest: Manifest) throws -> [Lane2ManagedArtifactRuntimeEntry] {
        var result: [Lane2ManagedArtifactRuntimeEntry] = []
        result.reserveCapacity(manifest.entryCount)
        for index in 0..<manifest.segmentCount { result.append(contentsOf: try loadSegment(manifest: manifest, segmentIndex: index).entries) }
        guard result.count == manifest.entryCount else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.verificationFailed(manifest.shardIndex) }
        return try validate(entries: result, shardIndex: manifest.shardIndex)
    }

    private func loadSegment(manifest: Manifest, segmentIndex: Int) throws -> Segment {
        let url = segmentURL(shardIndex: manifest.shardIndex, generation: manifest.generation, segmentIndex: segmentIndex)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(url.lastPathComponent) }
        let segment: Segment
        do { segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url)) }
        catch { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(url.lastPathComponent) }
        guard segment.schemaVersion == 1, segment.shardIndex == manifest.shardIndex, segment.generation == manifest.generation, segment.segmentIndex == segmentIndex, segment.entries.count <= Self.entriesPerSegment else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(url.lastPathComponent) }
        return segment
    }

    private func publish(shardIndex: Int, entries: [Lane2ManagedArtifactRuntimeEntry]) throws {
        try validateShard(shardIndex)
        let ordered = try validate(entries: entries.sorted(by: Self.entryOrder), shardIndex: shardIndex)
        try fileManager.createDirectory(at: segmentedDirectoryURL, withIntermediateDirectories: true)
        let generation = UUID()
        let segmentCount = Self.segmentCount(ordered.count)
        for index in 0..<segmentCount {
            let start = index * Self.entriesPerSegment
            let end = min(start + Self.entriesPerSegment, ordered.count)
            let segment = Segment(schemaVersion: 1, shardIndex: shardIndex, generation: generation, segmentIndex: index, entries: Array(ordered[start..<end]))
            try stableEncoder.encode(segment).write(to: segmentURL(shardIndex: shardIndex, generation: generation, segmentIndex: index), options: [.atomic])
        }
        // Complete read-back before authority publication.
        let provisional = Manifest(schemaVersion: 1, shardIndex: shardIndex, generation: generation, segmentCount: segmentCount, entryCount: ordered.count)
        var verified = 0
        for index in 0..<segmentCount { verified += try loadSegment(manifest: provisional, segmentIndex: index).entries.count }
        guard verified == ordered.count else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.verificationFailed(shardIndex) }
        // Atomic replacement preserves any prior committed manifest until the new bytes are durable.
        try stableEncoder.encode(provisional).write(to: manifestURL(shardIndex), options: [.atomic])
        guard try loadCommittedEntries(provisional) == ordered else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.verificationFailed(shardIndex) }
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptManifest(url.lastPathComponent) }
        let manifest: Manifest
        do { manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url)) }
        catch { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptManifest(url.lastPathComponent) }
        guard manifest.schemaVersion == 1, manifest.shardIndex == shardIndex, manifest.entryCount >= 0, manifest.segmentCount == Self.segmentCount(manifest.entryCount) else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptManifest(url.lastPathComponent) }
        return manifest
    }

    private func validate(entries: [Lane2ManagedArtifactRuntimeEntry], shardIndex: Int) throws -> [Lane2ManagedArtifactRuntimeEntry] {
        var seen = Set<String>()
        var result: [Lane2ManagedArtifactRuntimeEntry] = []
        result.reserveCapacity(entries.count)
        for entry in entries {
            let path = try Self.normalize(entry.relativePath)
            guard path == entry.relativePath, Self.isManaged(path), Self.shardIndex(path) == shardIndex, seen.insert(path).inserted else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(String(format: "%02x", shardIndex)) }
            result.append(entry)
        }
        return result.sorted(by: Self.entryOrder)
    }

    private func validateShard(_ shardIndex: Int) throws {
        guard (0..<Self.shardCount).contains(shardIndex) else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidShard(shardIndex) }
    }

    private func absoluteURL(_ relativePath: String) throws -> URL {
        let path = try Self.normalize(relativePath)
        let url = rootURL.appendingPathComponent(path).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard url.path.hasPrefix(prefix) else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidRelativePath(relativePath) }
        return url
    }

    private var v1DirectoryURL: URL { rootURL.appendingPathComponent(recoveryDirectoryName, isDirectory: true).appendingPathComponent("ArtifactInventory", isDirectory: true).appendingPathComponent("v1", isDirectory: true) }
    private var segmentedDirectoryURL: URL { v1DirectoryURL.appendingPathComponent("Segmented", isDirectory: true) }
    private func legacyShardURL(_ index: Int) -> URL { v1DirectoryURL.appendingPathComponent("Shards", isDirectory: true).appendingPathComponent(String(format: "%02x.json", index)) }
    private func manifestURL(_ index: Int) -> URL { segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.manifest.json", index)) }
    private func segmentURL(shardIndex: Int, generation: UUID, segmentIndex: Int) -> URL { segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, segmentIndex)) }
    private var stableEncoder: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }

    private static func segmentCount(_ count: Int) -> Int { count == 0 ? 0 : (count + entriesPerSegment - 1) / entriesPerSegment }
    private static func entryOrder(_ a: Lane2ManagedArtifactRuntimeEntry, _ b: Lane2ManagedArtifactRuntimeEntry) -> Bool { a.relativePath < b.relativePath }
    private static func isManaged(_ path: String) -> Bool { path.split(separator: "/").first.map { managedRootNames.contains(String($0)) } ?? false }
    private static func normalize(_ raw: String) throws -> String {
        let path = raw.replacingOccurrences(of: "\\", with: "/")
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0"), !(path as NSString).isAbsolutePath else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidRelativePath(raw) }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidRelativePath(raw) }
        return parts.joined(separator: "/")
    }
    private static func shardIndex(_ path: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in path.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
        return Int(hash % UInt64(shardCount))
    }
}
