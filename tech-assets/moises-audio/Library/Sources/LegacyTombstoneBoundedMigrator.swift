import Foundation

#if canImport(CoreData)
@preconcurrency import CoreData

public struct Lane2LegacyTombstoneBoundedMigrationReport: Hashable, Sendable {
    public let skippedBecauseComplete: Bool
    public let activatedBoundedMode: Bool
    public let selectedLegacyProjects: Int
    public let prioritizedDeletionJournals: Int
    public let hasMoreLegacyProjects: Bool
    public let ownershipRecordsPersisted: Int
    public let rootRowsMaterialized: Int
    public let projectsPerLaunch: Int

    public init(
        skippedBecauseComplete: Bool,
        activatedBoundedMode: Bool,
        selectedLegacyProjects: Int,
        prioritizedDeletionJournals: Int,
        hasMoreLegacyProjects: Bool,
        ownershipRecordsPersisted: Int,
        rootRowsMaterialized: Int,
        projectsPerLaunch: Int
    ) {
        self.skippedBecauseComplete = skippedBecauseComplete
        self.activatedBoundedMode = activatedBoundedMode
        self.selectedLegacyProjects = selectedLegacyProjects
        self.prioritizedDeletionJournals = prioritizedDeletionJournals
        self.hasMoreLegacyProjects = hasMoreLegacyProjects
        self.ownershipRecordsPersisted = ownershipRecordsPersisted
        self.rootRowsMaterialized = rootRowsMaterialized
        self.projectsPerLaunch = projectsPerLaunch
    }
}

public enum Lane2LegacyTombstoneBoundedMigrationFailure: Error, Equatable, Sendable {
    case incompatibleStoreModel
    case corruptValue(String)
}

/// AW24 bounded compatibility scanner. It deliberately sets the old AW22 completion marker after
/// writing a stronger `bounded-v2-active` marker. This suppresses the legacy unbounded fallback while
/// canonical AW24 open paths keep re-entering this scanner until the active marker is removed.
/// Each normal launch materializes at most N+1 journal-less tombstone roots and persists ownership for
/// at most N of them. Explicit pre-AW22 destructive journals are correctness-critical and are
/// prioritized even when they exceed the normal slice budget.
public enum Lane2LegacyTombstoneBoundedMigrator {
    public static func prepareNextSliceIfNeeded(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        projectsPerLaunch: Int = Lane2LegacyRecoverySliceBudget.defaultProjectsPerLaunch
    ) async throws -> Lane2LegacyTombstoneBoundedMigrationReport {
        let budget = Lane2LegacyRecoverySliceBudget(projectsPerLaunch: projectsPerLaunch)
        return try await Task.detached {
            try scan(
                metadataStoreURL: metadataStoreURL,
                artifactRootURL: artifactRootURL,
                budget: budget
            )
        }.value
    }

