import Foundation

#if canImport(CoreData)
@preconcurrency import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

/// Serialized Core Data adapter for the frozen epoch-2 ProjectLibraryPersisting contract.
/// Core Data objects never cross this boundary; only stable IDs, scalars and relative paths are persisted.
public final class CoreDataProjectLibraryStore: @unchecked Sendable, ProjectLibraryPersisting, LibraryMaintenanceProjectProviding {
    public struct Configuration: Sendable {
        public let storeURL: URL?
        public let inMemory: Bool
        public let enumerationPolicy: LibraryEnumerationPolicy

        public init(
            storeURL: URL? = nil,
            inMemory: Bool = false,
            enumerationBatchSize: Int = LibraryEnumerationPolicy.defaultBatchSize
        ) {
            self.storeURL = storeURL
            self.inMemory = inMemory
            self.enumerationPolicy = LibraryEnumerationPolicy(batchSize: enumerationBatchSize)
        }
    }

    private let coordinator: NSPersistentStoreCoordinator
    private let writerContext: NSManagedObjectContext
    private let enumerationPolicy: LibraryEnumerationPolicy

    public init(configuration: Configuration) throws {
        let model = LibraryManagedObjectModel.make()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        if configuration.inMemory {
            try coordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: options
            )
        } else {
            guard let storeURL = configuration.storeURL else {
                throw LibraryPersistenceFailure.corruptRecord("missing Core Data store URL")
            }
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil

        self.coordinator = coordinator
        self.writerContext = context
        self.enumerationPolicy = configuration.enumerationPolicy
    }

    public static func defaultStoreURL(appSupportDirectory: URL) -> URL {
        appSupportDirectory
            .appendingPathComponent("MoisesLibrary", isDirectory: true)
            .appendingPathComponent("Library.sqlite", isDirectory: false)
    }

    public func createProject(source: LocalAudioAsset) async throws -> ProjectID {
        try LibrarySnapshotPolicy.validate(source: source)
        let projectID = ProjectID()
        let now = Date()

        return try await perform { context in
            if let existingAsset = try StoreFetch.asset(id: source.id.rawValue, context: context) {
                let path = try StoreValue.string(existingAsset, "relativePath")
                let kind = try StoreValue.string(existingAsset, "mediaKind")
                guard path == source.relativePath, kind == source.mediaKind.rawValue else {
                    throw LibraryPersistenceFailure.assetIdentityConflict(source.id)
                }
            } else {
                let asset = StoreFetch.insert(entity: "AssetRecord", context: context)
                asset.setValue(source.id.rawValue, forKey: "assetUUID")
                asset.setValue(source.relativePath, forKey: "relativePath")
                asset.setValue(source.mediaKind.rawValue, forKey: "mediaKind")
                asset.setValue(source.durationSeconds, forKey: "durationSeconds")
            }

            let project = StoreFetch.insert(entity: "ProjectRecord", context: context)
            project.setValue(projectID.rawValue, forKey: "projectUUID")
            project.setValue(source.id.rawValue, forKey: "sourceAssetUUID")
            project.setValue(now, forKey: "createdAt")
            project.setValue(now, forKey: "updatedAt")
            project.setValue(false, forKey: "tombstoned")
            try StoreFetch.save(context)
            return projectID
        }
    }

    public func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {
        try await perform { context in
            let project = try StoreFetch.requireLiveProject(id: projectID.rawValue, context: context)
            let record = try StoreFetch.processing(projectID: projectID.rawValue, context: context)
                ?? StoreFetch.insert(entity: "ProcessingRecord", context: context)
            record.setValue(projectID.rawValue, forKey: "projectUUID")
            record.setValue(snapshot.jobID.rawValue, forKey: "jobUUID")
            record.setValue(snapshot.phase.rawValue, forKey: "phase")
            record.setValue(snapshot.fractionComplete, forKey: "fractionComplete")
            record.setValue(snapshot.retryable, forKey: "retryable")
            record.setValue(snapshot.stableErrorCode, forKey: "stableErrorCode")
            record.setValue(Date(), forKey: "updatedAt")
            project.setValue(Date(), forKey: "updatedAt")
            try StoreFetch.save(context)
        }
    }

    public func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {
        try LibrarySnapshotPolicy.validate(stems: stems, projectID: projectID)
        try await perform { context in
            let project = try StoreFetch.requireLiveProject(id: projectID.rawValue, context: context)
            for old in try StoreFetch.stems(projectID: projectID.rawValue, context: context) {
                context.delete(old)
            }
            for stem in stems {
                let record = StoreFetch.insert(entity: "StemRecord", context: context)
                record.setValue(stem.id.rawValue, forKey: "stemUUID")
                record.setValue(projectID.rawValue, forKey: "projectUUID")
                record.setValue(stem.role.rawValue, forKey: "role")
                record.setValue(stem.relativePath, forKey: "relativePath")
                record.setValue(stem.sampleRate, forKey: "sampleRate")
                record.setValue(Int64(stem.channels), forKey: "channels")
                record.setValue(stem.frameCount, forKey: "frameCount")
                record.setValue(stem.startTimeSeconds, forKey: "startTimeSeconds")
            }
            project.setValue(Date(), forKey: "updatedAt")
            try StoreFetch.save(context)
        }
    }

    public func listProjects() async throws -> [PersistedProjectSnapshot] {
        let policy = enumerationPolicy
        return try await perform { context in
            let records = try StoreFetch.liveProjects(context: context, fetchBatchSize: policy.batchSize)
            return try StoreMapper.projectSnapshots(records: records, context: context, policy: policy)
        }
    }

