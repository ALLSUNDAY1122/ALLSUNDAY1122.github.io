import Foundation

struct Lane2ManagedArtifactSegmentedShardStore: Sendable {
    static let schemaVersion = 1
    static let entriesPerSegment = 512

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
        let entries: [Lane2ManagedArtifactInventoryEntry]
    }

    let rootURL: URL
    let recoveryDirectoryName: String
    let fileManager: FileManager

    init(rootURL: URL, recoveryDirectoryName: String, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    func hasCommittedShard(_ shardIndex: Int) -> Bool {
        guard (0..<Lane2ManagedArtifactInventory.shardCount).contains(shardIndex) else { return false }
        let url = manifestURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return false }
        return manifest.schemaVersion == Self.schemaVersion && manifest.shardIndex == shardIndex
    }

    func loadCommittedEntries(_ shardIndex: Int) throws -> [Lane2ManagedArtifactInventoryEntry]? {
        let url = manifestURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
            }
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
            guard manifest.schemaVersion == Self.schemaVersion,
                  manifest.shardIndex == shardIndex,
                  manifest.segmentCount >= 0,
                  manifest.entryCount >= 0 else {
                throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
            }
            var entries: [Lane2ManagedArtifactInventoryEntry] = []
            entries.reserveCapacity(manifest.entryCount)
            for segmentIndex in 0..<manifest.segmentCount {
                let segmentURL = committedSegmentURL(
                    shardIndex: shardIndex,
                    generation: manifest.generation,
                    segmentIndex: segmentIndex
                )
                let segmentValues = try segmentURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard segmentValues.isRegularFile == true, segmentValues.isSymbolicLink != true else {
                    throw Lane2ManagedArtifactInventoryFailure.corruptShard(segmentURL.lastPathComponent)
                }
                let segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: segmentURL))
                guard segment.schemaVersion == Self.schemaVersion,
                      segment.shardIndex == shardIndex,
                      segment.generation == manifest.generation,
                      segment.segmentIndex == segmentIndex,
                      segment.entries.count <= Self.entriesPerSegment else {
                    throw Lane2ManagedArtifactInventoryFailure.corruptShard(segmentURL.lastPathComponent)
                }
                entries.append(contentsOf: segment.entries)
            }
            guard entries.count == manifest.entryCount else {
                throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
            }
            return entries
        } catch let failure as Lane2ManagedArtifactInventoryFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
        }
    }

    /// Crash contract: write a complete new generation first, read it back, and publish the small
    /// manifest last. The old v1 shard remains untouched as rollback evidence. A crash before manifest
    /// publication leaves the previous authority intact; after publication readers select the new
    /// generation. Orphaned uncommitted generations are harmless and can be swept later.
    func replaceCommittedShard(
        shardIndex: Int,
        entries: [Lane2ManagedArtifactInventoryEntry]
    ) throws {
        guard (0..<Lane2ManagedArtifactInventory.shardCount).contains(shardIndex) else {
            throw Lane2ManagedArtifactInventoryFailure.corruptShard(String(shardIndex))
        }
        try fileManager.createDirectory(at: segmentedDirectoryURL, withIntermediateDirectories: true)
        let generation = UUID()
        let ordered = entries.sorted { $0.relativePath < $1.relativePath }
        let chunks = stride(from: 0, to: ordered.count, by: Self.entriesPerSegment).map { start -> ArraySlice<Lane2ManagedArtifactInventoryEntry> in
            ordered[start..<min(start + Self.entriesPerSegment, ordered.count)]
        }
        for (segmentIndex, chunk) in chunks.enumerated() {
            let segment = Segment(
                schemaVersion: Self.schemaVersion,
                shardIndex: shardIndex,
                generation: generation,
                segmentIndex: segmentIndex,
                entries: Array(chunk)
            )
            let data = try stableEncoder.encode(segment)
            try data.write(
                to: committedSegmentURL(
                    shardIndex: shardIndex,
                    generation: generation,
                    segmentIndex: segmentIndex
                ),
                options: [.atomic]
            )
        }
        let manifest = Manifest(
            schemaVersion: Self.schemaVersion,
            shardIndex: shardIndex,
            generation: generation,
            segmentCount: chunks.count,
            entryCount: ordered.count
        )
        let pendingManifestURL = segmentedDirectoryURL.appendingPathComponent(
            String(format: "%02x.pending.json", shardIndex),
            isDirectory: false
        )
        let manifestData = try stableEncoder.encode(manifest)
        try manifestData.write(to: pendingManifestURL, options: [.atomic])

        // Read back all bytes before making this generation authoritative.
        var verifiedCount = 0
        for segmentIndex in 0..<chunks.count {
            let url = committedSegmentURL(
                shardIndex: shardIndex,
                generation: generation,
                segmentIndex: segmentIndex
            )
            let decoded = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
            guard decoded.schemaVersion == Self.schemaVersion,
                  decoded.shardIndex == shardIndex,
                  decoded.generation == generation,
                  decoded.segmentIndex == segmentIndex,
                  decoded.entries.count <= Self.entriesPerSegment else {
                throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
            }
            verifiedCount += decoded.entries.count
        }
        guard verifiedCount == ordered.count else {
            throw Lane2ManagedArtifactInventoryFailure.corruptShard(pendingManifestURL.lastPathComponent)
        }
        let finalManifestURL = manifestURL(shardIndex)
        if fileManager.fileExists(atPath: finalManifestURL.path) {
            try fileManager.removeItem(at: finalManifestURL)
        }
        try fileManager.moveItem(at: pendingManifestURL, to: finalManifestURL)
    }

    private var segmentedDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Segmented", isDirectory: true)
    }

    private func manifestURL(_ shardIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(
            String(format: "%02x.manifest.json", shardIndex),
            isDirectory: false
        )
    }

    private func committedSegmentURL(shardIndex: Int, generation: UUID, segmentIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(
            String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, segmentIndex),
            isDirectory: false
        )
    }

    private var stableEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