    private static func scan(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        budget: Lane2LegacyRecoverySliceBudget
    ) throws -> Lane2LegacyTombstoneBoundedMigrationReport {
        let index = Lane2DeletionOwnershipIndex(rootURL: artifactRootURL)
        let state = Lane2LegacyRecoverySliceState(rootURL: artifactRootURL)
        let lifecycle = LibraryArtifactLifecycle(rootURL: artifactRootURL)
        try index.ensureLayout()
        try state.ensureLayout()
        try lifecycle.ensureLayout()

        if !state.isActive, index.isLegacyScanComplete {
            return .init(
                skippedBecauseComplete: true,
                activatedBoundedMode: false,
                selectedLegacyProjects: 0,
                prioritizedDeletionJournals: 0,
                hasMoreLegacyProjects: false,
                ownershipRecordsPersisted: 0,
                rootRowsMaterialized: 0,
                projectsPerLaunch: budget.projectsPerLaunch
            )
        }

        let activated = !state.isActive
        if activated {
            try state.activate()
        }
        if !index.isLegacyScanComplete {
            try index.markLegacyScanComplete()
        }

        let model = Lane2AW24LegacyL2V1Model.make()
        try requireCompatibleModel(model, storeURL: metadataStoreURL)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: metadataStoreURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer {
            for store in coordinator.persistentStores { try? coordinator.remove(store) }
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.undoManager = nil

        let existingIndexedIDs = Set(try index.pendingRecords().map(\.projectUUID))
        let criticalJournalIDs = Set(
            try lifecycle.pendingDeletionJournals().compactMap { journal -> UUID? in
                guard journal.phase != .artifactsDeleted,
                      !existingIndexedIDs.contains(journal.projectUUID) else { return nil }
                return journal.projectUUID
            }
        )

        var output: Lane2LegacyTombstoneBoundedMigrationReport?
        var thrown: Error?
        context.performAndWait {
            do {
                let priorityRows = try fetchDictionaries(
                    entity: "ProjectRecord",
                    properties: ["projectUUID", "sourceAssetUUID"],
                    predicate: criticalJournalIDs.isEmpty
                        ? NSPredicate(value: false)
                        : NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "tombstoned == YES"),
                            inPredicate(key: "projectUUID", ids: criticalJournalIDs)
                        ]),
                    sort: [NSSortDescriptor(key: "projectUUID", ascending: true)],
                    context: context,
                    fetchLimit: 0,
                    fetchBatchSize: budget.projectsPerLaunch
                )

                let normalPredicate: NSPredicate
                if criticalJournalIDs.isEmpty {
                    normalPredicate = NSPredicate(format: "tombstoned == YES")
                } else {
                    normalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "tombstoned == YES"),
                        NSCompoundPredicate(notPredicateWithSubpredicate: inPredicate(
                            key: "projectUUID",
                            ids: criticalJournalIDs
                        ))
                    ])
                }
                let rootRows = try fetchDictionaries(
                    entity: "ProjectRecord",
                    properties: ["projectUUID", "sourceAssetUUID"],
                    predicate: normalPredicate,
                    sort: [NSSortDescriptor(key: "projectUUID", ascending: true)],
                    context: context,
                    fetchLimit: budget.projectsPerLaunch + 1,
                    fetchBatchSize: budget.projectsPerLaunch
                )
                let hasMore = budget.hasMore(availableWithSentinel: rootRows.count)
                let normalSelected = Array(rootRows.prefix(budget.projectsPerLaunch))
                let selectedRows = priorityRows + normalSelected

                let projectRows = try selectedRows.map { row in
                    Lane2LegacyTombstoneProjectRow(
                        projectUUID: try uuid(row["projectUUID"], key: "projectUUID"),
                        sourceAssetUUID: try uuid(row["sourceAssetUUID"], key: "sourceAssetUUID")
                    )
                }
                let projectIDs = Set(projectRows.map(\.projectUUID))
                let sourceAssetIDs = Set(projectRows.map(\.sourceAssetUUID))

                let assets = try fetchDictionaries(
                    entity: "AssetRecord",
                    properties: ["assetUUID", "relativePath"],
                    predicate: inPredicate(key: "assetUUID", ids: sourceAssetIDs),
                    sort: [NSSortDescriptor(key: "assetUUID", ascending: true)],
                    context: context,
                    fetchLimit: 0,
                    fetchBatchSize: budget.projectsPerLaunch
                ).map { row in
                    Lane2LegacyTombstoneAssetRow(
                        assetUUID: try uuid(row["assetUUID"], key: "assetUUID"),
                        relativePath: try string(row["relativePath"], key: "relativePath")
                    )
                }
                let stems = try fetchDictionaries(
                    entity: "StemRecord",
                    properties: ["projectUUID", "relativePath"],
                    predicate: inPredicate(key: "projectUUID", ids: projectIDs),
                    sort: [
                        NSSortDescriptor(key: "projectUUID", ascending: true),
                        NSSortDescriptor(key: "role", ascending: true)
                    ],
                    context: context,
                    fetchLimit: 0,
                    fetchBatchSize: budget.projectsPerLaunch
                ).map { row in
                    Lane2LegacyTombstoneStemRow(
                        projectUUID: try uuid(row["projectUUID"], key: "projectUUID"),
                        relativePath: try string(row["relativePath"], key: "relativePath")
                    )
                }

                let candidates = try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
                    projects: projectRows,
                    assets: assets,
                    stems: stems
                )
                for candidate in candidates {
                    try index.persist(
                        Lane2DeletionOwnershipRecord(
                            projectUUID: candidate.projectUUID,
                            sourceAssetUUID: candidate.sourceAssetUUID,
                            artifactRelativePaths: candidate.artifactRelativePaths
                        )
                    )
                }

                if !hasMore {
                    try state.finish()
                }

                output = .init(
                    skippedBecauseComplete: false,
                    activatedBoundedMode: activated,
                    selectedLegacyProjects: normalSelected.count,
                    prioritizedDeletionJournals: priorityRows.count,
                    hasMoreLegacyProjects: hasMore,
                    ownershipRecordsPersisted: candidates.count,
                    rootRowsMaterialized: rootRows.count,
                    projectsPerLaunch: budget.projectsPerLaunch
                )
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
        guard let output else {
            throw Lane2LegacyTombstoneBoundedMigrationFailure.corruptValue("missing bounded migration report")
        }
        return output
    }

    private static func requireCompatibleModel(_ model: NSManagedObjectModel, storeURL: URL) throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        guard let storedHashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data],
              storedHashes == model.entityVersionHashesByName else {
            throw Lane2LegacyTombstoneBoundedMigrationFailure.incompatibleStoreModel
        }
    }

    private static func fetchDictionaries(
        entity: String,
        properties: [String],
        predicate: NSPredicate,
        sort: [NSSortDescriptor],
        context: NSManagedObjectContext,
        fetchLimit: Int,
        fetchBatchSize: Int
    ) throws -> [[String: Any]] {
        let request = NSFetchRequest<NSDictionary>(entityName: entity)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = properties
        request.predicate = predicate
        request.sortDescriptors = sort
        request.fetchLimit = fetchLimit
        request.fetchBatchSize = fetchBatchSize
        return try context.fetch(request).map { $0 as? [String: Any] ?? [:] }
    }

    private static func inPredicate(key: String, ids: Set<UUID>) -> NSPredicate {
        guard !ids.isEmpty else { return NSPredicate(value: false) }
        return NSPredicate(format: "%K IN %@", argumentArray: [key, ids.map { $0 as NSUUID }])
    }

    private static func uuid(_ value: Any?, key: String) throws -> UUID {
        if let value = value as? UUID { return value }
        if let value = value as? NSUUID { return value as UUID }
        throw Lane2LegacyTombstoneBoundedMigrationFailure.corruptValue(key)
    }

    private static func string(_ value: Any?, key: String) throws -> String {
        guard let value = value as? String else {
            throw Lane2LegacyTombstoneBoundedMigrationFailure.corruptValue(key)
        }
        return value
    }
}

