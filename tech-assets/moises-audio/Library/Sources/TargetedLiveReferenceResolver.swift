import Foundation

public struct Lane2TargetedLiveReferenceQueryPlan: Equatable, Sendable {
    public let sourceArtifactPaths: [String]
    public let stemArtifactPaths: [String]
    public let batchSize: Int

    public init(sourceArtifactPaths: [String], stemArtifactPaths: [String], batchSize: Int) {
        self.sourceArtifactPaths = sourceArtifactPaths.sorted()
        self.stemArtifactPaths = stemArtifactPaths.sorted()
        self.batchSize = max(batchSize, 1)
    }

    public var requestedArtifactPathCount: Int {
        sourceArtifactPaths.count + stemArtifactPaths.count
    }

    public var sourceBatchCount: Int {
        batchCount(sourceArtifactPaths.count)
    }

    public var stemBatchCount: Int {
        batchCount(stemArtifactPaths.count)
    }

    private func batchCount(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (count + batchSize - 1) / batchSize
    }
}

public struct Lane2TargetedLiveReferenceDiagnostics: Hashable, Sendable {
    public let usedTargetedStoreQuery: Bool
    public let requestedProjectIDs: Int
    public let requestedArtifactPaths: Int
    public let sourceArtifactPaths: Int
    public let stemArtifactPaths: Int
    public let liveProjectIDsMatched: Int
    public let liveArtifactPathsMatched: Int
    public let logicalFetchCalls: Int

    public init(
        usedTargetedStoreQuery: Bool,
        requestedProjectIDs: Int,
        requestedArtifactPaths: Int,
        sourceArtifactPaths: Int,
        stemArtifactPaths: Int,
        liveProjectIDsMatched: Int,
        liveArtifactPathsMatched: Int,
        logicalFetchCalls: Int
    ) {
        self.usedTargetedStoreQuery = usedTargetedStoreQuery
        self.requestedProjectIDs = requestedProjectIDs
        self.requestedArtifactPaths = requestedArtifactPaths
        self.sourceArtifactPaths = sourceArtifactPaths
        self.stemArtifactPaths = stemArtifactPaths
        self.liveProjectIDsMatched = liveProjectIDsMatched
        self.liveArtifactPathsMatched = liveArtifactPathsMatched
        self.logicalFetchCalls = logicalFetchCalls
    }

    public static let empty = Self(
        usedTargetedStoreQuery: false,
        requestedProjectIDs: 0,
        requestedArtifactPaths: 0,
        sourceArtifactPaths: 0,
        stemArtifactPaths: 0,
        liveProjectIDsMatched: 0,
        liveArtifactPathsMatched: 0,
        logicalFetchCalls: 0
    )

    public func merged(with other: Self) -> Self {
        Self(
            usedTargetedStoreQuery: usedTargetedStoreQuery || other.usedTargetedStoreQuery,
            requestedProjectIDs: requestedProjectIDs + other.requestedProjectIDs,
            requestedArtifactPaths: requestedArtifactPaths + other.requestedArtifactPaths,
            sourceArtifactPaths: sourceArtifactPaths + other.sourceArtifactPaths,
            stemArtifactPaths: stemArtifactPaths + other.stemArtifactPaths,
            liveProjectIDsMatched: liveProjectIDsMatched + other.liveProjectIDsMatched,
            liveArtifactPathsMatched: liveArtifactPathsMatched + other.liveArtifactPathsMatched,
            logicalFetchCalls: logicalFetchCalls + other.logicalFetchCalls
        )
    }
}

public struct Lane2TargetedLiveReferenceSnapshot: Hashable, Sendable {
    public let liveProjectUUIDs: Set<UUID>
    public let liveReferencedArtifactPaths: Set<String>
    public let diagnostics: Lane2TargetedLiveReferenceDiagnostics

    public init(
        liveProjectUUIDs: Set<UUID>,
        liveReferencedArtifactPaths: Set<String>,
        diagnostics: Lane2TargetedLiveReferenceDiagnostics
    ) {
        self.liveProjectUUIDs = liveProjectUUIDs
        self.liveReferencedArtifactPaths = liveReferencedArtifactPaths
        self.diagnostics = diagnostics
    }
}

public enum Lane2TargetedLiveReferenceFailure: Error, Equatable, Sendable {
    case unsafeArtifactPath(String)
    case incompatibleStoreModel
    case corruptValue(String)
}

