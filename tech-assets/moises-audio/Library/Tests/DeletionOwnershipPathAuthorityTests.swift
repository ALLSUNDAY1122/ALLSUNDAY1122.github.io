import Foundation
import XCTest

final class Lane2DeletionOwnershipPathAuthorityTests: XCTestCase {
    func testEnsureLayoutRejectsRecoveryAncestorSymlinkWithoutCreatingExternalLayout() throws {
        let root = try makeRoot(prefix: "recovery-root")
        let external = try makeRoot(prefix: "recovery-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent(".LibraryRecovery", isDirectory: true),
            withDestinationURL: external
        )

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        XCTAssertThrowsError(try index.ensureLayout()) { error in
            XCTAssertEqual(
                error as? Lane2DeletionOwnershipIndexFailure,
                .recordCorrupt("DeleteOwnership")
            )
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: external.appendingPathComponent("DeleteOwnership", isDirectory: true).path
            )
        )
    }

    func testRecordLookupRejectsDeleteOwnershipAncestorSymlinkWithoutReadingExternalRecord() throws {
        let root = try makeRoot(prefix: "lookup-root")
        let external = try makeRoot(prefix: "lookup-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let recovery = root.appendingPathComponent(".LibraryRecovery", isDirectory: true)
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        let externalOwnership = external.appendingPathComponent("DeleteOwnership", isDirectory: true)
        try FileManager.default.createDirectory(at: externalOwnership, withIntermediateDirectories: true)
        let projectUUID = UUID()
        let externalRecord = externalOwnership.appendingPathComponent(projectUUID.uuidString + ".json")
        let sentinel = Data("must-not-read-or-change".utf8)
        try sentinel.write(to: externalRecord)
        try FileManager.default.createSymbolicLink(
            at: recovery.appendingPathComponent("DeleteOwnership", isDirectory: true),
            withDestinationURL: externalOwnership
        )

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        XCTAssertThrowsError(try index.record(projectUUID: projectUUID))
        XCTAssertEqual(try Data(contentsOf: externalRecord), sentinel)
    }

    func testRemoveRejectsShardsAncestorSymlinkWithoutDeletingExternalRecord() throws {
        let root = try makeRoot(prefix: "remove-root")
        let external = try makeRoot(prefix: "remove-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let ownership = root.appendingPathComponent(
            ".LibraryRecovery/DeleteOwnership",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: ownership, withIntermediateDirectories: true)

        let projectUUID = UUID()
        let shard = Lane2DeletionOwnershipIndex.shardIndex(for: projectUUID)
        let externalShards = external.appendingPathComponent("Shards", isDirectory: true)
        let externalShard = externalShards.appendingPathComponent(
            String(format: "%02x", shard),
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: externalShard, withIntermediateDirectories: true)
        let externalRecord = externalShard.appendingPathComponent(projectUUID.uuidString + ".json")
        let sentinel = Data("must-survive".utf8)
        try sentinel.write(to: externalRecord)
        try FileManager.default.createSymbolicLink(
            at: ownership.appendingPathComponent("Shards", isDirectory: true),
            withDestinationURL: externalShards
        )

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        XCTAssertThrowsError(try index.remove(projectUUID: projectUUID))
        XCTAssertEqual(try Data(contentsOf: externalRecord), sentinel)
    }

    func testLegacyMarkerDanglingSymlinkCannotBeOverwritten() throws {
        let root = try makeRoot(prefix: "marker-root")
        defer { try? FileManager.default.removeItem(at: root) }
        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        try index.ensureLayout()

        let marker = root.appendingPathComponent(
            ".LibraryRecovery/DeleteOwnership/.legacy-scan-v1-complete"
        )
        let missing = root.appendingPathComponent("outside-missing-marker")
        try FileManager.default.createSymbolicLink(at: marker, withDestinationURL: missing)

        XCTAssertFalse(index.isLegacyScanComplete)
        XCTAssertThrowsError(try index.markLegacyScanComplete())
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: marker.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testManifestRecoveryRejectsShardsAncestorSymlinkWithoutEnumeratingExternalTarget() throws {
        let root = try makeRoot(prefix: "manifest-shards-root")
        let external = try makeRoot(prefix: "manifest-shards-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let ownership = root.appendingPathComponent(
            ".LibraryRecovery/DeleteOwnership",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: ownership, withIntermediateDirectories: true)
        let externalShards = external.appendingPathComponent("Shards", isDirectory: true)
        try FileManager.default.createDirectory(at: externalShards, withIntermediateDirectories: true)
        let sentinel = externalShards.appendingPathComponent("sentinel")
        try Data("must-survive".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(
            at: ownership.appendingPathComponent("Shards", isDirectory: true),
            withDestinationURL: externalShards
        )

        let recovery = Lane2DeletionOwnershipManifestRecovery(rootURL: root)
        XCTAssertThrowsError(try recovery.reconcile())
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("must-survive".utf8))
    }

    func testManifestRecoveryRejectsManifestSymlinkWithoutOverwritingExternalTarget() throws {
        let root = try makeRoot(prefix: "manifest-root")
        let external = try makeRoot(prefix: "manifest-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        try index.ensureLayout()

        let projectUUID = UUID()
        let shard = Lane2DeletionOwnershipIndex.shardIndex(for: projectUUID)
        let shardDirectory = root.appendingPathComponent(
            ".LibraryRecovery/DeleteOwnership/Shards/\(String(format: "%02x", shard))",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: shardDirectory, withIntermediateDirectories: true)
        try Data("record-placeholder".utf8).write(
            to: shardDirectory.appendingPathComponent(projectUUID.uuidString + ".json")
        )

        let externalManifest = external.appendingPathComponent("manifest.json")
        let sentinel = Data("external-manifest-must-survive".utf8)
        try sentinel.write(to: externalManifest)
        let manifest = root.appendingPathComponent(
            ".LibraryRecovery/DeleteOwnership/.active-shards-v2.json"
        )
        try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: externalManifest)

        let recovery = Lane2DeletionOwnershipManifestRecovery(rootURL: root)
        XCTAssertThrowsError(try recovery.reconcile())
        XCTAssertEqual(try Data(contentsOf: externalManifest), sentinel)
        let attributes = try FileManager.default.attributesOfItem(atPath: manifest.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testNormalEmptyLayoutAndLegacyMarkerStillConverge() throws {
        let root = try makeRoot(prefix: "normal")
        defer { try? FileManager.default.removeItem(at: root) }
        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        try index.ensureLayout()
        XCTAssertNil(try index.record(projectUUID: UUID()))
        XCTAssertFalse(index.isLegacyScanComplete)
        try index.markLegacyScanComplete()
        XCTAssertTrue(index.isLegacyScanComplete)

        let report = try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        XCTAssertEqual(report.discoveredActiveShards, [])
        XCTAssertFalse(report.manifestWasPresent)
        XCTAssertFalse(report.manifestRewritten)
    }

    private func makeRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2DeletionAuthority-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
