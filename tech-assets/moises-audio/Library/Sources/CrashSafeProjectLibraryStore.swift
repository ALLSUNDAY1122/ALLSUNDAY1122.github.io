import Foundation

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public struct LibraryRecoveryReport: Hashable, Sendable {
    public let discardedPrepared: [ProjectID]
    public let completedCommitted: [ProjectID]
    public let promotedInterruptedTombstones: [ProjectID]

    public init(
        discardedPrepared: [ProjectID],
        completedCommitted: [ProjectID],
        promotedInterruptedTombstones: [ProjectID]
    ) {
        self.discardedPrepared = discardedPrepared
        self.completedCommitted = completedCommitted
        self.promotedInterruptedTombstones = promotedInterruptedTombstones
    }
}

/// Production facade for the L2-M01 Core Data adapter.
/// It adds file/database ordering guarantees without changing frozen Shared contracts.
public final class CrashSafeProjectLibraryStore:
    @unchecked Sendable,
    ProjectLibraryPersisting,
    LibraryMaintenanceProjectProviding
{
    private let metadata: CoreDataProjectLibraryStore
    private let artifacts: LibraryArtifactLifecycle
    private let mutationGate = Lane2LibraryMutationGate()

    public init(metadata: CoreDataProjectLibraryStore, artifactRootURL: URL) throws {
        self.metadata = metadata
        self.artifacts = LibraryArtifactLifecycle(rootURL: artifactRootURL)
        try artifacts.ensureLayout()
    }

    /// Preferred construction path: open metadata then reconcile any delete journal/tombstone left by interruption.
    public static func open(
        metadataConfiguration: CoreDataProjectLibraryStore.Configuration,
        artifactRootURL: URL
    ) async throws -> CrashSafeProjectLibraryStore {
        let store = try CrashSafeProjectLibraryStore(
            metadata: CoreDataProjectLibraryStore(configuration: metadataConfiguration),
            artifactRootURL: artifactRootURL
        )
        _ = try await store.recoverInterruptedOperations()
        return store
    }

    public func createProject(source: LocalAudioAsset) async throws -> ProjectID {
        try await withMutationGate {
            try artifacts.requireReady(relativePath: source.relativePath)
            return try await metadata.createProject(source: source)
        }
    }

    public func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {
        try await metadata.recordProcessing(projectID: projectID, snapshot: snapshot)
    }

    public func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {
        try await withMutationGate {
            for stem in stems {
                try artifacts.requireReady(relativePath: stem.relativePath)
            }
            try await metadata.recordStems(projectID: projectID, stems: stems)
        }
    }

    public func listProjects() async throws -> [PersistedProjectSnapshot] {
        try await metadata.listProjects()
    }

    public func listMaintenanceProjects() async throws -> [LibraryMaintenanceProject] {
        try await metadata.listMaintenanceProjects()
    }

    public func listLiveProjectIDs() async throws -> Set<ProjectID> {
        try await metadata.listLiveProjectIDs()
    }

    public func containsLiveProject(projectID: ProjectID) async throws -> Bool {
        try await metadata.containsLiveProject(projectID: projectID)
    }

    public func loadProject(projectID: ProjectID) async throws -> PersistedProjectSnapshot? {
        try await metadata.loadProject(projectID: projectID)
    }

    public func saveUserEdits(projectID: ProjectID, edits: ProjectUserEdits) async throws {
        try await metadata.saveUserEdits(projectID: projectID, edits: edits)
    }

    public func createSetlist(name: String) async throws -> SetlistID {
        try await metadata.createSetlist(name: name)
    }

    public func renameSetlist(setlistID: SetlistID, name: String) async throws {
        try await metadata.renameSetlist(setlistID: setlistID, name: name)
    }

    public func listSetlists() async throws -> [SetlistSnapshot] {
        try await metadata.listSetlists()
    }

    public func replaceSetlistEntries(
        setlistID: SetlistID,
        orderedProjectIDs: [ProjectID]
    ) async throws {
        try await metadata.replaceSetlistEntries(
            setlistID: setlistID,
            orderedProjectIDs: orderedProjectIDs
        )
    }

    public func deleteSetlist(setlistID: SetlistID) async throws {
        try await metadata.deleteSetlist(setlistID: setlistID)
    }

    /// Sequence:
    /// 1) read a lightweight live-project artifact projection,
    /// 2) durable PREPARED journal (non-destructive),
    /// 3) metadata tombstone transaction,
    /// 4) mark journal COMMITTED,
    /// 5) validate journal ownership/live references,
    /// 6) idempotent file deletion and durable ARTIFACTS_DELETED marker,
    /// 7) physical Core Data project/child compaction,
    /// 8) retire the journal only after metadata compaction commits.
    /// A crash in every gap converges safely during recoverInterruptedOperations().
    public func deleteProject(projectID: ProjectID) async throws {
        try await withMutationGate {
            let projects = try await metadata.listMaintenanceProjects()
            guard let target = projects.first(where: { $0.projectID == projectID }) else {
                _ = try await recoverInterruptedOperationsUnlocked()
                return
            }

            let otherReferences = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(
                in: projects,
                excluding: projectID
            )
            let relativePaths = target.artifactRelativePaths.filter {
                !otherReferences.contains($0)
            }

            try artifacts.persistPreparedDeletion(
                projectUUID: projectID.rawValue,
                relativePaths: relativePaths
            )
            try await metadata.deleteProject(projectID: projectID)
            try artifacts.markDeletionCommitted(projectUUID: projectID.rawValue)
            _ = try await recoverInterruptedOperationsUnlocked()
        }
    }

    public func recoveryPlan(projectID: ProjectID) async throws -> ProcessingRecoveryPlan {
        try await metadata.recoveryPlan(projectID: projectID)
    }

    /// Reconciles durable delete journals and also backfills older physically retained tombstones.
    /// Destructive journal paths are re-authorized against current tombstone ownership and live
    /// references before any file is removed. Metadata is compacted only after artifact deletion is
    /// durably recorded as ARTIFACTS_DELETED.
    @discardableResult
    public func recoverInterruptedOperations() async throws -> LibraryRecoveryReport {
        try await withMutationGate {
            try await recoverInterruptedOperationsUnlocked()
        }
    }

    private func recoverInterruptedOperationsUnlocked() async throws -> LibraryRecoveryReport {
        let journals = try artifacts.pendingDeletionJournals()
        let candidates = try await metadata.listTombstonedProjectCompactionCandidates()

        guard !journals.isEmpty || !candidates.isEmpty else {
            return LibraryRecoveryReport(
                discardedPrepared: [],
                completedCommitted: [],
                promotedInterruptedTombstones: []
            )
        }

        let liveProjects = try await metadata.listMaintenanceProjects()
        let liveIDs = Set(liveProjects.map(\.projectID))
        let liveReferences = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(in: liveProjects)
        let candidateByID = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.projectUUID, $0) }
        )
        let journalProjectIDs = Set(journals.map(\.projectUUID))

        var discarded: [ProjectID] = []
        var completed: [ProjectID] = []
        var promoted: [ProjectID] = []

        for journal in journals {
            let projectID = ProjectID(rawValue: journal.projectUUID)

            switch journal.phase {
            case .prepared:
                if liveIDs.contains(projectID) {
                    try artifacts.discardPreparedDeletion(projectUUID: journal.projectUUID)
                    discarded.append(projectID)
                    continue
                }
                guard let candidate = candidateByID[journal.projectUUID] else {
                    throw Lane2TombstonedMetadataCompactionFailure.missingTombstoneCandidate(
                        journal.projectUUID
                    )
                }
                try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
                    relativePaths: journal.relativePaths,
                    candidate: candidate,
                    liveReferencedArtifactPaths: liveReferences
                )
                try artifacts.markDeletionCommitted(projectUUID: journal.projectUUID)
                try artifacts.executeCommittedDeletion(projectUUID: journal.projectUUID)
                _ = try await metadata.compactTombstonedProject(projectID: projectID)
                try artifacts.completeMetadataCompaction(projectUUID: journal.projectUUID)
                promoted.append(projectID)

            case .committed:
                guard !liveIDs.contains(projectID) else {
                    throw Lane2TombstonedMetadataCompactionFailure.liveProjectCannotCompact(
                        journal.projectUUID
                    )
                }
                guard let candidate = candidateByID[journal.projectUUID] else {
                    throw Lane2TombstonedMetadataCompactionFailure.missingTombstoneCandidate(
                        journal.projectUUID
                    )
                }
                try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
                    relativePaths: journal.relativePaths,
                    candidate: candidate,
                    liveReferencedArtifactPaths: liveReferences
                )
                try artifacts.executeCommittedDeletion(projectUUID: journal.projectUUID)
                _ = try await metadata.compactTombstonedProject(projectID: projectID)
                try artifacts.completeMetadataCompaction(projectUUID: journal.projectUUID)
                completed.append(projectID)

            case .artifactsDeleted:
                guard !liveIDs.contains(projectID) else {
                    throw Lane2TombstonedMetadataCompactionFailure.liveProjectCannotCompact(
                        journal.projectUUID
                    )
                }
                if candidateByID[journal.projectUUID] != nil {
                    _ = try await metadata.compactTombstonedProject(projectID: projectID)
                }
                try artifacts.completeMetadataCompaction(projectUUID: journal.projectUUID)
                completed.append(projectID)
            }
        }

        // Older builds could leave tombstones after deleting artifacts and removing their journal.
        // Recreate a COMMITTED intent from the still-durable tombstone, but only for validated
        // source/stem paths not referenced by any live project.
        for candidate in candidates where !journalProjectIDs.contains(candidate.projectUUID) {
            let plan = try Lane2TombstonedMetadataCompactionPolicy.plan(
                candidate: candidate,
                liveReferencedArtifactPaths: liveReferences
            )
            try artifacts.persistCommittedDeletion(
                projectUUID: candidate.projectUUID,
                relativePaths: plan.artifactRelativePathsToDelete
            )
            try artifacts.executeCommittedDeletion(projectUUID: candidate.projectUUID)
            let projectID = ProjectID(rawValue: candidate.projectUUID)
            _ = try await metadata.compactTombstonedProject(projectID: projectID)
            try artifacts.completeMetadataCompaction(projectUUID: candidate.projectUUID)
            completed.append(projectID)
        }

        return LibraryRecoveryReport(
            discardedPrepared: discarded.sorted(by: projectIDLessThan),
            completedCommitted: completed.sorted(by: projectIDLessThan),
            promotedInterruptedTombstones: promoted.sorted(by: projectIDLessThan)
        )
    }

    /// Grace-based orphan collection is restricted to app-owned managed roots.
    /// Live source/stem paths are always retained.
    public func sweepOrphanArtifacts(
        gracePeriod: TimeInterval = 3600,
        now: Date = Date()
    ) async throws -> LibraryOrphanSweepResult {
        try await withMutationGate {
            _ = try await recoverInterruptedOperationsUnlocked()
            let projects = try await metadata.listMaintenanceProjects()
            let referenced = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(in: projects)
            return try artifacts.sweepOrphans(
                referencedRelativePaths: referenced,
                gracePeriod: gracePeriod,
                now: now
            )
        }
    }

    private func withMutationGate<T: Sendable>(
        _ operation: () async throws -> T
    ) async throws -> T {
        await mutationGate.lock()
        do {
            let result = try await operation()
            await mutationGate.unlock()
            return result
        } catch {
            await mutationGate.unlock()
            throw error
        }
    }

    private func projectIDLessThan(_ lhs: ProjectID, _ rhs: ProjectID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}
#endif