public enum Lane2TargetedLiveReferenceQueryPolicy {
    public static let defaultBatchSize = 128

    public static func plan(
        candidateArtifactPaths: Set<String>,
        batchSize: Int = defaultBatchSize
    ) throws -> Lane2TargetedLiveReferenceQueryPlan {
        var sources = Set<String>()
        var stems = Set<String>()
        for path in candidateArtifactPaths {
            let validated = try validate(path)
            if validated.hasPrefix("Imports/") {
                sources.insert(validated)
            } else {
                stems.insert(validated)
            }
        }
        return Lane2TargetedLiveReferenceQueryPlan(
            sourceArtifactPaths: Array(sources),
            stemArtifactPaths: Array(stems),
            batchSize: max(batchSize, 1)
        )
    }

    private static func validate(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard normalized == relativePath,
              !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2TargetedLiveReferenceFailure.unsafeArtifactPath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
              parts[0] == "Imports" || parts[0] == "Stems" else {
            throw Lane2TargetedLiveReferenceFailure.unsafeArtifactPath(relativePath)
        }
        return parts.joined(separator: "/")
    }
}

public protocol Lane2LiveArtifactReferenceResolving: Sendable {
    func resolve(
        targetProjectUUIDs: Set<UUID>,
        candidateArtifactPaths: Set<String>
    ) async throws -> Lane2TargetedLiveReferenceSnapshot
}

#if canImport(CoreData)
@preconcurrency import CoreData

public struct Lane2CoreDataLiveArtifactReferenceResolver: Lane2LiveArtifactReferenceResolving, Sendable {
    public let storeURL: URL
    public let batchSize: Int

    public init(storeURL: URL, batchSize: Int = Lane2TargetedLiveReferenceQueryPolicy.defaultBatchSize) {
        self.storeURL = storeURL.standardizedFileURL
        self.batchSize = max(batchSize, 1)
    }

    public func resolve(
        targetProjectUUIDs: Set<UUID>,
        candidateArtifactPaths: Set<String>
    ) async throws -> Lane2TargetedLiveReferenceSnapshot {
        let storeURL = storeURL
        let batchSize = batchSize
        return try await Task.detached {
            try Self.scan(
                storeURL: storeURL,
                targetProjectUUIDs: targetProjectUUIDs,
                candidateArtifactPaths: candidateArtifactPaths,
                batchSize: batchSize
            )
        }.value
    }

