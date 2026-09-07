import Foundation

public struct Lane2ForegroundDeletePreparationPlan: Equatable, Sendable {
    public let candidate: Lane2TombstonedProjectCompactionCandidate
    public let sharedLiveArtifactPaths: [String]
    public let artifactRelativePathsToDelete: [String]

    public init(
        candidate: Lane2TombstonedProjectCompactionCandidate,
        sharedLiveArtifactPaths: [String],
        artifactRelativePathsToDelete: [String]
    ) {
        self.candidate = candidate
        self.sharedLiveArtifactPaths = sharedLiveArtifactPaths.sorted()
        self.artifactRelativePathsToDelete = artifactRelativePathsToDelete.sorted()
    }
}

public enum Lane2ForegroundDeletePreparationPolicy {
    public static func plan(
        candidate: Lane2TombstonedProjectCompactionCandidate,
        liveReferencedArtifactPathsExcludingTarget: Set<String>
    ) throws -> Lane2ForegroundDeletePreparationPlan {
        let deletion = try Lane2TombstonedMetadataCompactionPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPaths: liveReferencedArtifactPathsExcludingTarget
        )
        return Lane2ForegroundDeletePreparationPlan(
            candidate: candidate,
            sharedLiveArtifactPaths: deletion.retainedLiveArtifactPaths,
            artifactRelativePathsToDelete: deletion.artifactRelativePathsToDelete
        )
    }
}

public struct Lane2ForegroundDeleteReferenceDiagnostics: Hashable, Sendable {
    public let usedTargetedStoreQuery: Bool
    public let candidateArtifactPaths: Int
    public let sharedLiveArtifactPaths: Int
    public let logicalFetchCalls: Int

    public init(
        usedTargetedStoreQuery: Bool,
        candidateArtifactPaths: Int,
        sharedLiveArtifactPaths: Int,
        logicalFetchCalls: Int
    ) {
        self.usedTargetedStoreQuery = usedTargetedStoreQuery
        self.candidateArtifactPaths = candidateArtifactPaths
        self.sharedLiveArtifactPaths = sharedLiveArtifactPaths
        self.logicalFetchCalls = logicalFetchCalls
    }

    public static let empty = Self(
        usedTargetedStoreQuery: false,
        candidateArtifactPaths: 0,
        sharedLiveArtifactPaths: 0,
        logicalFetchCalls: 0
    )
}

public struct Lane2ForegroundDeleteReferenceSnapshot: Hashable, Sendable {
    public let liveReferencedArtifactPathsExcludingTarget: Set<String>
    public let diagnostics: Lane2ForegroundDeleteReferenceDiagnostics

    public init(
        liveReferencedArtifactPathsExcludingTarget: Set<String>,
        diagnostics: Lane2ForegroundDeleteReferenceDiagnostics
    ) {
        self.liveReferencedArtifactPathsExcludingTarget = liveReferencedArtifactPathsExcludingTarget
        self.diagnostics = diagnostics
    }
}

#if canImport(CoreData)
@preconcurrency import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public extension CoreDataProjectLibraryStore {
    /// Bounded foreground delete candidate. `loadProject` is a single-project read; unlike
    /// `listMaintenanceProjects` it never materializes unrelated live projects.
    func foregroundDeletionCandidate(
        projectID: ProjectID
    ) async throws -> Lane2TombstonedProjectCompactionCandidate? {
        guard let snapshot = try await loadProject(projectID: projectID) else { return nil }
        return Lane2TombstonedProjectCompactionCandidate(
            projectUUID: snapshot.projectID.rawValue,
            sourceAssetUUID: snapshot.source.id.rawValue,
            artifactRelativePaths: [snapshot.source.relativePath] + snapshot.stems.map(\.relativePath)
        )
    }
}

public extension Lane2CoreDataLiveArtifactReferenceResolver {
    /// Foreground-only reference lookup. The target project is excluded so PREPARED contains only
    /// paths that are not referenced by any *other* live project before the target is tombstoned.
    func resolveReferencesExcludingTarget(
        targetProjectUUID: UUID,
        candidateArtifactPaths: Set<String>
    ) async throws -> Lane2ForegroundDeleteReferenceSnapshot {
        let storeURL = storeURL
        let batchSize = batchSize
        return try await Task.detached {
            try Self.scanReferencesExcludingTarget(
                storeURL: storeURL,
                targetProjectUUID: targetProjectUUID,
                candidateArtifactPaths: candidateArtifactPaths,
                batchSize: batchSize
            )
        }.value
    }

