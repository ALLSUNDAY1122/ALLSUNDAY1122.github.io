import Foundation

#if canImport(CoreData)
@preconcurrency import CoreData

public struct Lane2LegacyTombstoneBulkMigrationReport: Hashable, Sendable {
    public let skippedBecauseComplete: Bool
    public let projectCount: Int
    public let batchCount: Int
    public let ownershipRecordsPersisted: Int
    public let logicalFetchUpperBound: Int
    public let legacyNPlusOneUpperBound: Int

    public init(
        skippedBecauseComplete: Bool,
        projectCount: Int,
        batchCount: Int,
        ownershipRecordsPersisted: Int,
        logicalFetchUpperBound: Int,
        legacyNPlusOneUpperBound: Int
    ) {
        self.skippedBecauseComplete = skippedBecauseComplete
        self.projectCount = projectCount
        self.batchCount = batchCount
        self.ownershipRecordsPersisted = ownershipRecordsPersisted
        self.logicalFetchUpperBound = logicalFetchUpperBound
        self.legacyNPlusOneUpperBound = legacyNPlusOneUpperBound
    }
}

public enum Lane2LegacyTombstoneBulkMigrationFailure: Error, Equatable, Sendable {
    case incompatibleStoreModel
    case corruptValue(String)
}

/// One-time pre-AW22 compatibility scanner. It runs before CrashSafe recovery, projects only
/// tombstoned Project/Asset/Stem fields, persists AW22 ownership records, and writes the existing
/// legacy-complete marker only after every tombstone has durable ownership evidence.
public enum Lane2LegacyTombstoneBulkMigrator {
    public static func prepareIfNeeded(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        enumerationBatchSize: Int = LibraryEnumerationPolicy.defaultBatchSize
    ) async throws -> Lane2LegacyTombstoneBulkMigrationReport {
        let policy = LibraryEnumerationPolicy(batchSize: enumerationBatchSize)
        return try await Task.detached {
            try scan(
                metadataStoreURL: metadataStoreURL,
                artifactRootURL: artifactRootURL,
                enumerationPolicy: policy
            )
        }.value
    }

    private static func scan(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        enumerationPolicy: LibraryEnumerationPolicy
    ) throws -> Lane2LegacyTombstoneBulkMigrationReport {
        let index = Lane2DeletionOwnershipIndex(rootURL: artifactRootURL)
        try index.ensureLayout()
        if index.isLegacyScanComplete {
            return Lane2LegacyTombstoneBulkMigrationReport(
                skippedBecauseComplete: true,
                projectCount: 0,
                batchCount: 0,
                ownershipRecordsPersisted: 0,
                logicalFetchUpperBound: 0,
                legacyNPlusOneUpperBound: 0
            )
        }

        let model = Lane2LegacyTombstoneL2V1Model.make()
        try requireCompatibleModel(model, storeURL: metadataStoreURL)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: metadataStoreURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer {
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.undoManager = nil

        var output: Lane2LegacyTombstoneBulkMigrationReport?
        var thrown: Error?
        context.performAndWait {
            do {
                let projects = try fetchDictionaries(
                    entity: "ProjectRecord",
                    properties: ["projectUUID", "sourceAssetUUID"],
                    predicate: NSPredicate(format: "tombstoned == YES"),
                    sort: [NSSortDescriptor(key: "projectUUID", ascending: true)],
                    context: context,
                    fetchBatchSize: enumerationPolicy.batchSize
                )
                let metrics = Lane2LegacyTombstoneProjectionPolicy.metrics(
                    projectCount: projects.count,
                    enumerationPolicy: enumerationPolicy
                )
                var persisted = 0

                for range in enumerationPolicy.ranges(forCount: projects.count) {
                    let batch = Array(projects[range])
                    let projectRows = try batch.map { row in
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
                        fetchBatchSize: enumerationPolicy.batchSize
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
                        fetchBatchSize: enumerationPolicy.batchSize
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
                        persisted += 1
                    }
                }

                try index.markLegacyScanComplete()
                output = Lane2LegacyTombstoneBulkMigrationReport(
                    skippedBecauseComplete: false,
                    projectCount: projects.count,
                    batchCount: metrics.batchCount,
                    ownershipRecordsPersisted: persisted,
                    logicalFetchUpperBound: metrics.totalLogicalFetchCalls,
                    legacyNPlusOneUpperBound: Lane2LegacyTombstoneProjectionPolicy
                        .legacyNPlusOneFetchUpperBound(projectCount: projects.count)
                )
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
        guard let output else {
            throw Lane2LegacyTombstoneBulkMigrationFailure.corruptValue("missing migration report")
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
            throw Lane2LegacyTombstoneBulkMigrationFailure.incompatibleStoreModel
        }
    }

    private static func fetchDictionaries(
        entity: String,
        properties: [String],
        predicate: NSPredicate,
        sort: [NSSortDescriptor],
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [[String: Any]] {
        let request = NSFetchRequest<NSDictionary>(entityName: entity)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = properties
        request.predicate = predicate
        request.sortDescriptors = sort
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
        throw Lane2LegacyTombstoneBulkMigrationFailure.corruptValue(key)
    }

    private static func string(_ value: Any?, key: String) throws -> String {
        guard let value = value as? String else {
            throw Lane2LegacyTombstoneBulkMigrationFailure.corruptValue(key)
        }
        return value
    }
}

private enum Lane2LegacyTombstoneL2V1Model {
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