    private static func scan(
        storeURL: URL,
        targetProjectUUIDs: Set<UUID>,
        candidateArtifactPaths: Set<String>,
        batchSize: Int
    ) throws -> Lane2TargetedLiveReferenceSnapshot {
        let plan = try Lane2TargetedLiveReferenceQueryPolicy.plan(
            candidateArtifactPaths: candidateArtifactPaths,
            batchSize: batchSize
        )
        let model = Lane2AW26L2V1Model.make()
        try requireCompatibleModel(model, storeURL: storeURL)
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

        var output: Lane2TargetedLiveReferenceSnapshot?
        var thrown: Error?
        context.performAndWait {
            do {
                var logicalFetchCalls = 0
                var liveProjectUUIDs = Set<UUID>()
                for ids in chunks(Array(targetProjectUUIDs).sorted(by: uuidLessThan), size: batchSize) {
                    logicalFetchCalls += 1
                    let rows = try fetchDictionaries(
                        entity: "ProjectRecord",
                        properties: ["projectUUID"],
                        predicate: liveAndInPredicate(key: "projectUUID", values: ids.map { $0 as NSUUID }),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    for row in rows {
                        liveProjectUUIDs.insert(try uuid(row["projectUUID"], key: "projectUUID"))
                    }
                }

                var livePaths = Set<String>()
                for paths in chunks(plan.sourceArtifactPaths, size: batchSize) {
                    logicalFetchCalls += 1
                    let assetRows = try fetchDictionaries(
                        entity: "AssetRecord",
                        properties: ["assetUUID", "relativePath"],
                        predicate: inPredicate(key: "relativePath", values: paths),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    var pathByAsset = [UUID: String]()
                    for row in assetRows {
                        let assetUUID = try uuid(row["assetUUID"], key: "assetUUID")
                        let path = try string(row["relativePath"], key: "relativePath")
                        guard paths.contains(path) else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("source path escaped predicate")
                        }
                        pathByAsset[assetUUID] = path
                    }
                    let assetIDs = Array(pathByAsset.keys)
                    guard !assetIDs.isEmpty else { continue }
                    logicalFetchCalls += 1
                    let liveRows = try fetchDictionaries(
                        entity: "ProjectRecord",
                        properties: ["sourceAssetUUID"],
                        predicate: liveAndInPredicate(
                            key: "sourceAssetUUID",
                            values: assetIDs.map { $0 as NSUUID }
                        ),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    for row in liveRows {
                        let assetUUID = try uuid(row["sourceAssetUUID"], key: "sourceAssetUUID")
                        guard let path = pathByAsset[assetUUID] else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("live source asset escaped predicate")
                        }
                        livePaths.insert(path)
                    }
                }

                for paths in chunks(plan.stemArtifactPaths, size: batchSize) {
                    logicalFetchCalls += 1
                    let stemRows = try fetchDictionaries(
                        entity: "StemRecord",
                        properties: ["projectUUID", "relativePath"],
                        predicate: inPredicate(key: "relativePath", values: paths),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    var pathsByProject = [UUID: Set<String>]()
                    for row in stemRows {
                        let projectUUID = try uuid(row["projectUUID"], key: "projectUUID")
                        let path = try string(row["relativePath"], key: "relativePath")
                        guard paths.contains(path) else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("stem path escaped predicate")
                        }
                        pathsByProject[projectUUID, default: []].insert(path)
                    }
                    let projectIDs = Array(pathsByProject.keys)
                    guard !projectIDs.isEmpty else { continue }
                    logicalFetchCalls += 1
                    let liveRows = try fetchDictionaries(
                        entity: "ProjectRecord",
                        properties: ["projectUUID"],
                        predicate: liveAndInPredicate(
                            key: "projectUUID",
                            values: projectIDs.map { $0 as NSUUID }
                        ),
                        context: context,
                        fetchBatchSize: batchSize
                    )
                    for row in liveRows {
                        let projectUUID = try uuid(row["projectUUID"], key: "projectUUID")
                        guard let paths = pathsByProject[projectUUID] else {
                            throw Lane2TargetedLiveReferenceFailure.corruptValue("live stem project escaped predicate")
                        }
                        livePaths.formUnion(paths)
                    }
                }

                output = Lane2TargetedLiveReferenceSnapshot(
                    liveProjectUUIDs: liveProjectUUIDs,
                    liveReferencedArtifactPaths: livePaths,
                    diagnostics: Lane2TargetedLiveReferenceDiagnostics(
                        usedTargetedStoreQuery: true,
                        requestedProjectIDs: targetProjectUUIDs.count,
                        requestedArtifactPaths: plan.requestedArtifactPathCount,
                        sourceArtifactPaths: plan.sourceArtifactPaths.count,
                        stemArtifactPaths: plan.stemArtifactPaths.count,
                        liveProjectIDsMatched: liveProjectUUIDs.count,
                        liveArtifactPathsMatched: livePaths.count,
                        logicalFetchCalls: logicalFetchCalls
                    )
                )
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
        guard let output else {
            throw Lane2TargetedLiveReferenceFailure.corruptValue("missing targeted live-reference result")
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
            throw Lane2TargetedLiveReferenceFailure.incompatibleStoreModel
        }
    }

    private static func fetchDictionaries(
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

    private static func inPredicate(key: String, values: [Any]) -> NSPredicate {
        guard !values.isEmpty else { return NSPredicate(value: false) }
        return NSPredicate(format: "%K IN %@", argumentArray: [key, values])
    }

    private static func liveAndInPredicate(key: String, values: [Any]) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "tombstoned == NO"),
            inPredicate(key: key, values: values)
        ])
    }

    private static func uuid(_ value: Any?, key: String) throws -> UUID {
        if let value = value as? UUID { return value }
        if let value = value as? NSUUID { return value as UUID }
        throw Lane2TargetedLiveReferenceFailure.corruptValue(key)
    }

    private static func string(_ value: Any?, key: String) throws -> String {
        guard let value = value as? String else {
            throw Lane2TargetedLiveReferenceFailure.corruptValue(key)
        }
        return value
    }

    private static func chunks<T>(_ values: [T], size: Int) -> [[T]] {
        guard !values.isEmpty else { return [] }
        return stride(from: 0, to: values.count, by: max(size, 1)).map { start in
            Array(values[start..<min(start + max(size, 1), values.count)])
        }
    }

    private static func uuidLessThan(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

private enum Lane2AW26L2V1Model {
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
