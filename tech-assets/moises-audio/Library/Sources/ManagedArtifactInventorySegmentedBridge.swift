import Foundation

/// AW41 compatibility bridge between the canonical AW29 inventory contract and the segmented
/// runtime. AW43 routes candidate preparation through the fully streaming traversal reader while
/// preserving the existing two-phase cursor contract. AW44 routes steady-state mutation through
/// the bounded segmented mutation writer so committed shards are never materialized as one array.
public struct Lane2ManagedArtifactInventorySegmentedBridge: Sendable {
    private struct CursorRecord: Codable, Sendable {
        static let schemaVersion = 1
        let schemaVersion: Int
        let traversal: Lane2ManagedArtifactInventoryTraversal
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

    public func registerManaged(relativePaths: [String]) throws {
        try boundedMutation.upsertManaged(relativePaths: relativePaths)
    }

    public func remove(relativePaths: [String]) throws {
        try boundedMutation.removeManaged(relativePaths: relativePaths)
    }

    public func prepareOrphanCandidateSlice(
        gracePeriod: TimeInterval = 3600,
        now: Date = Date(),
        candidateLimit: Int = Lane2ManagedArtifactInventory.defaultCandidateLimit,
        shardVisitLimit: Int = Lane2ManagedArtifactInventory.defaultShardVisitLimit
    ) throws -> Lane2ManagedArtifactInventorySlice {
        let prior = try loadTraversal()
        return try streamingTraversal.prepareOrphanCandidateSlice(
            priorTraversal: prior,
            gracePeriod: gracePeriod,
            now: now,
            candidateLimit: candidateLimit,
            shardVisitLimit: shardVisitLimit
        )
    }

    public func persistTraversal(after slice: Lane2ManagedArtifactInventorySlice) throws {
        guard slice.priorTraversal == try loadTraversal() else {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
        try fileManager.createDirectory(
            at: cursorURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let record = CursorRecord(
            schemaVersion: CursorRecord.schemaVersion,
            traversal: slice.nextTraversal
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(record).write(to: cursorURL, options: [.atomic])
    }

    public func resetTraversalForRecovery() throws {
        if fileManager.fileExists(atPath: cursorURL.path) {
            try fileManager.removeItem(at: cursorURL)
        }
    }

    private func loadTraversal() throws -> Lane2ManagedArtifactInventoryTraversal {
        guard fileManager.fileExists(atPath: cursorURL.path) else {
            return Lane2ManagedArtifactInventoryTraversal(shardIndex: 0)
        }
        do {
            let values = try cursorURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
            }
            let record = try JSONDecoder().decode(CursorRecord.self, from: Data(contentsOf: cursorURL))
            guard record.schemaVersion == CursorRecord.schemaVersion,
                  (0..<Lane2ManagedArtifactInventory.shardCount).contains(record.traversal.shardIndex) else {
                throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
            }
            if let after = record.traversal.afterRelativePath {
                guard try Lane2ManagedArtifactInventory.shardIndex(for: after) == record.traversal.shardIndex else {
                    throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
                }
            }
            return record.traversal
        } catch let failure as Lane2ManagedArtifactInventoryFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
    }

    private var boundedMutation: Lane2ManagedArtifactSegmentedBoundedMutation {
        Lane2ManagedArtifactSegmentedBoundedMutation(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
    }

    private var streamingTraversal: Lane2ManagedArtifactSegmentedStreamingTraversal {
        Lane2ManagedArtifactSegmentedStreamingTraversal(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
    }

    private var cursorURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("cursor.json", isDirectory: false)
    }
}
