import Foundation

private final class Lane2SegmentedStreamingTraversalFileManagerHandle: @unchecked Sendable {
    let value: FileManager
    init(_ value: FileManager) { self.value = value }
}

/// AW43 fully streaming orphan traversal for committed segmented managed-artifact shards.
/// Each committed segment is decoded and discarded independently; traversal never materializes an
/// entire committed shard before candidate filtering. Legacy fallback remains bounded by the AW38
/// encoded-size ceiling for pre-segmented compatibility.
public struct Lane2ManagedArtifactSegmentedStreamingTraversal: Sendable {
    public static let shardCount = 256
    public static let entriesPerSegment = 512
    public static let maximumLegacyEncodedBytes = 8 * 1024 * 1024

    private struct Entry: Codable, Hashable, Sendable {
        let relativePath: String
        let modificationTime: TimeInterval
    }

    private struct LegacyShard: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let entries: [Entry]
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
        let entries: [Entry]
    }

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManagerHandle: Lane2SegmentedStreamingTraversalFileManagerHandle

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery", fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManagerHandle = Lane2SegmentedStreamingTraversalFileManagerHandle(fileManager)
    }

    private var fileManager: FileManager { fileManagerHandle.value }

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
            let shardIndex = traversal.shardIndex
            try validateShard(shardIndex)
            let after = traversal.afterRelativePath
            let completed: Bool
            if let manifest = try loadManifest(shardIndex) {
                completed = try scanCommitted(
                    manifest: manifest,
                    after: after,
                    now: now,
                    gracePeriod: gracePeriod,
                    candidateLimit: effectiveCandidates,
                    candidates: &candidates,
                    scanned: &scanned,
                    traversal: &traversal
                )
            } else {
                completed = try scanLegacy(
                    shardIndex: shardIndex,
                    after: after,
                    now: now,
                    gracePeriod: gracePeriod,
                    candidateLimit: effectiveCandidates,
                    candidates: &candidates,
                    scanned: &scanned,
                    traversal: &traversal
                )
            }
            visited += 1
            if completed {
                traversal = Lane2ManagedArtifactInventoryTraversal(shardIndex: (shardIndex + 1) % Self.shardCount)
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

    private func scanCommitted(
        manifest: Manifest,
        after: String?,
        now: Date,
        gracePeriod: TimeInterval,
        candidateLimit: Int,
        candidates: inout [Lane2ManagedArtifactInventoryCandidate],
        scanned: inout Int,
        traversal: inout Lane2ManagedArtifactInventoryTraversal
    ) throws -> Bool {
        var decodedCount = 0
        var previousPath: String?
        for segmentIndex in 0..<manifest.segmentCount {
            let segment = try loadSegment(manifest: manifest, segmentIndex: segmentIndex)
            decodedCount += segment.entries.count
            for entry in segment.entries {
                try validateEntry(entry, shardIndex: manifest.shardIndex, previousPath: &previousPath)
                guard after == nil || entry.relativePath > after! else { continue }
                scanned += 1
                traversal = Lane2ManagedArtifactInventoryTraversal(
                    shardIndex: manifest.shardIndex,
                    afterRelativePath: entry.relativePath
                )
                if now.timeIntervalSince1970 - entry.modificationTime >= gracePeriod {
                    candidates.append(
                        Lane2ManagedArtifactInventoryCandidate(
                            relativePath: entry.relativePath,
                            recordedModificationTime: entry.modificationTime
                        )
                    )
                    if candidates.count >= candidateLimit {
                        return false
                    }
                }
            }
        }
        guard decodedCount == manifest.entryCount else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.verificationFailed(manifest.shardIndex)
        }
        return true
    }

    private func scanLegacy(
        shardIndex: Int,
        after: String?,
        now: Date,
        gracePeriod: TimeInterval,
        candidateLimit: Int,
        candidates: inout [Lane2ManagedArtifactInventoryCandidate],
        scanned: inout Int,
        traversal: inout Lane2ManagedArtifactInventoryTraversal
    ) throws -> Bool {
        let entries = try loadLegacyEntries(shardIndex)
        var previousPath: String?
        for entry in entries {
            try validateEntry(entry, shardIndex: shardIndex, previousPath: &previousPath)
            guard after == nil || entry.relativePath > after! else { continue }
            scanned += 1
            traversal = Lane2ManagedArtifactInventoryTraversal(shardIndex: shardIndex, afterRelativePath: entry.relativePath)
            if now.timeIntervalSince1970 - entry.modificationTime >= gracePeriod {
                candidates.append(
                    Lane2ManagedArtifactInventoryCandidate(
                        relativePath: entry.relativePath,
                        recordedModificationTime: entry.modificationTime
                    )
                )
                if candidates.count >= candidateLimit {
                    return false
                }
            }
        }
        return true
    }

    private func validateEntry(_ entry: Entry, shardIndex: Int, previousPath: inout String?) throws {
        let path = try Self.normalize(entry.relativePath)
        guard path == entry.relativePath,
              Self.isManaged(path),
              Self.shardIndex(path) == shardIndex,
              previousPath == nil || previousPath! < path else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(String(format: "%02x", shardIndex))
        }
        previousPath = path
    }

    private func loadLegacyEntries(_ shardIndex: Int) throws -> [Entry] {
        let url = legacyShardURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptLegacyShard(url.lastPathComponent)
        }
        guard max(values.fileSize ?? 0, 0) <= Self.maximumLegacyEncodedBytes else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.legacyShardOversized(url.lastPathComponent)
        }
        let legacy: LegacyShard
        do {
            legacy = try JSONDecoder().decode(LegacyShard.self, from: Data(contentsOf: url))
        } catch {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptLegacyShard(url.lastPathComponent)
        }
        guard legacy.schemaVersion == 1, legacy.shardIndex == shardIndex else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptLegacyShard(url.lastPathComponent)
        }
        return legacy.entries
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptManifest(url.lastPathComponent)
        }
        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
        } catch {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptManifest(url.lastPathComponent)
        }
        guard manifest.schemaVersion == 1,
              manifest.shardIndex == shardIndex,
              manifest.entryCount >= 0,
              manifest.segmentCount == Self.segmentCount(manifest.entryCount) else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptManifest(url.lastPathComponent)
        }
        return manifest
    }

    private func loadSegment(manifest: Manifest, segmentIndex: Int) throws -> Segment {
        let url = segmentURL(shardIndex: manifest.shardIndex, generation: manifest.generation, segmentIndex: segmentIndex)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(url.lastPathComponent)
        }
        let segment: Segment
        do {
            segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
        } catch {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(url.lastPathComponent)
        }
        guard segment.schemaVersion == 1,
              segment.shardIndex == manifest.shardIndex,
              segment.generation == manifest.generation,
              segment.segmentIndex == segmentIndex,
              segment.entries.count <= Self.entriesPerSegment else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.corruptSegment(url.lastPathComponent)
        }
        return segment
    }

    private func validateShard(_ index: Int) throws {
        guard (0..<Self.shardCount).contains(index) else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidShard(index)
        }
    }

    private var v1DirectoryURL: URL {
        rootURL.appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }
    private var segmentedDirectoryURL: URL { v1DirectoryURL.appendingPathComponent("Segmented", isDirectory: true) }
    private func legacyShardURL(_ index: Int) -> URL {
        v1DirectoryURL.appendingPathComponent("Shards", isDirectory: true)
            .appendingPathComponent(String(format: "%02x.json", index))
    }
    private func manifestURL(_ index: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.manifest.json", index))
    }
    private func segmentURL(shardIndex: Int, generation: UUID, segmentIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, segmentIndex))
    }

    private static func segmentCount(_ count: Int) -> Int {
        count == 0 ? 0 : (count + entriesPerSegment - 1) / entriesPerSegment
    }
    private static func isManaged(_ path: String) -> Bool {
        path.split(separator: "/").first.map { ["Imports", "Stems", "Exports"].contains(String($0)) } ?? false
    }
    private static func normalize(_ raw: String) throws -> String {
        let path = raw.replacingOccurrences(of: "\\", with: "/")
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\0"),
              !(path as NSString).isAbsolutePath else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidRelativePath(raw)
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2ManagedArtifactSegmentedRuntimeFailure.invalidRelativePath(raw)
        }
        return parts.joined(separator: "/")
    }
    private static func shardIndex(_ path: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(shardCount))
    }
}