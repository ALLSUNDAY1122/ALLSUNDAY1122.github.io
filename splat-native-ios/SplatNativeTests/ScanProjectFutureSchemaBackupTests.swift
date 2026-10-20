import Foundation
import XCTest

final class ScanProjectFutureSchemaBackupTests: XCTestCase {
    private var rootURL: URL!
    private var store: ScanProjectStore!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectFutureSchemaBackupTests-\(UUID().uuidString)", isDirectory: true)
        store = ScanProjectStore(rootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL { try? FileManager.default.removeItem(at: rootURL) }
        store = nil
        rootURL = nil
    }

    func testFutureManifestBackupBlocksCurrentPrimaryAndDirectWrite() throws {
        let created = try store.createProject(title: "future backup")
        _ = try store.updateManifest(projectURL: created.0) { $0.acceptedFrames = 8 }
        let primary = created.0.appendingPathComponent(ScanProjectStore.manifestFileName)
        let backup = created.0.appendingPathComponent(ScanProjectStore.manifestBackupFileName)
        let primaryBefore = try Data(contentsOf: primary)
        let futureBackup = try futureJSONData(
            basedOn: primary,
            schemaVersion: ScanProjectManifest.currentSchemaVersion + 2
        )
        try futureBackup.write(to: backup, options: .atomic)

        XCTAssertThrowsError(try store.loadProject(id: created.1.id)) { error in
            guard case ScanProjectStoreError.unsupportedManifestSchemaVersion(let version) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(version, ScanProjectManifest.currentSchemaVersion + 2)
        }
        XCTAssertThrowsError(try store.writeManifest(created.1, to: created.0))
        XCTAssertEqual(try Data(contentsOf: primary), primaryBefore)
        XCTAssertEqual(try Data(contentsOf: backup), futureBackup)
    }

    func testFutureCheckpointBackupBlocksCurrentPrimaryAndRotation() throws {
        let created = try store.createProject(title: "future checkpoint backup")
        let first = checkpoint(timestamp: 10)
        let second = checkpoint(timestamp: 20)
        try store.saveCheckpoint(first, projectURL: created.0)
        try store.saveCheckpoint(second, projectURL: created.0)
        let primary = created.0.appendingPathComponent(ScanProjectStore.checkpointFileName)
        let backup = created.0.appendingPathComponent(ScanProjectStore.checkpointBackupFileName)
        let primaryBefore = try Data(contentsOf: primary)
        let futureBackup = try futurePlistData(
            basedOn: primary,
            schemaVersion: ScanCaptureCheckpoint.currentSchemaVersion + 3
        )
        try futureBackup.write(to: backup, options: .atomic)

        XCTAssertThrowsError(try store.loadCheckpoint(projectURL: created.0)) { error in
            guard case ScanProjectStoreError.unsupportedCheckpointSchemaVersion(let version) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(version, ScanCaptureCheckpoint.currentSchemaVersion + 3)
        }
        XCTAssertThrowsError(try store.saveCheckpoint(checkpoint(timestamp: 30), projectURL: created.0))
        XCTAssertEqual(try Data(contentsOf: primary), primaryBefore)
        XCTAssertEqual(try Data(contentsOf: backup), futureBackup)
    }

    func testFutureManifestBlocksResultCommitBeforeAnyFileMoves() throws {
        let created = try store.createProject(title: "future commit")
        let primary = created.0.appendingPathComponent(ScanProjectStore.manifestFileName)
        let futureData = try futureJSONData(
            basedOn: primary,
            schemaVersion: ScanProjectManifest.currentSchemaVersion + 1
        )
        try futureData.write(to: primary, options: .atomic)
        let pending = created.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x33, count: 64).write(to: pending, options: .atomic)

        XCTAssertThrowsError(try store.commitPendingSplat(projectURL: created.0))
        XCTAssertEqual(try Data(contentsOf: primary), futureData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.splatResultFileName).path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path
        ))
    }

    private func checkpoint(timestamp: TimeInterval) -> ScanCaptureCheckpoint {
        ScanCaptureCheckpoint(
            frames: [],
            featurePoints: [],
            coverageSectors: [],
            estimatedTargetCenter: nil,
            lastAcceptedTransform: nil,
            lastAcceptedTimestamp: timestamp
        )
    }

    private func futureJSONData(basedOn url: URL, schemaVersion: Int) throws -> Data {
        let source = try Data(contentsOf: url)
        guard var object = try JSONSerialization.jsonObject(with: source) as? [String: Any] else {
            throw ScanProjectStoreError.invalidManifest
        }
        object["schemaVersion"] = schemaVersion
        object["futureOnlyBackupField"] = ["preserve": true]
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func futurePlistData(basedOn url: URL, schemaVersion: Int) throws -> Data {
        let source = try Data(contentsOf: url)
        guard var object = try PropertyListSerialization.propertyList(from: source, options: [], format: nil) as? [String: Any] else {
            throw ScanProjectStoreError.rawDataUnavailable
        }
        object["schemaVersion"] = schemaVersion
        object["futureOnlyBackupField"] = "preserve"
        return try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    }
}
