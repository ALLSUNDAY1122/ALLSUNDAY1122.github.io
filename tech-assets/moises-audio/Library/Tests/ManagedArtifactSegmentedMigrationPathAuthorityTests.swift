import Foundation
import XCTest

final class Lane2ManagedArtifactSegmentedMigrationPathAuthorityTests: XCTestCase {
    func testSegmentedDirectorySymlinkCannotRedirectCleanup() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let external = fixture.root.deletingLastPathComponent().appendingPathComponent("aw52-external-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: external) }
        let externalFile = external.appendingPathComponent("01.pending.json")
        try Data("outside".utf8).write(to: externalFile)
        try fixture.ensureV1()
        try FileManager.default.createSymbolicLink(at: fixture.segmented, withDestinationURL: external)

        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        XCTAssertThrowsError(try store.removeUncommittedGenerations(shardIndex: 1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFile.path))
    }

    func testDanglingManifestDoesNotFallBackToLegacy() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try fixture.writeLegacy(index: 2, entries: [.init(relativePath: "Imports/a.m4a", modificationTime: 1)])
        try FileManager.default.createDirectory(at: fixture.segmented, withIntermediateDirectories: true)
        let manifest = fixture.segmented.appendingPathComponent("02.manifest.json")
        let absent = fixture.root.appendingPathComponent("never-created.json")
        try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: absent)

        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        XCTAssertThrowsError(try store.migrateLegacyShardIfNeeded(2))
        XCTAssertFalse(store.hasCommittedShard(2))
    }

    func testSymlinkedLegacyShardAncestorFailsClosed() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let external = fixture.root.deletingLastPathComponent().appendingPathComponent("aw52-legacy-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: external) }
        let externalLegacy = external.appendingPathComponent("03.json")
        try Fixture.writeLegacyPayload(index: 3, entries: [.init(relativePath: "Imports/a.m4a", modificationTime: 1)], to: externalLegacy)
        try fixture.ensureV1()
        try FileManager.default.createSymbolicLink(at: fixture.shards, withDestinationURL: external)

        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        XCTAssertThrowsError(try store.migrateLegacyShardIfNeeded(3))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalLegacy.path))
    }

    func testCommittedManifestCannotAuthorizeSymlinkSegment() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try fixture.writeLegacy(index: 4, entries: [.init(relativePath: "Imports/a.m4a", modificationTime: 1)])
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        _ = try store.migrateLegacyShardIfNeeded(4)
        let manifestData = try Data(contentsOf: fixture.segmented.appendingPathComponent("04.manifest.json"))
        let manifestObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let generation = try XCTUnwrap(manifestObject["generation"] as? String)
        let segment = fixture.segmented.appendingPathComponent("04.\(generation).0000.json")
        try FileManager.default.removeItem(at: segment)
        let external = fixture.root.appendingPathComponent("external-segment.json")
        try Data("outside".utf8).write(to: external)
        try FileManager.default.createSymbolicLink(at: segment, withDestinationURL: external)

        XCTAssertThrowsError(try store.loadCommittedEntries(4))
        XCTAssertEqual(try Data(contentsOf: external), Data("outside".utf8))
    }

    func testSymlinkPendingLeafIsNotRemovedByCleanup() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try fixture.writeLegacy(index: 5, entries: [.init(relativePath: "Imports/a.m4a", modificationTime: 1)])
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        _ = try store.migrateLegacyShardIfNeeded(5)
        let external = fixture.root.appendingPathComponent("outside-pending.json")
        try Data("outside".utf8).write(to: external)
        let pending = fixture.segmented.appendingPathComponent("05.pending.json")
        try FileManager.default.createSymbolicLink(at: pending, withDestinationURL: external)

        XCTAssertThrowsError(try store.removeUncommittedGenerations(shardIndex: 5))
        XCTAssertEqual(try Data(contentsOf: external), Data("outside".utf8))
    }

    func testCleanupRemovesRegularUncommittedFilesAndPreservesCommittedGeneration() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let entries: [Lane2ManagedArtifactSegmentEntry] = [.init(relativePath: "Imports/a.m4a", modificationTime: 1.0)]
        try fixture.writeLegacy(index: 6, entries: entries)
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        _ = try store.migrateLegacyShardIfNeeded(6)
        try Data("junk".utf8).write(to: fixture.segmented.appendingPathComponent("06.pending.json"))
        try Data("junk".utf8).write(to: fixture.segmented.appendingPathComponent("06.00000000-0000-0000-0000-000000000000.0000.json"))

        let removed = try store.removeUncommittedGenerations(shardIndex: 6)
        let loaded = try store.loadCommittedEntries(6)
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(loaded, entries)
    }

    func testHugeManifestEntryCountFailsClosedWithoutArithmeticOverflow() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.segmented, withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "shardIndex": 7,
            "generation": UUID().uuidString,
            "segmentCount": 1,
            "entryCount": Int.max
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: fixture.segmented.appendingPathComponent("07.manifest.json"), options: [.atomic])

        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)
        XCTAssertThrowsError(try store.loadCommittedEntries(7))
    }

    func testNormalMigrationRetainsLegacyRollbackAndRetiresPending() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let entries = (0..<1300).map { Lane2ManagedArtifactSegmentEntry(relativePath: String(format: "Imports/%04d.m4a", $0), modificationTime: Double($0)) }
        try fixture.writeLegacy(index: 8, entries: entries)
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: fixture.root)

        let result = try store.migrateLegacyShardIfNeeded(8)
        let loaded = try store.loadCommittedEntries(8)
        XCTAssertTrue(result.migrated)
        XCTAssertEqual(result.segmentCount, 3)
        XCTAssertEqual(loaded, entries)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.shards.appendingPathComponent("08.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.segmented.appendingPathComponent("08.pending.json").path))
    }
}

private final class Fixture {
    let root: URL
    let v1: URL
    let shards: URL
    let segmented: URL
    private let fm = FileManager.default

    init() throws {
        root = fm.temporaryDirectory.appendingPathComponent("L2AW52PathTests-" + UUID().uuidString, isDirectory: true)
        v1 = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1", isDirectory: true)
        shards = v1.appendingPathComponent("Shards", isDirectory: true)
        segmented = v1.appendingPathComponent("Segmented", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanup() { try? fm.removeItem(at: root) }
    func ensureV1() throws { try fm.createDirectory(at: v1, withIntermediateDirectories: true) }

    func writeLegacy(index: Int, entries: [Lane2ManagedArtifactSegmentEntry]) throws {
        try fm.createDirectory(at: shards, withIntermediateDirectories: true)
        try Self.writeLegacyPayload(index: index, entries: entries, to: shards.appendingPathComponent(String(format: "%02x.json", index)))
    }

    static func writeLegacyPayload(index: Int, entries: [Lane2ManagedArtifactSegmentEntry], to url: URL) throws {
        struct Legacy: Codable { let schemaVersion: Int; let shardIndex: Int; let entries: [Lane2ManagedArtifactSegmentEntry] }
        try JSONEncoder().encode(Legacy(schemaVersion: 1, shardIndex: index, entries: entries)).write(to: url, options: [.atomic])
    }
}