    /// Lane-local lightweight projection used by delete/orphan/reconciliation maintenance.
    /// It intentionally excludes processing, edit and mix materialization.
    public func listMaintenanceProjects() async throws -> [LibraryMaintenanceProject] {
        let policy = enumerationPolicy
        return try await perform { context in
            let records = try StoreFetch.liveProjects(context: context, fetchBatchSize: policy.batchSize)
            return try StoreMapper.maintenanceProjects(records: records, context: context, policy: policy)
        }
    }

    public func listLiveProjectIDs() async throws -> Set<ProjectID> {
        let policy = enumerationPolicy
        return try await perform { context in
            let records = try StoreFetch.liveProjects(context: context, fetchBatchSize: policy.batchSize)
            return try Set(records.map { ProjectID(rawValue: try StoreValue.uuid($0, "projectUUID")) })
        }
    }

    public func containsLiveProject(projectID: ProjectID) async throws -> Bool {
        try await perform { context in
            guard let project = try StoreFetch.project(id: projectID.rawValue, context: context) else {
                return false
            }
            return !StoreValue.bool(project, "tombstoned")
        }
    }

    public func loadProject(projectID: ProjectID) async throws -> PersistedProjectSnapshot? {
        try await perform { context in
            guard let project = try StoreFetch.project(id: projectID.rawValue, context: context),
                  !StoreValue.bool(project, "tombstoned") else {
                return nil
            }
            return try StoreMapper.projectSnapshot(record: project, context: context)
        }
    }

    public func saveUserEdits(projectID: ProjectID, edits: ProjectUserEdits) async throws {
        try LibrarySnapshotPolicy.validate(edits: edits)
        try await perform { context in
            let project = try StoreFetch.requireLiveProject(id: projectID.rawValue, context: context)
            let record = try StoreFetch.edit(projectID: projectID.rawValue, context: context)
                ?? StoreFetch.insert(entity: "ProjectEditRecord", context: context)
            record.setValue(projectID.rawValue, forKey: "projectUUID")
            record.setValue(Int64(edits.schemaVersion), forKey: "schemaVersion")
            record.setValue(edits.tempoRatio, forKey: "tempoRatio")
            record.setValue(edits.pitchSemitones, forKey: "pitchSemitones")
            record.setValue(edits.metronomeEnabled, forKey: "metronomeEnabled")
            record.setValue(Int64(edits.countInClicks), forKey: "countInClicks")
            record.setValue(edits.loopStartSeconds, forKey: "loopStartSeconds")
            record.setValue(edits.loopEndSeconds, forKey: "loopEndSeconds")

            for old in try StoreFetch.stemMix(projectID: projectID.rawValue, context: context) {
                context.delete(old)
            }
            for (index, mix) in edits.stemMix.enumerated() {
                let mixRecord = StoreFetch.insert(entity: "StemMixRecord", context: context)
                mixRecord.setValue(projectID.rawValue, forKey: "projectUUID")
                mixRecord.setValue(mix.stemID.rawValue, forKey: "stemUUID")
                mixRecord.setValue(mix.gain, forKey: "gain")
                mixRecord.setValue(mix.isMuted, forKey: "isMuted")
                mixRecord.setValue(mix.isSoloed, forKey: "isSoloed")
                mixRecord.setValue(Int64(index), forKey: "position")
            }
            project.setValue(Date(), forKey: "updatedAt")
            try StoreFetch.save(context)
        }
    }

    public func createSetlist(name: String) async throws -> SetlistID {
        let normalizedName = try LibraryNamePolicy.normalizedSetlistName(name)
        let setlistID = SetlistID()
        let now = Date()
        return try await perform { context in
            let record = StoreFetch.insert(entity: "SetlistRecord", context: context)
            record.setValue(setlistID.rawValue, forKey: "setlistUUID")
            record.setValue(normalizedName, forKey: "name")
            record.setValue(now, forKey: "createdAt")
            record.setValue(now, forKey: "updatedAt")
            try StoreFetch.save(context)
            return setlistID
        }
    }

    public func renameSetlist(setlistID: SetlistID, name: String) async throws {
        let normalizedName = try LibraryNamePolicy.normalizedSetlistName(name)
        try await perform { context in
            guard let record = try StoreFetch.setlist(id: setlistID.rawValue, context: context) else {
                throw LibraryPersistenceFailure.setlistNotFound(setlistID)
            }
            record.setValue(normalizedName, forKey: "name")
            record.setValue(Date(), forKey: "updatedAt")
            try StoreFetch.save(context)
        }
    }

    public func listSetlists() async throws -> [SetlistSnapshot] {
        let policy = enumerationPolicy
        return try await perform { context in
            let records = try StoreFetch.setlists(context: context, fetchBatchSize: policy.batchSize)
            return try StoreMapper.setlistSnapshots(records: records, context: context, policy: policy)
        }
    }

    public func replaceSetlistEntries(setlistID: SetlistID, orderedProjectIDs: [ProjectID]) async throws {
        try await perform { context in
            guard let setlist = try StoreFetch.setlist(id: setlistID.rawValue, context: context) else {
                throw LibraryPersistenceFailure.setlistNotFound(setlistID)
            }
            for projectID in Set(orderedProjectIDs) {
                _ = try StoreFetch.requireLiveProject(id: projectID.rawValue, context: context)
            }
            for old in try StoreFetch.setlistEntries(setlistID: setlistID.rawValue, context: context) {
                context.delete(old)
            }
            for (position, projectID) in orderedProjectIDs.enumerated() {
                let entry = StoreFetch.insert(entity: "SetlistEntryRecord", context: context)
                entry.setValue(UUID(), forKey: "entryUUID")
                entry.setValue(setlistID.rawValue, forKey: "setlistUUID")
                entry.setValue(projectID.rawValue, forKey: "projectUUID")
                entry.setValue(Int64(position), forKey: "position")
            }
            setlist.setValue(Date(), forKey: "updatedAt")
            try StoreFetch.save(context)
        }
    }

