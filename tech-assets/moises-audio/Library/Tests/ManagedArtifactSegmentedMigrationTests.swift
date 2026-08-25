import Foundation
import XCTest

final class Lane2ManagedArtifactSegmentedMigrationTests: XCTestCase {
    func testLegacyShardMigratesIntoBoundedSegmentsAndRetainsLegacyRollbackBytes() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let entries = (0..<1300).map {
            Lane2ManagedArtifactSegmentEntry(
                relativePath: String(format: "Imports/%04d.m4a", $0),
                modificationTime: Double($0)
            )
        }
        try writeLegacyShard(index: 7, entries: entries, root: root)
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: root)

        let result = try store.migrateLegacyShardIfNeeded(7)
        XCTAssertTrue(result.migrated)
        XCTAssertEqual(result.entryCount, 1300)
        XCTAssertEqual(result.segmentCount, 3)
        XCTAssertTrue(store.hasCommittedShard(7))
        XCTAssertEqual(try store.loadCommittedEntries(7), entries)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL(index: 7, root: root).path))
    }

    func testCommittedMigrationIsIdempotent() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let entries = [Lane2ManagedArtifactSegmentEntry(relativePath: "Imports/a.m4a", modificationTime: 1)]
        try writeLegacyShard(index: 3, entries: entries, root: root)
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: root)
        XCTAssertTrue(try store.migrateLegacyShardIfNeeded(3).migrated)
        XCTAssertFalse(try store.migrateLegacyShardIfNeeded(3).migrated)
        XCTAssertEqual(try store.loadCommittedEntries(3), entries)
    }

    func testCorruptLegacyShardFailsClosedWithoutManifest() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = legacyURL(index: 2, root: root)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: url)
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: root)
        XCTAssertThrowsError(try store.migrateLegacyShardIfNeeded(2))
        XCTAssertFalse(store.hasCommittedShard(2))
    }

    func testUncommittedGenerationCleanupDoesNotDeleteCommittedGeneration() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let entries = [Lane2ManagedArtifactSegmentEntry(relativePath: "Imports/a.m4a", modificationTime: 1)]
        try writeLegacyShard(index: 1, entries: entries, root: root)
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: root)
        _ = try store.migrateLegacyShardIfNeeded(1)
        let segmented = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true)
        try Data("junk".utf8).write(to: segmented.appendingPathComponent("01.pending.json"))
        try Data("junk".utf8).write(to: segmented.appendingPathComponent("01.00000000-0000-0000-0000-000000000000.0000.json"))

        XCTAssertGreaterThanOrEqual(try store.removeUncommittedGenerations(shardIndex: 1), 2)
        XCTAssertEqual(try store.loadCommittedEntries(1), entries)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("L2AW39Tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func legacyURL(index: Int, root: URL) -> URL {
        root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Shards", isDirectory: true)
            .appendingPathComponent(String(format: "%02x.json", index))
    }

    private func writeLegacyShard(index: Int, entries: [Lane2ManagedArtifactSegmentEntry], root: URL) throws {
        struct Legacy: Codable { let schemaVersion: Int; let shardIndex: Int; let entries: [Lane2ManagedArtifactSegmentEntry] }
        let url = legacyURL(index: index, root: root)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Legacy(schemaVersion: 1, shardIndex: index, entries: entries)).write(to: url, options: [.atomic])
    }
}
