import Foundation

private final class Lane2SegmentedBridgeFileManagerHandle: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}

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
    private let fileManagerHandle: Lane2SegmentedBridgeFileManagerHandle

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManagerHandle = Lane2SegmentedBridgeFileManagerHandle(fileManager)
    }

    private var fileManager: FileManager {
        fileManagerHandle.value
    }

    private var descriptorIO: Lane2LibraryDescriptorRelativeIO {
        Lane2LibraryDescriptorRelativeIO(rootURL: rootURL)
    }

    private var pathAuthority: Lane2ManagedArtifactInventoryPathAuthority {
        Lane2ManagedArtifactInventoryPathAuthority(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
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
        do {
            _ = try pathAuthority.requireV1DirectoryIfPresent()
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
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
        guard slice.priorTraversal == (try loadTraversal()) else {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
        do {
            try pathAuthority.ensureV1Directory()
            _ = try pathAuthority.requireRegularFileOrMissing(
                cursorURL,
                within: pathAuthority.v1DirectoryURL
            )
            let record = CursorRecord(
                schemaVersion: CursorRecord.schemaVersion,
                traversal: slice.nextTraversal
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try descriptorIO.writeRegularFileAtomically(
                encoder.encode(record),
                to: cursorURL
            )
            try pathAuthority.requireExistingRegularFile(
                cursorURL,
                within: pathAuthority.v1DirectoryURL
            )
        } catch let failure as Lane2ManagedArtifactInventoryFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
    }

    public func resetTraversalForRecovery() throws {
        do {
            guard try pathAuthority.nodeExists(cursorURL) else { return }
            try pathAuthority.requireExistingRegularFile(
                cursorURL,
                within: pathAuthority.v1DirectoryURL
            )
            try descriptorIO.removeLeaf(at: cursorURL)
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
    }

    private func loadTraversal() throws -> Lane2ManagedArtifactInventoryTraversal {
        do {
            guard try pathAuthority.nodeExists(cursorURL) else {
                return Lane2ManagedArtifactInventoryTraversal(shardIndex: 0)
            }
            try pathAuthority.requireExistingRegularFile(
                cursorURL,
                within: pathAuthority.v1DirectoryURL
            )
            let data = try descriptorIO.readRegularFile(
                at: cursorURL,
                maximumBytes: 64 * 1024
            )
            let record = try JSONDecoder().decode(CursorRecord.self, from: data)
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
        pathAuthority.cursorURL
    }
}
