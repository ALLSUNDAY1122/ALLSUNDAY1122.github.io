import Foundation
import XCTest

final class ManagedArtifactSegmentedRuntimeTests: XCTestCase {
    func testLegacyMutationActivatesSegmentedAuthorityAndPreservesLegacyRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/a.m4a"
        let artifact = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: artifact)
        let shard = shardIndex(path)
        let legacyDirectory = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Shards", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyURL = legacyDirectory.appendingPathComponent(String(format: "%02x.json", shard))
        let legacy = "{\"entries\":[{\"modificationTime\":0,\"relativePath\":\"Imports/a.m4a\"}],\"schemaVersion\":1,\"shardIndex\":\(shard)}"
        try Data(legacy.utf8).write(to: legacyURL)

        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        XCTAssertEqual(try runtime.authority(forShard: shard), .legacyV1)
        try runtime.upsertManaged(relativePaths: [path])
        XCTAssertEqual(try runtime.authority(forShard: shard), .segmentedCommitted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertEqual(try runtime.loadShard(shard).map(\.relativePath), [path])
    }

    func testRemovingLastEntryKeepsZeroEntrySegmentedAuthority() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Exports/final.m4a"
        let artifact = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([9]).write(to: artifact)
        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        try runtime.upsertManaged(relativePaths: [path])
        let shard = shardIndex(path)
        try runtime.removeManaged(relativePaths: [path])
        XCTAssertEqual(try runtime.authority(forShard: shard), .segmentedCommitted)
        XCTAssertTrue(try runtime.loadShard(shard).isEmpty)
    }

    func testCorruptCommittedManifestFailsClosed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let shard = 17
        let segmented = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true)
        try FileManager.default.createDirectory(at: segmented, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: segmented.appendingPathComponent("11.manifest.json"))
        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        XCTAssertThrowsError(try runtime.authority(forShard: shard))
    }

    private func shardIndex(_ path: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in path.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
        return Int(hash % 256)
    }
}
