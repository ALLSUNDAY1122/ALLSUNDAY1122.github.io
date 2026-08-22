import Foundation

#if canImport(CoreData)
@preconcurrency import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

/// Serialized Core Data adapter for the frozen epoch-2 ProjectLibraryPersisting contract.
/// Core Data objects never cross this boundary; only stable IDs, scalars and relative paths are persisted.
public final class CoreDataProjectLibraryStore: @unchecked Sendable, ProjectLibraryPersisting {
    public struct Configuration: Sendable {
        public let storeURL: URL?
        public let inMemory: Bool

        public init(storeURL: URL? = nil, inMemory: Bool = false) {
            self.storeURL = storeURL
            self.inMemory = inMemory
        }
    }

    private let coordinator: NSPersistentStoreCoordinator
    private let writerContext: NSManagedObjectContext

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
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ProjectRecord")
            request.predicate = NSPredicate(format: "tombstoned == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).map { try StoreMapper.projectSnapshot(record: $0, context: context) }
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
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "SetlistRecord")
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).map { record in
                let id = SetlistID(rawValue: try StoreValue.uuid(record, "setlistUUID"))
                let entries = try StoreFetch.setlistEntries(setlistID: id.rawValue, context: context).map { entry in
                    SetlistEntry(
                        id: SetlistEntryID(rawValue: try StoreValue.uuid(entry, "entryUUID")),
                        projectID: ProjectID(rawValue: try StoreValue.uuid(entry, "projectUUID")),
                        position: Int(try StoreValue.int64(entry, "position"))
                    )
                }
                return SetlistSnapshot(id: id, name: try StoreValue.string(record, "name"), entries: entries)
            }
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

        let processing = try StoreFetch.processing(projectID: projectID.rawValue, context: context).map { try processing(record: $0) }
        let stems = try StoreFetch.stems(projectID: projectID.rawValue, context: context).map { stemRecord in
            StemArtifact(
                id: StemID(rawValue: try StoreValue.uuid(stemRecord, "stemUUID")),
                projectID: projectID,
                role: StemRole(rawValue: try StoreValue.string(stemRecord, "role")),
                relativePath: try StoreValue.string(stemRecord, "relativePath"),
                sampleRate: try StoreValue.double(stemRecord, "sampleRate"),
                channels: Int(try StoreValue.int64(stemRecord, "channels")),
                frameCount: try StoreValue.int64(stemRecord, "frameCount"),
                startTimeSeconds: try StoreValue.double(stemRecord, "startTimeSeconds")
            )
        }
        try LibrarySnapshotPolicy.validate(stems: stems, projectID: projectID)
        let edits = try StoreFetch.edit(projectID: projectID.rawValue, context: context).map { try edits(record: $0, projectID: projectID, context: context) }
        return PersistedProjectSnapshot(projectID: projectID, source: source, processing: processing, stems: stems, edits: edits)
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

    static func edits(record: NSManagedObject, projectID: ProjectID, context: NSManagedObjectContext) throws -> ProjectUserEdits {
        let mix = try StoreFetch.stemMix(projectID: projectID.rawValue, context: context).map { mixRecord in
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
}

private enum StoreFetch {
    static func insert(entity: String, context: NSManagedObjectContext) -> NSManagedObject {
        NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    static func save(_ context: NSManagedObjectContext) throws {
        if context.hasChanges { try context.save() }
    }

    static func project(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(entity: "ProjectRecord", predicate: NSPredicate(format: "projectUUID == %@", id as NSUUID), context: context)
    }

    static func requireLiveProject(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let project = try project(id: id, context: context), !StoreValue.bool(project, "tombstoned") else {
            throw LibraryPersistenceFailure.projectNotFound(ProjectID(rawValue: id))
        }
        return project
    }

    static func asset(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(entity: "AssetRecord", predicate: NSPredicate(format: "assetUUID == %@", id as NSUUID), context: context)
    }

    static func processing(projectID: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(entity: "ProcessingRecord", predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID), context: context)
    }

    static func edit(projectID: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(entity: "ProjectEditRecord", predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID), context: context)
    }

    static func setlist(id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        try one(entity: "SetlistRecord", predicate: NSPredicate(format: "setlistUUID == %@", id as NSUUID), context: context)
    }

    static func stems(projectID: UUID, context: NSManagedObjectContext) throws -> [NSManagedObject] {
        try many(entity: "StemRecord", predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID), sort: [NSSortDescriptor(key: "role", ascending: true)], context: context)
    }

    static func stemMix(projectID: UUID, context: NSManagedObjectContext) throws -> [NSManagedObject] {
        try many(entity: "StemMixRecord", predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID), sort: [NSSortDescriptor(key: "position", ascending: true)], context: context)
    }

    static func setlistEntries(setlistID: UUID, context: NSManagedObjectContext) throws -> [NSManagedObject] {
        try many(entity: "SetlistEntryRecord", predicate: NSPredicate(format: "setlistUUID == %@", setlistID as NSUUID), sort: [NSSortDescriptor(key: "position", ascending: true)], context: context)
    }

    static func setlistEntries(projectID: UUID, context: NSManagedObjectContext) throws -> [NSManagedObject] {
        try many(entity: "SetlistEntryRecord", predicate: NSPredicate(format: "projectUUID == %@", projectID as NSUUID), sort: [], context: context)
    }

    private static func one(entity: String, predicate: NSPredicate, context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func many(entity: String, predicate: NSPredicate, sort: [NSSortDescriptor], context: NSManagedObjectContext) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.sortDescriptors = sort
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

        model.entities = [project, asset, processing, stem, edit, stemMix, setlist, setlistEntry]
        return model
    }

    private static func entity(_ name: String, _ attributes: [NSAttributeDescription], unique: [String] = []) -> NSEntityDescription {
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