    private static func scanReferencesExcludingTarget(
        storeURL: URL,
        targetProjectUUID: UUID,
        candidateArtifactPaths: Set<String>,
        batchSize: Int
    ) throws -> Lane2ForegroundDeleteReferenceSnapshot {
        let plan = try Lane2TargetedLiveReferenceQueryPolicy.plan(
            candidateArtifactPaths: candidateArtifactPaths,
            batchSize: batchSize
        )
        let model = Lane2AW27L2V1Model.make()
        try requireAW27CompatibleModel(model, storeURL: storeURL)
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

        var output: Lane2ForegroundDeleteReferenceSnapshot?
        var thrown: Error?
        context.performAndWait {
            do {
                var shared = Set<String>()
                var logicalFetchCalls = 0

                for paths in aw27Chunks(plan.sourceArtifactPaths, size: batchSize) {
                    logicalFetchCalls += 1
                    let assets = try aw27FetchDictionaries(
                        entity: "AssetRecord",
                        properties: ["assetUUID", "relativePath"],
                        predicate: aw27InPredicate(key: "relativePath", values: paths),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    var pathByAsset = [UUID: String]()
                    for row in assets {
                        let assetID = try aw27UUID(row["assetUUID"], key: "assetUUID")
                        let path = try aw27String(row["relativePath"], key: "relativePath")
                        guard paths.contains(path), pathByAsset[assetID] == nil else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("duplicate/escaped source candidate")
                        }
                        pathByAsset[assetID] = path
                    }
                    guard !pathByAsset.isEmpty else { continue }

                    logicalFetchCalls += 1
                    let liveRows = try aw27FetchDictionaries(
                        entity: "ProjectRecord",
                        properties: ["sourceAssetUUID"],
                        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "tombstoned == NO"),
                            NSPredicate(format: "projectUUID != %@", targetProjectUUID as NSUUID),
                            aw27InPredicate(
                                key: "sourceAssetUUID",
                                values: pathByAsset.keys.map { $0 as NSUUID }
                            )
                        ]),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    for row in liveRows {
                        let assetID = try aw27UUID(row["sourceAssetUUID"], key: "sourceAssetUUID")
                        guard let path = pathByAsset[assetID] else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("source reference escaped candidate")
                        }
                        shared.insert(path)
                    }
                }

                for paths in aw27Chunks(plan.stemArtifactPaths, size: batchSize) {
                    logicalFetchCalls += 1
                    let stemRows = try aw27FetchDictionaries(
                        entity: "StemRecord",
                        properties: ["projectUUID", "relativePath"],
                        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "projectUUID != %@", targetProjectUUID as NSUUID),
                            aw27InPredicate(key: "relativePath", values: paths)
                        ]),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    var pathsByProject = [UUID: Set<String>]()
                    for row in stemRows {
                        let projectID = try aw27UUID(row["projectUUID"], key: "projectUUID")
                        let path = try aw27String(row["relativePath"], key: "relativePath")
                        guard paths.contains(path) else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("stem reference escaped candidate")
                        }
                        pathsByProject[projectID, default: []].insert(path)
                    }
                    guard !pathsByProject.isEmpty else { continue }

                    logicalFetchCalls += 1
                    let liveRows = try aw27FetchDictionaries(
                        entity: "ProjectRecord",
                        properties: ["projectUUID"],
                        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "tombstoned == NO"),
                            aw27InPredicate(
                                key: "projectUUID",
                                values: pathsByProject.keys.map { $0 as NSUUID }
                            )
                        ]),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    for row in liveRows {
                        let projectID = try aw27UUID(row["projectUUID"], key: "projectUUID")
                        guard let paths = pathsByProject[projectID] else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("live stem project escaped candidate")
                        }
                        shared.formUnion(paths)
                    }
                }

                output = Lane2ForegroundDeleteReferenceSnapshot(
                    liveReferencedArtifactPathsExcludingTarget: shared,
                    diagnostics: Lane2ForegroundDeleteReferenceDiagnostics(
                        usedTargetedStoreQuery: true,
                        candidateArtifactPaths: plan.requestedArtifactPathCount,
                        sharedLiveArtifactPaths: shared.count,
                        logicalFetchCalls: logicalFetchCalls
                    )
                )
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
        guard let output else {
            throw Lane2TargetedLiveReferenceFailure.corruptValue("missing foreground delete reference result")
        }
        return output
    }

    private static func requireAW27CompatibleModel(
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

    private static func aw27FetchDictionaries(
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

    private static func aw27InPredicate(key: String, values: [Any]) -> NSPredicate {
        guard !values.isEmpty else { return NSPredicate(value: false) }
        return NSPredicate(format: "%K IN %@", argumentArray: [key, values])
    }

    private static func aw27UUID(_ value: Any?, key: String) throws -> UUID {
        if let value = value as? UUID { return value }
        if let value = value as? NSUUID { return value as UUID }
        throw Lane2TargetedLiveReferenceFailure.corruptValue(key)
    }

    private static func aw27String(_ value: Any?, key: String) throws -> String {
        guard let value = value as? String else {
            throw Lane2TargetedLiveReferenceFailure.corruptValue(key)
        }
        return value
    }

    private static func aw27Chunks<T>(_ values: [T], size: Int) -> [[T]] {
        guard !values.isEmpty else { return [] }
        let size = max(size, 1)
        return stride(from: 0, to: values.count, by: size).map { start in
            Array(values[start..<min(start + size, values.count)])
        }
    }
}

private enum Lane2AW27L2V1Model {
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