    public func deleteSetlist(setlistID: SetlistID) async throws {
        try await perform { context in
            guard let record = try StoreFetch.setlist(id: setlistID.rawValue, context: context) else {
                return
            }
            for entry in try StoreFetch.setlistEntries(setlistID: setlistID.rawValue, context: context) {
                context.delete(entry)
            }
            context.delete(record)
            try StoreFetch.save(context)
        }
    }

    /// L2-M01 provides the contract-level tombstone behavior. L2-M02 owns artifact cleanup,
    /// orphan sweep and interrupted-delete recovery around this tombstone.
    public func deleteProject(projectID: ProjectID) async throws {
        try await perform { context in
            guard let project = try StoreFetch.project(id: projectID.rawValue, context: context) else {
                return
            }
            if StoreValue.bool(project, "tombstoned") { return }
            project.setValue(true, forKey: "tombstoned")
            project.setValue(Date(), forKey: "updatedAt")

            let affectedEntries = try StoreFetch.setlistEntries(projectID: projectID.rawValue, context: context)
            let setlistIDs = try Set(affectedEntries.map { try StoreValue.uuid($0, "setlistUUID") })
            affectedEntries.forEach(context.delete)
            for setlistID in setlistIDs {
                let survivors = try StoreFetch.setlistEntries(setlistID: setlistID, context: context)
                for (index, entry) in survivors.enumerated() {
                    entry.setValue(Int64(index), forKey: "position")
                }
            }
            try StoreFetch.save(context)
        }
    }

    /// Low-level startup repair for rows hidden from the public setlist snapshot because their
    /// `setlistUUID` no longer has a SetlistRecord. This intentionally does not repair ordering or
    /// project membership; AW18 runs those higher-level semantics after this pass.
    @discardableResult
    public func reconcileOrphanSetlistEntries() async throws -> Lane2SetlistOrphanEntryRecoveryReport {
        let policy = enumerationPolicy
        return try await perform { context in
            let setlistRecords = try StoreFetch.setlists(
                context: context,
                fetchBatchSize: policy.batchSize
            )
            let liveSetlistUUIDs = try Set(
                setlistRecords.map { try StoreValue.uuid($0, "setlistUUID") }
            )
            guard liveSetlistUUIDs.count == setlistRecords.count else {
                throw LibraryPersistenceFailure.corruptRecord("duplicate setlist identity")
            }

            func fetchEntryRecords() throws -> [NSManagedObject] {
                let request = NSFetchRequest<NSManagedObject>(entityName: "SetlistEntryRecord")
                request.fetchBatchSize = policy.batchSize
                request.returnsObjectsAsFaults = true
                return try context.fetch(request)
            }

            let entryRecords = try fetchEntryRecords()
            let ownership = try entryRecords.map {
                Lane2SetlistEntryOwnership(
                    entryUUID: try StoreValue.uuid($0, "entryUUID"),
                    setlistUUID: try StoreValue.uuid($0, "setlistUUID")
                )
            }
            let plan = try Lane2SetlistOrphanEntryPolicy.plan(
                entries: ownership,
                liveSetlistUUIDs: liveSetlistUUIDs
            )

            if plan.requiresRepair {
                let orphanIDs = Set(plan.orphanEntryUUIDs)
                for (record, identity) in zip(entryRecords, ownership)
                where orphanIDs.contains(identity.entryUUID) {
                    context.delete(record)
                }
                try StoreFetch.save(context)
            }

            let remaining = try fetchEntryRecords().map {
                Lane2SetlistEntryOwnership(
                    entryUUID: try StoreValue.uuid($0, "entryUUID"),
                    setlistUUID: try StoreValue.uuid($0, "setlistUUID")
                )
            }
            try Lane2SetlistOrphanEntryPolicy.requireConverged(
                entries: remaining,
                liveSetlistUUIDs: liveSetlistUUIDs
            )

            return Lane2SetlistOrphanEntryRecoveryReport(
                scannedEntries: plan.scannedEntries,
                liveSetlists: plan.liveSetlists,
                removedOrphanEntries: plan.orphanEntryUUIDs.count
            )
        }
    }

    /// Returns only physically retained tombstones. Live projects are intentionally excluded.
    /// The projection includes source/stem paths so crash recovery can authorize artifact deletion
    /// without materializing processing/edit/mix payloads.
    public func listTombstonedProjectCompactionCandidates() async throws
        -> [Lane2TombstonedProjectCompactionCandidate]
    {
        let policy = enumerationPolicy
        return try await perform { context in
            let records = try StoreFetch.tombstonedProjects(
                context: context,
                fetchBatchSize: policy.batchSize
            )
            var candidates: [Lane2TombstonedProjectCompactionCandidate] = []
            candidates.reserveCapacity(records.count)

            for record in records {
                let projectUUID = try StoreValue.uuid(record, "projectUUID")
                let sourceAssetUUID = try StoreValue.uuid(record, "sourceAssetUUID")
                guard let asset = try StoreFetch.asset(id: sourceAssetUUID, context: context) else {
                    throw Lane2TombstonedMetadataCompactionFailure.missingSourceAsset(sourceAssetUUID)
                }
                let sourcePath = try StoreValue.string(asset, "relativePath")
                let stemPaths = try StoreFetch.stems(projectID: projectUUID, context: context).map {
                    try StoreValue.string($0, "relativePath")
                }
                candidates.append(
                    Lane2TombstonedProjectCompactionCandidate(
                        projectUUID: projectUUID,
                        sourceAssetUUID: sourceAssetUUID,
                        artifactRelativePaths: [sourcePath] + stemPaths
                    )
                )
            }

            try Lane2TombstonedMetadataCompactionPolicy.requireUniqueProjects(candidates)
            return candidates.sorted { $0.projectUUID.uuidString < $1.projectUUID.uuidString }
        }
    }

