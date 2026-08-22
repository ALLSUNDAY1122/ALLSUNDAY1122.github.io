import Foundation

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public struct LibraryRecoveryReport: Hashable, Sendable {
    public let discardedPrepared: [ProjectID]
    public let completedCommitted: [ProjectID]
    public let promotedInterruptedTombstones: [ProjectID]

    public init(discardedPrepared: [ProjectID], completedCommitted: [ProjectID], promotedInterruptedTombstones: [ProjectID]) {
        self.discardedPrepared = discardedPrepared
        self.completedCommitted = completedCommitted
        self.promotedInterruptedTombstones = promotedInterruptedTombstones
    }
}

/// Production facade for the L2-M01 Core Data adapter.
/// It adds file/database ordering guarantees without changing frozen Shared contracts.
public final class CrashSafeProjectLibraryStore: @unchecked Sendable, ProjectLibraryPersisting {
    private let metadata: CoreDataProjectLibraryStore
    private let artifacts: LibraryArtifactLifecycle

    public init(metadata: CoreDataProjectLibraryStore, artifactRootURL: URL) throws {
        self.metadata = metadata
        self.artifacts = LibraryArtifactLifecycle(rootURL: artifactRootURL)
        try artifacts.ensureLayout()
    }

    /// Preferred construction path: open metadata then reconcile any delete journal left by interruption.
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
        try artifacts.requireReady(relativePath: source.relativePath)
        return try await metadata.createProject(source: source)
    }

    public func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {
        try await metadata.recordProcessing(projectID: projectID, snapshot: snapshot)
    }

    public func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {
        for stem in stems {
            try artifacts.requireReady(relativePath: stem.relativePath)
        }
        try await metadata.recordStems(projectID: projectID, stems: stems)
    }

    public func listProjects() async throws -> [PersistedProjectSnapshot] {
        try await metadata.listProjects()
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

    public func replaceSetlistEntries(setlistID: SetlistID, orderedProjectIDs: [ProjectID]) async throws {
        try await metadata.replaceSetlistEntries(setlistID: setlistID, orderedProjectIDs: orderedProjectIDs)
    }

    public func deleteSetlist(setlistID: SetlistID) async throws {
        try await metadata.deleteSetlist(setlistID: setlistID)
    }

    /// Sequence:
    /// 1) durable PREPARED journal (non-destructive),
    /// 2) metadata tombstone transaction,
    /// 3) mark journal COMMITTED,
    /// 4) idempotent file deletion.
    /// A crash in every gap converges safely during recoverInterruptedOperations().
    public func deleteProject(projectID: ProjectID) async throws {
        guard let snapshot = try await metadata.loadProject(projectID: projectID) else {
            try await reconcileDeletion(projectID: projectID)
            return
        }

        let relativePaths = [snapshot.source.relativePath] + snapshot.stems.map(\.relativePath)
        try artifacts.persistPreparedDeletion(projectUUID: projectID.rawValue, relativePaths: relativePaths)
        try await metadata.deleteProject(projectID: projectID)
        try artifacts.markDeletionCommitted(projectUUID: projectID.rawValue)
        try artifacts.executeCommittedDeletion(projectUUID: projectID.rawValue)
    }

    public func recoveryPlan(projectID: ProjectID) async throws -> ProcessingRecoveryPlan {
        try await metadata.recoveryPlan(projectID: projectID)
    }

    /// Reconciles every journal against live metadata after relaunch.
    /// PREPARED + live project => deletion never committed; discard intent and retain files.
    /// PREPARED + hidden project => crash occurred after tombstone; promote to COMMITTED and finish cleanup.
    /// COMMITTED => finish idempotent cleanup.
    @discardableResult
    public func recoverInterruptedOperations() async throws -> LibraryRecoveryReport {
        var discarded: [ProjectID] = []
        var completed: [ProjectID] = []
        var promoted: [ProjectID] = []

        for journal in try artifacts.pendingDeletionJournals() {
            let projectID = ProjectID(rawValue: journal.projectUUID)
            switch journal.phase {
            case .prepared:
                if try await metadata.loadProject(projectID: projectID) != nil {
                    try artifacts.discardPreparedDeletion(projectUUID: journal.projectUUID)
                    discarded.append(projectID)
                } else {
                    try artifacts.markDeletionCommitted(projectUUID: journal.projectUUID)
                    try artifacts.executeCommittedDeletion(projectUUID: journal.projectUUID)
                    promoted.append(projectID)
                }
            case .committed:
                try artifacts.executeCommittedDeletion(projectUUID: journal.projectUUID)
                completed.append(projectID)
            }
        }

        return LibraryRecoveryReport(
            discardedPrepared: discarded,
            completedCommitted: completed,
            promotedInterruptedTombstones: promoted
        )
    }

    /// Grace-based orphan collection is restricted to app-owned managed roots.
    /// Live source/stem paths are always retained.
    public func sweepOrphanArtifacts(
        gracePeriod: TimeInterval = 3600,
        now: Date = Date()
    ) async throws -> LibraryOrphanSweepResult {
        _ = try await recoverInterruptedOperations()
        let snapshots = try await metadata.listProjects()
        var referenced = Set<String>()
        for snapshot in snapshots {
            referenced.insert(snapshot.source.relativePath)
            for stem in snapshot.stems { referenced.insert(stem.relativePath) }
        }
        return try artifacts.sweepOrphans(
            referencedRelativePaths: referenced,
            gracePeriod: gracePeriod,
            now: now
        )
    }

    private func reconcileDeletion(projectID: ProjectID) async throws {
        guard let journal = try artifacts.pendingDeletionJournals().first(where: { $0.projectUUID == projectID.rawValue }) else {
            return
        }
        switch journal.phase {
        case .prepared:
            if try await metadata.loadProject(projectID: projectID) != nil {
                try artifacts.discardPreparedDeletion(projectUUID: projectID.rawValue)
            } else {
                try artifacts.markDeletionCommitted(projectUUID: projectID.rawValue)
                try artifacts.executeCommittedDeletion(projectUUID: projectID.rawValue)
            }
        case .committed:
            try artifacts.executeCommittedDeletion(projectUUID: projectID.rawValue)
        }
    }
}
#endif