private enum Lane2AW24LegacyL2V1Model {
    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = Set([AnyHashable("L2-V1")])
        let project = entity("ProjectRecord", [
            attribute("projectUUID", .UUIDAttributeType), attribute("sourceAssetUUID", .UUIDAttributeType),
            attribute("createdAt", .dateAttributeType), attribute("updatedAt", .dateAttributeType),
            attribute("tombstoned", .booleanAttributeType, defaultValue: false)
        ], unique: ["projectUUID"])
        let asset = entity("AssetRecord", [
            attribute("assetUUID", .UUIDAttributeType), attribute("relativePath", .stringAttributeType),
            attribute("mediaKind", .stringAttributeType), attribute("durationSeconds", .doubleAttributeType, optional: true)
        ], unique: ["assetUUID"])
        let processing = entity("ProcessingRecord", [
            attribute("projectUUID", .UUIDAttributeType), attribute("jobUUID", .UUIDAttributeType),
            attribute("phase", .stringAttributeType), attribute("fractionComplete", .doubleAttributeType, optional: true),
            attribute("retryable", .booleanAttributeType, defaultValue: false),
            attribute("stableErrorCode", .stringAttributeType, optional: true), attribute("updatedAt", .dateAttributeType)
        ], unique: ["projectUUID"])
        let stem = entity("StemRecord", [
            attribute("stemUUID", .UUIDAttributeType), attribute("projectUUID", .UUIDAttributeType),
            attribute("role", .stringAttributeType), attribute("relativePath", .stringAttributeType),
            attribute("sampleRate", .doubleAttributeType), attribute("channels", .integer64AttributeType),
            attribute("frameCount", .integer64AttributeType), attribute("startTimeSeconds", .doubleAttributeType)
        ], unique: ["stemUUID"])
        let edit = entity("ProjectEditRecord", [
            attribute("projectUUID", .UUIDAttributeType), attribute("schemaVersion", .integer64AttributeType),
            attribute("tempoRatio", .doubleAttributeType), attribute("pitchSemitones", .doubleAttributeType),
            attribute("metronomeEnabled", .booleanAttributeType, defaultValue: false),
            attribute("countInClicks", .integer64AttributeType), attribute("loopStartSeconds", .doubleAttributeType, optional: true),
            attribute("loopEndSeconds", .doubleAttributeType, optional: true)
        ], unique: ["projectUUID"])
        let stemMix = entity("StemMixRecord", [
            attribute("projectUUID", .UUIDAttributeType), attribute("stemUUID", .UUIDAttributeType),
            attribute("gain", .doubleAttributeType), attribute("isMuted", .booleanAttributeType, defaultValue: false),
            attribute("isSoloed", .booleanAttributeType, defaultValue: false), attribute("position", .integer64AttributeType)
        ])
        let setlist = entity("SetlistRecord", [
            attribute("setlistUUID", .UUIDAttributeType), attribute("name", .stringAttributeType),
            attribute("createdAt", .dateAttributeType), attribute("updatedAt", .dateAttributeType)
        ], unique: ["setlistUUID"])
        let setlistEntry = entity("SetlistEntryRecord", [
            attribute("entryUUID", .UUIDAttributeType), attribute("setlistUUID", .UUIDAttributeType),
            attribute("projectUUID", .UUIDAttributeType), attribute("position", .integer64AttributeType)
        ], unique: ["entryUUID"])
        model.entities = [project, asset, processing, stem, edit, stemMix, setlist, setlistEntry]
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
        if !unique.isEmpty { entity.uniquenessConstraints = [unique.map { $0 as Any }] }
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