    /// Physically removes one tombstoned project and project-owned child metadata in one Core Data
    /// save. AssetRecord is removed only when no other ProjectRecord — live or tombstoned — still
    /// references the same source asset. A live project is never compacted.
    @discardableResult
    public func compactTombstonedProject(
        projectID: ProjectID
    ) async throws -> Lane2TombstonedMetadataCompactionResult {
        try await perform { context in
            guard let project = try StoreFetch.project(id: projectID.rawValue, context: context) else {
                return .alreadyAbsent(projectUUID: projectID.rawValue)
            }
            guard StoreValue.bool(project, "tombstoned") else {
                throw Lane2TombstonedMetadataCompactionFailure.liveProjectCannotCompact(projectID.rawValue)
            }

            let sourceAssetUUID = try StoreValue.uuid(project, "sourceAssetUUID")
            guard let sourceAsset = try StoreFetch.asset(id: sourceAssetUUID, context: context) else {
                throw Lane2TombstonedMetadataCompactionFailure.missingSourceAsset(sourceAssetUUID)
            }

            let processing = try StoreFetch.processingRecords(
                projectID: projectID.rawValue,
                context: context
            )
            let stems = try StoreFetch.stems(projectID: projectID.rawValue, context: context)
            let edits = try StoreFetch.editRecords(
                projectID: projectID.rawValue,
                context: context
            )
            let stemMix = try StoreFetch.stemMix(projectID: projectID.rawValue, context: context)
            let setlistEntries = try StoreFetch.setlistEntries(
                projectID: projectID.rawValue,
                context: context
            )

            let remainingProjectAssetRefs = try Set(
                StoreFetch.projectsReferencingAsset(
                    sourceAssetUUID,
                    excludingProjectID: projectID.rawValue,
                    context: context
                ).map { try StoreValue.uuid($0, "sourceAssetUUID") }
            )
            let removeSourceAsset = Lane2TombstonedMetadataCompactionPolicy.shouldRemoveSourceAsset(
                sourceAssetUUID: sourceAssetUUID,
                remainingProjectSourceAssetUUIDs: remainingProjectAssetRefs
            )

            processing.forEach(context.delete)
            stems.forEach(context.delete)
            edits.forEach(context.delete)
            stemMix.forEach(context.delete)
            setlistEntries.forEach(context.delete)
            context.delete(project)
            if removeSourceAsset {
                context.delete(sourceAsset)
            }
            try StoreFetch.save(context)

            guard try StoreFetch.project(id: projectID.rawValue, context: context) == nil,
                  try StoreFetch.processingRecords(projectID: projectID.rawValue, context: context).isEmpty,
                  try StoreFetch.stems(projectID: projectID.rawValue, context: context).isEmpty,
                  try StoreFetch.editRecords(projectID: projectID.rawValue, context: context).isEmpty,
                  try StoreFetch.stemMix(projectID: projectID.rawValue, context: context).isEmpty,
                  try StoreFetch.setlistEntries(projectID: projectID.rawValue, context: context).isEmpty else {
                throw LibraryPersistenceFailure.corruptRecord("tombstoned metadata compaction did not converge")
            }

            if removeSourceAsset {
                guard try StoreFetch.asset(id: sourceAssetUUID, context: context) == nil else {
                    throw LibraryPersistenceFailure.corruptRecord("source asset survived final reference compaction")
                }
            } else {
                guard try StoreFetch.asset(id: sourceAssetUUID, context: context) != nil else {
                    throw LibraryPersistenceFailure.corruptRecord("shared source asset was removed")
                }
            }

            return Lane2TombstonedMetadataCompactionResult(
                projectUUID: projectID.rawValue,
                projectRecordRemoved: true,
                processingRecordsRemoved: processing.count,
                stemRecordsRemoved: stems.count,
                editRecordsRemoved: edits.count,
                stemMixRecordsRemoved: stemMix.count,
                setlistEntryRecordsRemoved: setlistEntries.count,
                sourceAssetRecordRemoved: removeSourceAsset,
                sourceAssetRecordRetained: !removeSourceAsset
            )
        }
    }

    public func recoveryPlan(projectID: ProjectID) async throws -> ProcessingRecoveryPlan {
        try await perform { context in
            _ = try StoreFetch.requireLiveProject(id: projectID.rawValue, context: context)
            guard let record = try StoreFetch.processing(projectID: projectID.rawValue, context: context) else {
                return .none
            }
            return LibraryRecoveryPolicy.plan(for: try StoreMapper.processing(record: record))
        }
    }

