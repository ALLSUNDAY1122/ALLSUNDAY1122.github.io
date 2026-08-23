import Foundation

public struct Lane2TombstonedProjectCompactionCandidate: Hashable, Sendable {
    public let projectUUID: UUID
    public let sourceAssetUUID: UUID
    public let artifactRelativePaths: [String]

    public init(projectUUID: UUID, sourceAssetUUID: UUID, artifactRelativePaths: [String]) {
        self.projectUUID = projectUUID
        self.sourceAssetUUID = sourceAssetUUID
        self.artifactRelativePaths = Array(Set(artifactRelativePaths)).sorted()
    }
}

public struct Lane2TombstonedProjectCompactionPlan: Equatable, Sendable {
    public let artifactRelativePathsToDelete: [String]
    public let retainedLiveArtifactPaths: [String]

    public init(artifactRelativePathsToDelete: [String], retainedLiveArtifactPaths: [String]) {
        self.artifactRelativePathsToDelete = artifactRelativePathsToDelete.sorted()
        self.retainedLiveArtifactPaths = retainedLiveArtifactPaths.sorted()
    }
}

public struct Lane2TombstonedMetadataCompactionResult: Equatable, Sendable {
    public let projectUUID: UUID
    public let projectRecordRemoved: Bool
    public let processingRecordsRemoved: Int
    public let stemRecordsRemoved: Int
    public let editRecordsRemoved: Int
    public let stemMixRecordsRemoved: Int
    public let setlistEntryRecordsRemoved: Int
    public let sourceAssetRecordRemoved: Bool
    public let sourceAssetRecordRetained: Bool
    public let wasAlreadyAbsent: Bool

    public init(
        projectUUID: UUID,
        projectRecordRemoved: Bool,
        processingRecordsRemoved: Int,
        stemRecordsRemoved: Int,
        editRecordsRemoved: Int,
        stemMixRecordsRemoved: Int,
        setlistEntryRecordsRemoved: Int,
        sourceAssetRecordRemoved: Bool,
        sourceAssetRecordRetained: Bool,
        wasAlreadyAbsent: Bool = false
    ) {
        self.projectUUID = projectUUID
        self.projectRecordRemoved = projectRecordRemoved
        self.processingRecordsRemoved = processingRecordsRemoved
        self.stemRecordsRemoved = stemRecordsRemoved
        self.editRecordsRemoved = editRecordsRemoved
        self.stemMixRecordsRemoved = stemMixRecordsRemoved
        self.setlistEntryRecordsRemoved = setlistEntryRecordsRemoved
        self.sourceAssetRecordRemoved = sourceAssetRecordRemoved
        self.sourceAssetRecordRetained = sourceAssetRecordRetained
        self.wasAlreadyAbsent = wasAlreadyAbsent
    }

    public static func alreadyAbsent(projectUUID: UUID) -> Self {
        Self(
            projectUUID: projectUUID,
            projectRecordRemoved: false,
            processingRecordsRemoved: 0,
            stemRecordsRemoved: 0,
            editRecordsRemoved: 0,
            stemMixRecordsRemoved: 0,
            setlistEntryRecordsRemoved: 0,
            sourceAssetRecordRemoved: false,
            sourceAssetRecordRetained: false,
            wasAlreadyAbsent: true
        )
    }
}

public enum Lane2TombstonedMetadataCompactionFailure: Error, Equatable, Sendable {
    case duplicateProjectIdentity(UUID)
    case liveProjectCannotCompact(UUID)
    case missingSourceAsset(UUID)
    case unsafeArtifactPath(String)
    case journalArtifactNotOwnedByProject(String)
    case journalTargetsLiveArtifact(String)
}

/// Portable authorization policy shared by current deletes, interrupted deletes and historical
/// tombstone backfill. It never authorizes deletion outside app-owned Imports/Stems roots.
public enum Lane2TombstonedMetadataCompactionPolicy {
    /// Computes the destructive artifact subset for a tombstone. Only app-owned source/stem roots
    /// are accepted here: historical tombstone metadata is not trusted to authorize deletion from
    /// recovery, export, staging or arbitrary roots. Live-project paths always win retention.
    public static func plan(
        candidate: Lane2TombstonedProjectCompactionCandidate,
        liveReferencedArtifactPaths: Set<String>
    ) throws -> Lane2TombstonedProjectCompactionPlan {
        let normalized = try candidate.artifactRelativePaths.map(validateOwnedDeletionPath)
        let unique = Set(normalized)
        let retained = unique.intersection(liveReferencedArtifactPaths)
        return Lane2TombstonedProjectCompactionPlan(
            artifactRelativePathsToDelete: Array(unique.subtracting(retained)),
            retainedLiveArtifactPaths: Array(retained)
        )
    }

    /// Existing journals are durable intent, but they are not blindly trusted on relaunch. A journal
    /// may delete only paths still attributable to the tombstoned project and not referenced by a
    /// currently live project. A subset is accepted because older deletes may have conservatively
    /// retained a path that later became otherwise unreferenced.
    public static func requireAuthorizedJournal(
        relativePaths: [String],
        candidate: Lane2TombstonedProjectCompactionCandidate,
        liveReferencedArtifactPaths: Set<String>
    ) throws {
        let candidatePaths = Set(try candidate.artifactRelativePaths.map(validateOwnedDeletionPath))
        let normalizedJournal = try relativePaths.map(validateOwnedDeletionPath)
        for path in normalizedJournal {
            if liveReferencedArtifactPaths.contains(path) {
                throw Lane2TombstonedMetadataCompactionFailure.journalTargetsLiveArtifact(path)
            }
            guard candidatePaths.contains(path) else {
                throw Lane2TombstonedMetadataCompactionFailure.journalArtifactNotOwnedByProject(path)
            }
        }
    }

    public static func requireUniqueProjects(
        _ candidates: [Lane2TombstonedProjectCompactionCandidate]
    ) throws {
        var seen = Set<UUID>()
        for candidate in candidates where !seen.insert(candidate.projectUUID).inserted {
            throw Lane2TombstonedMetadataCompactionFailure.duplicateProjectIdentity(candidate.projectUUID)
        }
    }

    /// A source AssetRecord can disappear only after every other ProjectRecord — live or tombstoned —
    /// has stopped referencing that exact asset identity.
    public static func shouldRemoveSourceAsset(
        sourceAssetUUID: UUID,
        remainingProjectSourceAssetUUIDs: Set<UUID>
    ) -> Bool {
        !remainingProjectSourceAssetUUIDs.contains(sourceAssetUUID)
    }

    private static func validateOwnedDeletionPath(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard normalized == relativePath,
              !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2TombstonedMetadataCompactionFailure.unsafeArtifactPath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
              parts[0] == "Imports" || parts[0] == "Stems" else {
            throw Lane2TombstonedMetadataCompactionFailure.unsafeArtifactPath(relativePath)
        }
        return parts.joined(separator: "/")
    }
}
