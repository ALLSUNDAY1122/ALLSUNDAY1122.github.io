import Foundation
import XCTest

final class DeletionOwnershipManifestRecoveryTests: XCTestCase {
    func testMissingManifestIsRebuiltFromDeterministicShardDirectories() throws {
        let root = temporaryRoot("missing")
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let record = try makeRecord()
        try index.persist(record)
        try FileManager.default.removeItem(at: manifestURL(root: root))

        let report = try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        XCTAssertTrue(report.manifestRewritten)
        XCTAssertFalse(report.manifestWasPresent)
        XCTAssertEqual(report.discoveredActiveShards, [Lane2DeletionOwnershipIndex.shardIndex(for: record.projectUUID)])

        let slice = try index.pendingRecordSlice(limit: 16)
        XCTAssertEqual(slice.records.map(\.projectUUID), [record.projectUUID])
    }

    func testMalformedManifestIsRebuiltWithoutDroppingOwnershipRecord() throws {
        let root = temporaryRoot("corrupt")
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let record = try makeRecord()
        try index.persist(record)
        try Data("{broken".utf8).write(to: manifestURL(root: root), options: [.atomic])

        let report = try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        XCTAssertTrue(report.manifestWasPresent)
        XCTAssertFalse(report.manifestWasValid)
        XCTAssertTrue(report.manifestRewritten)

        XCTAssertEqual(try index.record(projectUUID: record.projectUUID), record)
    }

    func testValidButStaleManifestMissingShardConvergesToDirectoryTruth() throws {
        let root = temporaryRoot("stale-missing")
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let first = try makeRecord()
        var second = try makeRecord()
        while Lane2DeletionOwnershipIndex.shardIndex(for: second.projectUUID)
                == Lane2DeletionOwnershipIndex.shardIndex(for: first.projectUUID) {
            second = try makeRecord()
        }
        try index.persist(first)
        try index.persist(second)

        let firstShard = Lane2DeletionOwnershipIndex.shardIndex(for: first.projectUUID)
        try writeManifest([firstShard], root: root)

        let report = try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        XCTAssertTrue(report.manifestWasValid)
        XCTAssertTrue(report.manifestRewritten)
        XCTAssertEqual(
            Set(report.discoveredActiveShards),
            Set([first, second].map { Lane2DeletionOwnershipIndex.shardIndex(for: $0.projectUUID) })
        )
    }

    func testStaleEmptyShardIsRemovedFromManifest() throws {
        let root = temporaryRoot("stale-empty")
        defer { try? FileManager.default.removeItem(at: root) }

        let emptyShard = 7
        let emptyDirectory = shardRootURL(root: root)
            .appendingPathComponent(String(format: "%02x", emptyShard), isDirectory: true)
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        try writeManifest([emptyShard], root: root)

        let report = try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        XCTAssertTrue(report.manifestWasValid)
        XCTAssertTrue(report.manifestRewritten)
        XCTAssertTrue(report.discoveredActiveShards.isEmpty)
    }

    func testSymlinkShardDirectoryFailsClosed() throws {
        let root = temporaryRoot("symlink")
        defer { try? FileManager.default.removeItem(at: root) }

        let shardRoot = shardRootURL(root: root)
        try FileManager.default.createDirectory(at: shardRoot, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let shardDirectory = shardRoot.appendingPathComponent("00", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: shardDirectory, withDestinationURL: target)

        XCTAssertThrowsError(
            try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        )
    }

    func testMalformedVisibleShardEntryFailsClosed() throws {
        let root = temporaryRoot("malformed")
        defer { try? FileManager.default.removeItem(at: root) }

        let shardDirectory = shardRootURL(root: root).appendingPathComponent("00", isDirectory: true)
        try FileManager.default.createDirectory(at: shardDirectory, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: shardDirectory.appendingPathComponent("not-a-record.txt"))

        XCTAssertThrowsError(
            try Lane2DeletionOwnershipManifestRecovery(rootURL: root).reconcile()
        )
    }

    private func makeRecord() throws -> Lane2DeletionOwnershipRecord {
        let projectUUID = UUID()
        let sourceUUID = UUID()
        return try Lane2DeletionOwnershipRecord(
            projectUUID: projectUUID,
            sourceAssetUUID: sourceUUID,
            artifactRelativePaths: ["Imports/\(sourceUUID.uuidString).m4a"]
        )
    }

    private func temporaryRoot(_ suffix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("L2-AW46-\(suffix)-\(UUID().uuidString)", isDirectory: true)
    }

    private func ownershipURL(root: URL) -> URL {
        root.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
    }

    private func shardRootURL(root: URL) -> URL {
        ownershipURL(root: root).appendingPathComponent("Shards", isDirectory: true)
    }

    private func manifestURL(root: URL) -> URL {
        ownershipURL(root: root).appendingPathComponent(".active-shards-v2.json")
    }

    private func writeManifest(_ shardIndices: [Int], root: URL) throws {
        try FileManager.default.createDirectory(at: ownershipURL(root: root), withIntermediateDirectories: true)
        let normalized = Array(Set(shardIndices)).sorted()
        let json = "{\"schemaVersion\":2,\"shardIndices\":[\(normalized.map(String.init).joined(separator: ","))]}"
        try Data(json.utf8).write(to: manifestURL(root: root), options: [.atomic])
    }
}