    private func perform<T: Sendable>(
        _ operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = writerContext
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    continuation.resume(returning: try operation(context))
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private enum StoreMapper {
    private struct ProjectBatchMaterialization {
        let assetsByID: [UUID: NSManagedObject]
        let processingByProjectID: [UUID: NSManagedObject]
        let stemsByProjectID: [UUID: [NSManagedObject]]
        let editsByProjectID: [UUID: NSManagedObject]
        let mixByProjectID: [UUID: [NSManagedObject]]
    }

    static func projectSnapshots(
        records: [NSManagedObject],
        context: NSManagedObjectContext,
        policy: LibraryEnumerationPolicy
    ) throws -> [PersistedProjectSnapshot] {
        guard !records.isEmpty else { return [] }
        var snapshots: [PersistedProjectSnapshot] = []
        snapshots.reserveCapacity(records.count)

        for range in policy.ranges(forCount: records.count) {
            let batch = Array(records[range])
            let projectIDs = try Set(batch.map { try StoreValue.uuid($0, "projectUUID") })
            let assetIDs = try Set(batch.map { try StoreValue.uuid($0, "sourceAssetUUID") })
            let materialized = try ProjectBatchMaterialization(
                assetsByID: uniqueByUUID(
                    StoreFetch.assets(ids: assetIDs, context: context, fetchBatchSize: policy.batchSize),
                    key: "assetUUID"
                ),
                processingByProjectID: uniqueByUUID(
                    StoreFetch.processing(projectIDs: projectIDs, context: context, fetchBatchSize: policy.batchSize),
                    key: "projectUUID"
                ),
                stemsByProjectID: groupByUUID(
                    StoreFetch.stems(projectIDs: projectIDs, context: context, fetchBatchSize: policy.batchSize),
                    key: "projectUUID"
                ),
                editsByProjectID: uniqueByUUID(
                    StoreFetch.edits(projectIDs: projectIDs, context: context, fetchBatchSize: policy.batchSize),
                    key: "projectUUID"
                ),
                mixByProjectID: groupByUUID(
                    StoreFetch.stemMix(projectIDs: projectIDs, context: context, fetchBatchSize: policy.batchSize),
                    key: "projectUUID"
                )
            )
            for record in batch {
                snapshots.append(try projectSnapshot(record: record, materialized: materialized))
            }
        }
        return snapshots
    }

    static func maintenanceProjects(
        records: [NSManagedObject],
        context: NSManagedObjectContext,
        policy: LibraryEnumerationPolicy
    ) throws -> [LibraryMaintenanceProject] {
        guard !records.isEmpty else { return [] }
        var result: [LibraryMaintenanceProject] = []
        result.reserveCapacity(records.count)

        for range in policy.ranges(forCount: records.count) {
            let batch = Array(records[range])
            let projectIDs = try Set(batch.map { try StoreValue.uuid($0, "projectUUID") })
            let assetIDs = try Set(batch.map { try StoreValue.uuid($0, "sourceAssetUUID") })
            let assets = try uniqueByUUID(
                StoreFetch.assets(ids: assetIDs, context: context, fetchBatchSize: policy.batchSize),
                key: "assetUUID"
            )
            let stems = try groupByUUID(
                StoreFetch.stems(projectIDs: projectIDs, context: context, fetchBatchSize: policy.batchSize),
                key: "projectUUID"
            )

            for record in batch {
                let projectID = ProjectID(rawValue: try StoreValue.uuid(record, "projectUUID"))
                let assetID = AssetID(rawValue: try StoreValue.uuid(record, "sourceAssetUUID"))
                guard let asset = assets[assetID.rawValue] else {
                    throw LibraryPersistenceFailure.corruptRecord("missing source asset")
                }
                let stemPaths = try (stems[projectID.rawValue] ?? []).map {
                    try StoreValue.string($0, "relativePath")
                }
                result.append(
                    try LibraryMaintenanceProject(
                        projectID: projectID,
                        sourceAssetID: assetID,
                        sourceRelativePath: try StoreValue.string(asset, "relativePath"),
                        stemRelativePaths: stemPaths
                    )
                )
            }
        }
        return try LibraryMaintenanceProjectionPolicy.validateUniqueProjects(result)
    }

    static func projectSnapshot(record: NSManagedObject, context: NSManagedObjectContext) throws -> PersistedProjectSnapshot {
        let projectID = ProjectID(rawValue: try StoreValue.uuid(record, "projectUUID"))
        let assetUUID = try StoreValue.uuid(record, "sourceAssetUUID")
        guard let asset = try StoreFetch.asset(id: assetUUID, context: context) else {
            throw LibraryPersistenceFailure.corruptRecord("missing source asset")
        }
        let kindRaw = try StoreValue.string(asset, "mediaKind")
        guard let mediaKind = ImportedMediaKind(rawValue: kindRaw) else {
            throw LibraryPersistenceFailure.corruptRecord("invalid media kind")
        }
        let source = LocalAudioAsset(
            id: AssetID(rawValue: assetUUID),
            relativePath: try StoreValue.string(asset, "relativePath"),
            mediaKind: mediaKind,
            durationSeconds: StoreValue.optionalDouble(asset, "durationSeconds")
        )
        try LibrarySnapshotPolicy.validate(source: source)

        let processing = try StoreFetch.processing(projectID: projectID.rawValue, context: context)
            .map { try processing(record: $0) }
        let stems = try StoreFetch.stems(projectID: projectID.rawValue, context: context)
            .map { try stem(record: $0, projectID: projectID) }
        try LibrarySnapshotPolicy.validate(stems: stems, projectID: projectID)
        let edits = try StoreFetch.edit(projectID: projectID.rawValue, context: context)
            .map { try edits(record: $0, projectID: projectID, context: context) }
        return PersistedProjectSnapshot(
            projectID: projectID,
            source: source,
            processing: processing,
            stems: stems,
            edits: edits
        )
    }

    private static func projectSnapshot(
        record: NSManagedObject,
        materialized: ProjectBatchMaterialization
    ) throws -> PersistedProjectSnapshot {
        let projectID = ProjectID(rawValue: try StoreValue.uuid(record, "projectUUID"))
        let assetUUID = try StoreValue.uuid(record, "sourceAssetUUID")
        guard let asset = materialized.assetsByID[assetUUID] else {
            throw LibraryPersistenceFailure.corruptRecord("missing source asset")
        }
        let kindRaw = try StoreValue.string(asset, "mediaKind")
        guard let mediaKind = ImportedMediaKind(rawValue: kindRaw) else {
            throw LibraryPersistenceFailure.corruptRecord("invalid media kind")
        }
        let source = LocalAudioAsset(
            id: AssetID(rawValue: assetUUID),
            relativePath: try StoreValue.string(asset, "relativePath"),
            mediaKind: mediaKind,
            durationSeconds: StoreValue.optionalDouble(asset, "durationSeconds")
        )
        try LibrarySnapshotPolicy.validate(source: source)

        let processingSnapshot = try materialized.processingByProjectID[projectID.rawValue]
            .map { try processing(record: $0) }
        let stems = try (materialized.stemsByProjectID[projectID.rawValue] ?? [])
            .map { try stem(record: $0, projectID: projectID) }
        try LibrarySnapshotPolicy.validate(stems: stems, projectID: projectID)
        let editsSnapshot = try materialized.editsByProjectID[projectID.rawValue].map {
            try edits(
                record: $0,
                projectID: projectID,
                mixRecords: materialized.mixByProjectID[projectID.rawValue] ?? []
            )
        }
        return PersistedProjectSnapshot(
            projectID: projectID,
            source: source,
            processing: processingSnapshot,
            stems: stems,
            edits: editsSnapshot
        )
    }

    static func setlistSnapshots(
        records: [NSManagedObject],
        context: NSManagedObjectContext,
        policy: LibraryEnumerationPolicy
    ) throws -> [SetlistSnapshot] {
        guard !records.isEmpty else { return [] }
        var snapshots: [SetlistSnapshot] = []
        snapshots.reserveCapacity(records.count)

        for range in policy.ranges(forCount: records.count) {
            let batch = Array(records[range])
            let ids = try Set(batch.map { try StoreValue.uuid($0, "setlistUUID") })
            let entryRecords = try StoreFetch.setlistEntries(
                setlistIDs: ids,
                context: context,
                fetchBatchSize: policy.batchSize
            )
            let grouped = try groupByUUID(entryRecords, key: "setlistUUID")
            for record in batch {
                let id = SetlistID(rawValue: try StoreValue.uuid(record, "setlistUUID"))
                let entries = try (grouped[id.rawValue] ?? []).map { try setlistEntry(record: $0) }
                snapshots.append(
                    SetlistSnapshot(
                        id: id,
                        name: try StoreValue.string(record, "name"),
                        entries: entries
                    )
                )
            }
        }
        return snapshots
    }

    static func processing(record: NSManagedObject) throws -> ProcessingSnapshot {
        guard let phase = ProcessingPhase(rawValue: try StoreValue.string(record, "phase")) else {
            throw LibraryPersistenceFailure.corruptRecord("invalid processing phase")
        }
        return ProcessingSnapshot(
            jobID: ProcessingJobID(rawValue: try StoreValue.uuid(record, "jobUUID")),
            phase: phase,
            fractionComplete: StoreValue.optionalDouble(record, "fractionComplete"),
            retryable: StoreValue.bool(record, "retryable"),
            stableErrorCode: record.value(forKey: "stableErrorCode") as? String
        )
    }

    static func edits(
        record: NSManagedObject,
        projectID: ProjectID,
        context: NSManagedObjectContext
    ) throws -> ProjectUserEdits {
        try edits(
            record: record,
            projectID: projectID,
            mixRecords: StoreFetch.stemMix(projectID: projectID.rawValue, context: context)
        )
    }

    private static func edits(
        record: NSManagedObject,
        projectID: ProjectID,
        mixRecords: [NSManagedObject]
    ) throws -> ProjectUserEdits {
        let mix = try mixRecords.map { mixRecord in
            StemMixEdit(
                stemID: StemID(rawValue: try StoreValue.uuid(mixRecord, "stemUUID")),
                gain: try StoreValue.double(mixRecord, "gain"),
                isMuted: StoreValue.bool(mixRecord, "isMuted"),
                isSoloed: StoreValue.bool(mixRecord, "isSoloed")
            )
        }
        let edits = ProjectUserEdits(
            schemaVersion: Int(try StoreValue.int64(record, "schemaVersion")),
            tempoRatio: try StoreValue.double(record, "tempoRatio"),
            pitchSemitones: try StoreValue.double(record, "pitchSemitones"),
            metronomeEnabled: StoreValue.bool(record, "metronomeEnabled"),
            countInClicks: Int(try StoreValue.int64(record, "countInClicks")),
            loopStartSeconds: StoreValue.optionalDouble(record, "loopStartSeconds"),
            loopEndSeconds: StoreValue.optionalDouble(record, "loopEndSeconds"),
            stemMix: mix
        )
        try LibrarySnapshotPolicy.validate(edits: edits)
        return edits
    }

    private static func stem(record: NSManagedObject, projectID: ProjectID) throws -> StemArtifact {
        StemArtifact(
            id: StemID(rawValue: try StoreValue.uuid(record, "stemUUID")),
            projectID: projectID,
            role: StemRole(rawValue: try StoreValue.string(record, "role")),
            relativePath: try StoreValue.string(record, "relativePath"),
            sampleRate: try StoreValue.double(record, "sampleRate"),
            channels: Int(try StoreValue.int64(record, "channels")),
            frameCount: try StoreValue.int64(record, "frameCount"),
            startTimeSeconds: try StoreValue.double(record, "startTimeSeconds")
        )
    }

    private static func setlistEntry(record: NSManagedObject) throws -> SetlistEntry {
        SetlistEntry(
            id: SetlistEntryID(rawValue: try StoreValue.uuid(record, "entryUUID")),
            projectID: ProjectID(rawValue: try StoreValue.uuid(record, "projectUUID")),
            position: Int(try StoreValue.int64(record, "position"))
        )
    }

    private static func uniqueByUUID(
        _ records: [NSManagedObject],
        key: String
    ) throws -> [UUID: NSManagedObject] {
        var result: [UUID: NSManagedObject] = [:]
        result.reserveCapacity(records.count)
        for record in records {
            let id = try StoreValue.uuid(record, key)
            guard result[id] == nil else {
                throw LibraryPersistenceFailure.corruptRecord("duplicate \(key)")
            }
            result[id] = record
        }
        return result
    }

    private static func groupByUUID(
        _ records: [NSManagedObject],
        key: String
    ) throws -> [UUID: [NSManagedObject]] {
        var result: [UUID: [NSManagedObject]] = [:]
        for record in records {
            result[try StoreValue.uuid(record, key), default: []].append(record)
        }
        return result
    }
}

private enum StoreFetch {
    static func insert(entity: String, context: NSManagedObjectContext) -> NSManagedObject {
        NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    static func save(_ context: NSManagedObjectContext) throws {
        if context.hasChanges { try context.save() }
    }

    static func project(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(
            entity: "ProjectRecord",
            predicate: NSPredicate(format: "projectUUID == %@", id as NSUUID),
            context: context
        )
    }

    static func requireLiveProject(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let project = try project(id: id, context: context),
              !StoreValue.bool(project, "tombstoned") else {
            throw LibraryPersistenceFailure.projectNotFound(ProjectID(rawValue: id))
        }
        return project
    }

    static func tombstonedProjects(
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ProjectRecord")
        request.predicate = NSPredicate(format: "tombstoned == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: true),
            NSSortDescriptor(key: "projectUUID", ascending: true)
        ]
        request.fetchBatchSize = fetchBatchSize
        request.returnsObjectsAsFaults = true
        return try context.fetch(request)
    }

    static func projectsReferencingAsset(
        _ assetUUID: UUID,
        excludingProjectID projectUUID: UUID,
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try many(
            entity: "ProjectRecord",
            predicate: NSPredicate(
                format: "sourceAssetUUID == %@ AND projectUUID != %@",
                assetUUID as NSUUID,
                projectUUID as NSUUID
            ),
            sort: [],
            context: context
        )
    }

    static func liveProjects(
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ProjectRecord")
        request.predicate = NSPredicate(format: "tombstoned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchBatchSize = fetchBatchSize
        request.returnsObjectsAsFaults = true
        return try context.fetch(request)
    }

    static func setlists(
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "SetlistRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchBatchSize = fetchBatchSize
        request.returnsObjectsAsFaults = true
        return try context.fetch(request)
    }

    static func asset(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(
            entity: "AssetRecord",
            predicate: NSPredicate(format: "assetUUID == %@", id as NSUUID),
            context: context
        )
    }

    static func assets(
        ids: Set<UUID>,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        try manyForIDs(
            entity: "AssetRecord",
            key: "assetUUID",
            ids: ids,
            sort: [],
            context: context,
            fetchBatchSize: fetchBatchSize
        )
    }

    static func processing(projectID: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(
            entity: "ProcessingRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            context: context
        )
    }

    static func processingRecords(
        projectID: UUID,
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try many(
            entity: "ProcessingRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            sort: [],
            context: context
        )
    }

    static func processing(
        projectIDs: Set<UUID>,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        try manyForIDs(
            entity: "ProcessingRecord",
            key: "projectUUID",
            ids: projectIDs,
            sort: [],
            context: context,
            fetchBatchSize: fetchBatchSize
        )
    }

    static func edit(projectID: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(
            entity: "ProjectEditRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            context: context
        )
    }

    static func editRecords(
        projectID: UUID,
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try many(
            entity: "ProjectEditRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            sort: [],
            context: context
        )
    }

    static func edits(
        projectIDs: Set<UUID>,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        try manyForIDs(
            entity: "ProjectEditRecord",
            key: "projectUUID",
            ids: projectIDs,
            sort: [],
            context: context,
            fetchBatchSize: fetchBatchSize
        )
    }

    static func setlist(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(
            entity: "SetlistRecord",
            predicate: NSPredicate(format: "setlistUUID == %@", id as NSUUID),
            context: context
        )
    }

    static func stems(projectID: UUID, context: NSManagedObjectContext) throws -> [NSManagedObject] {
        try many(
            entity: "StemRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            sort: [NSSortDescriptor(key: "role", ascending: true)],
            context: context
        )
    }

    static func stems(
        projectIDs: Set<UUID>,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        try manyForIDs(
            entity: "StemRecord",
            key: "projectUUID",
            ids: projectIDs,
            sort: [NSSortDescriptor(key: "role", ascending: true)],
            context: context,
            fetchBatchSize: fetchBatchSize
        )
    }

    static func stemMix(projectID: UUID, context: NSManagedObjectContext) throws -> [NSManagedObject] {
        try many(
            entity: "StemMixRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            sort: [NSSortDescriptor(key: "position", ascending: true)],
            context: context
        )
    }

    static func stemMix(
        projectIDs: Set<UUID>,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        try manyForIDs(
            entity: "StemMixRecord",
            key: "projectUUID",
            ids: projectIDs,
            sort: [NSSortDescriptor(key: "position", ascending: true)],
            context: context,
            fetchBatchSize: fetchBatchSize
        )
    }

    static func setlistEntries(
        setlistID: UUID,
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try many(
            entity: "SetlistEntryRecord",
            predicate: NSPredicate(format: "setlistUUID == %@", setlistID as NSUUID),
            sort: [NSSortDescriptor(key: "position", ascending: true)],
            context: context
        )
    }

    static func setlistEntries(
        setlistIDs: Set<UUID>,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        try manyForIDs(
            entity: "SetlistEntryRecord",
            key: "setlistUUID",
            ids: setlistIDs,
            sort: [NSSortDescriptor(key: "position", ascending: true)],
            context: context,
            fetchBatchSize: fetchBatchSize
        )
    }

    static func setlistEntries(
        projectID: UUID,
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try many(
            entity: "SetlistEntryRecord",
            predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID),
            sort: [],
            context: context
        )
    }

    private static func one(
        entity: String,
        predicate: NSPredicate,
        context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func many(
        entity: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor],
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.sortDescriptors = sort
        return try context.fetch(request)
    }

    private static func manyForIDs(
        entity: String,
        key: String,
        ids: Set<UUID>,
        sort: [NSSortDescriptor],
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [NSManagedObject] {
        guard !ids.isEmpty else { return [] }
        let bridgedIDs = ids.map { $0 as NSUUID }
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "%K IN %@", argumentArray: [key, bridgedIDs])
        request.sortDescriptors = sort
        request.fetchBatchSize = fetchBatchSize
        request.returnsObjectsAsFaults = true
        return try context.fetch(request)
    }
}

private enum StoreValue {
    static func uuid(_ object: NSManagedObject, _ key: String) throws -> UUID {
        guard let value = object.value(forKey: key) as? UUID else {
            throw LibraryPersistenceFailure.corruptRecord(key)
        }
        return value
    }

    static func string(_ object: NSManagedObject, _ key: String) throws -> String {
        guard let value = object.value(forKey: key) as? String else {
            throw LibraryPersistenceFailure.corruptRecord(key)
        }
        return value
    }

    static func double(_ object: NSManagedObject, _ key: String) throws -> Double {
        guard let value = object.value(forKey: key) as? NSNumber else {
            throw LibraryPersistenceFailure.corruptRecord(key)
        }
        return value.doubleValue
    }

    static func optionalDouble(_ object: NSManagedObject, _ key: String) -> Double? {
        (object.value(forKey: key) as? NSNumber)?.doubleValue
    }

    static func int64(_ object: NSManagedObject, _ key: String) throws -> Int64 {
        guard let value = object.value(forKey: key) as? NSNumber else {
            throw LibraryPersistenceFailure.corruptRecord(key)
        }
        return value.int64Value
    }

    static func bool(_ object: NSManagedObject, _ key: String) -> Bool {
        (object.value(forKey: key) as? NSNumber)?.boolValue ?? false
    }
}

private enum LibraryManagedObjectModel {
    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = Set([AnyHashable("L2-V1")])

        let project = entity("ProjectRecord", [
            attribute("projectUUID", .UUIDAttributeType),
            attribute("sourceAssetUUID", .UUIDAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType),
            attribute("tombstoned", .booleanAttributeType, defaultValue: false)
        ], unique: ["projectUUID"])

        let asset = entity("AssetRecord", [
            attribute("assetUUID", .UUIDAttributeType),
            attribute("relativePath", .stringAttributeType),
            attribute("mediaKind", .stringAttributeType),
            attribute("durationSeconds", .doubleAttributeType, optional: true)
        ], unique: ["assetUUID"])

        let processing = entity("ProcessingRecord", [
            attribute("projectUUID", .UUIDAttributeType),
            attribute("jobUUID", .UUIDAttributeType),
            attribute("phase", .stringAttributeType),
            attribute("fractionComplete", .doubleAttributeType, optional: true),
            attribute("retryable", .booleanAttributeType, defaultValue: false),
            attribute("stableErrorCode", .stringAttributeType, optional: true),
            attribute("updatedAt", .dateAttributeType)
        ], unique: ["projectUUID"])

        let stem = entity("StemRecord", [
            attribute("stemUUID", .UUIDAttributeType),
            attribute("projectUUID", .UUIDAttributeType),
            attribute("role", .stringAttributeType),
            attribute("relativePath", .stringAttributeType),
            attribute("sampleRate", .doubleAttributeType),
            attribute("channels", .integer64AttributeType),
            attribute("frameCount", .integer64AttributeType),
            attribute("startTimeSeconds", .doubleAttributeType)
        ], unique: ["stemUUID"])

        let edit = entity("ProjectEditRecord", [
            attribute("projectUUID", .UUIDAttributeType),
            attribute("schemaVersion", .integer64AttributeType),
            attribute("tempoRatio", .doubleAttributeType),
            attribute("pitchSemitones", .doubleAttributeType),
            attribute("metronomeEnabled", .booleanAttributeType, defaultValue: false),
            attribute("countInClicks", .integer64AttributeType),
            attribute("loopStartSeconds", .doubleAttributeType, optional: true),
            attribute("loopEndSeconds", .doubleAttributeType, optional: true)
        ], unique: ["projectUUID"])

        let stemMix = entity("StemMixRecord", [
            attribute("projectUUID", .UUIDAttributeType),
            attribute("stemUUID", .UUIDAttributeType),
            attribute("gain", .doubleAttributeType),
            attribute("isMuted", .booleanAttributeType, defaultValue: false),
            attribute("isSoloed", .booleanAttributeType, defaultValue: false),
            attribute("position", .integer64AttributeType)
        ])

        let setlist = entity("SetlistRecord", [
            attribute("setlistUUID", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ], unique: ["setlistUUID"])

        let setlistEntry = entity("SetlistEntryRecord", [
            attribute("entryUUID", .UUIDAttributeType),
            attribute("setlistUUID", .UUIDAttributeType),
            attribute("projectUUID", .UUIDAttributeType),
            attribute("position", .integer64AttributeType)
        ], unique: ["entryUUID"])

        model.entities = [
            project,
            asset,
            processing,
            stem,
            edit,
            stemMix,
            setlist,
            setlistEntry
        ]
        return model
    }

    private static func entity(
        _ name: String,
        _ attributes: [NSAttributeDescription],
        unique: [String] = []
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = attributes
        if !unique.isEmpty {
            entity.uniquenessConstraints = [unique.map { $0 as Any }]
        }
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
#endif
