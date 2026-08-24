import Foundation

#if canImport(CoreData)
@preconcurrency import CoreData

public extension Lane2CoreDataLiveArtifactReferenceResolver {
    /// Production foreground candidate reader. It intentionally reads only ProjectRecord,
    /// source AssetRecord and StemRecord for one live project; corrupt processing/edit/mix
    /// payloads cannot prevent the user from initiating deletion.
    func resolveForegroundDeletionCandidate(
        projectUUID: UUID
    ) async throws -> Lane2TombstonedProjectCompactionCandidate? {
        let storeURL = storeURL
        let batchSize = batchSize
        return try await Task.detached {
            try Self.scanForegroundDeletionCandidate(
                storeURL: storeURL,
                projectUUID: projectUUID,
                batchSize: batchSize
            )
        }.value
    }

    private static func scanForegroundDeletionCandidate(
        storeURL: URL,
        projectUUID: UUID,
        batchSize: Int
    ) throws -> Lane2TombstonedProjectCompactionCandidate? {
        let model = Lane2AW27CandidateL2V1Model.make()
        try requireCandidateModel(model, storeURL: storeURL)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        defer {
            for store in coordinator.persistentStores { try? coordinator.remove(store) }
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.undoManager = nil

        var output: Lane2TombstonedProjectCompactionCandidate?
        var thrown: Error?
        context.performAndWait {
            do {
                let projectRows = try candidateFetch(
                    entity: "ProjectRecord",
                    properties: ["projectUUID", "sourceAssetUUID"],
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "tombstoned == NO"),
                        NSPredicate(format: "projectUUID == %@", projectUUID as NSUUID)
                    ]),
                    context: context,
                    fetchBatchSize: 1
                )
                guard let projectRow = projectRows.first else { return }
                guard projectRows.count == 1 else {
                    throw Lane2TargetedLiveReferenceFailure.corruptValue("duplicate foreground project identity")
                }
                let storedProjectUUID = try candidateUUID(projectRow["projectUUID"], key: "projectUUID")
                guard storedProjectUUID == projectUUID else {
                    throw Lane2TargetedLiveReferenceFailure.corruptValue("foreground project escaped predicate")
                }
                let sourceAssetUUID = try candidateUUID(projectRow["sourceAssetUUID"], key: "sourceAssetUUID")

                let assetRows = try candidateFetch(
                    entity: "AssetRecord",
                    properties: ["assetUUID", "relativePath"],
                    predicate: NSPredicate(format: "assetUUID == %@", sourceAssetUUID as NSUUID),
                    context: context,
                    fetchBatchSize: 1
                )
                guard assetRows.count == 1 else {
                    throw Lane2TargetedLiveReferenceFailure.corruptValue("missing/duplicate foreground source asset")
                }
                let storedAssetUUID = try candidateUUID(assetRows[0]["assetUUID"], key: "assetUUID")
                guard storedAssetUUID == sourceAssetUUID else {
                    throw Lane2TargetedLiveReferenceFailure.corruptValue("foreground source asset escaped predicate")
                }
                let sourcePath = try candidateString(assetRows[0]["relativePath"], key: "relativePath")

                let stemRows = try candidateFetch(
                    entity: "StemRecord",
                    properties: ["projectUUID", "relativePath"],
                    predicate: NSPredicate(format: "projectUUID == %@", projectUUID as NSUUID),
                    context: context,
                    fetchBatchSize: batchSize
                )
                let stemPaths = try stemRows.map { row -> String in
                    guard try candidateUUID(row["projectUUID"], key: "projectUUID") == projectUUID else {
                        throw Lane2TargetedLiveReferenceFailure.corruptValue("foreground stem escaped predicate")
                    }
                    return try candidateString(row["relativePath"], key: "relativePath")
                }

                let candidate = Lane2TombstonedProjectCompactionCandidate(
                    projectUUID: projectUUID,
                    sourceAssetUUID: sourceAssetUUID,
                    artifactRelativePaths: [sourcePath] + stemPaths
                )
                _ = try Lane2TargetedLiveReferenceQueryPolicy.plan(
                    candidateArtifactPaths: Set(candidate.artifactRelativePaths),
                    batchSize: batchSize
                )
                output = candidate
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
        return output
    }

    private static func requireCandidateModel(
        _ model: NSManagedObjectModel,
        storeURL: URL
    ) throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        guard let storedHashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data],
              storedHashes == model.entityVersionHashesByName else {
            throw Lane2TargetedLiveReferenceFailure.incompatibleStoreModel
        }
    }

    private static func candidateFetch(
        entity: String,
        properties: [String],
        predicate: NSPredicate,
        context: NSManagedObjectContext,
        fetchBatchSize: Int
    ) throws -> [[String: Any]] {
        let request = NSFetchRequest<NSDictionary>(entityName: entity)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = properties
        request.predicate = predicate
        request.fetchBatchSize = fetchBatchSize
        return try context.fetch(request).map { $0 as? [String: Any] ?? [:] }
    }

    private static func candidateUUID(_ value: Any?, key: String) throws -> UUID {
        if let value = value as? UUID { return value }
        if let value = value as? NSUUID { return value as UUID }
        throw Lane2TargetedLiveReferenceFailure.corruptValue(key)
    }

    private static func candidateString(_ value: Any?, key: String) throws -> String {
        guard let value = value as? String else {
            throw Lane2TargetedLiveReferenceFailure.corruptValue(key)
        }
        return value
    }
}

private enum Lane2AW27CandidateL2V1Model {
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
