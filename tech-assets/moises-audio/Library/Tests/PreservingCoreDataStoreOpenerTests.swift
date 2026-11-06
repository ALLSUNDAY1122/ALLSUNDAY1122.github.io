import Foundation
import XCTest

#if canImport(CoreData)
import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class PreservingCoreDataStoreOpenerTests: XCTestCase {
    func testLegacyV0MigratesOnCopyAndOriginalBytesRemainPreserved() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LegacyMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let recovery = root.appendingPathComponent("Recovery", isDirectory: true)
        let sourceID = UUID()
        let projectID = UUID()
        try LegacyV0Fixture.write(storeURL: storeURL, sourceID: sourceID, projectID: projectID)
        let originalBytes = try Data(contentsOf: storeURL)

        let opened = try await PreservingCoreDataStoreOpener.open(storeURL: storeURL, recoveryRootURL: recovery)
        let projects = try await opened.store.listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.projectID.rawValue, projectID)
        XCTAssertEqual(projects.first?.source.id.rawValue, sourceID)
        XCTAssertNotEqual(opened.activeStorePath, storeURL.path)
        XCTAssertEqual(try Data(contentsOf: storeURL), originalBytes)
        XCTAssertNotNil(opened.preservedSnapshotPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(opened.preservedSnapshotPath)))
    }

    func testPlausibleHeaderButInvalidSQLiteFailsMigrationAndPreservesOriginal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MigrationFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("Library.sqlite")
        var bytes = Data("SQLite format 3\0".utf8)
        bytes.append(Data("not-a-real-database".utf8))
        try bytes.write(to: storeURL)

        do {
            _ = try await PreservingCoreDataStoreOpener.open(storeURL: storeURL)
            XCTFail("Expected migration failure")
        } catch let PreservingStoreOpenFailure.migrationFailed(originalPath, snapshotPath, _, _) {
            XCTAssertEqual(originalPath, storeURL.path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotPath))
            XCTAssertEqual(try Data(contentsOf: storeURL), bytes)
        }
    }

    func testInvalidHeaderExportsRecoveryPackageWithoutCreatingEmptyReplacement() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Corruption-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("Library.sqlite")
        let corrupt = Data("corrupt-user-store".utf8)
        try corrupt.write(to: storeURL)

        do {
            _ = try await PreservingCoreDataStoreOpener.open(storeURL: storeURL)
            XCTFail("Expected corruption failure")
        } catch let PreservingStoreOpenFailure.corruptStore(originalPath, recoveryPackagePath) {
            XCTAssertEqual(originalPath, storeURL.path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryPackagePath))
            XCTAssertEqual(try Data(contentsOf: storeURL), corrupt)
        }
    }
}

private enum LegacyV0Fixture {
    static func write(storeURL: URL, sourceID: UUID, projectID: UUID) throws {
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let model = makeModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let asset = NSEntityDescription.insertNewObject(forEntityName: "AssetRecord", into: context)
            asset.setValue(sourceID, forKey: "assetUUID")
            asset.setValue("Imports/legacy/source.m4a", forKey: "relativePath")
            asset.setValue("audio", forKey: "mediaKind")
            asset.setValue(123.0, forKey: "durationSeconds")

            let project = NSEntityDescription.insertNewObject(forEntityName: "ProjectRecord", into: context)
            project.setValue(projectID, forKey: "projectUUID")
            project.setValue(sourceID, forKey: "sourceAssetUUID")
            project.setValue(Date(timeIntervalSince1970: 1_700_000_000), forKey: "createdAt")
            project.setValue(Date(timeIntervalSince1970: 1_700_000_001), forKey: "updatedAt")
            project.setValue(false, forKey: "tombstoned")
            try context.save()
        }
        try coordinator.remove(store)
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = Set([AnyHashable("L2-V0-legacy-fixture")])
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
        let setlist = entity("SetlistRecord", [
            attribute("setlistUUID", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ], unique: ["setlistUUID"])
        let entry = entity("SetlistEntryRecord", [
            attribute("entryUUID", .UUIDAttributeType),
            attribute("setlistUUID", .UUIDAttributeType),
            attribute("projectUUID", .UUIDAttributeType),
            attribute("position", .integer64AttributeType)
        ], unique: ["entryUUID"])
        model.entities = [project, asset, setlist, entry]
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

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
#endif
