import Foundation
import XCTest

final class ManagedArtifactSegmentedSteadyStatePathAuthorityTests: XCTestCase {
    private let fm = FileManager.default

    func testRuntimeDanglingManifestDoesNotFallBackToLegacy() throws {
        let root = try makeRoot("runtime-dangling"); defer { cleanup(root) }
        let path = "Imports/a.m4a", shard = shardIndex(path)
        try makeArtifact(root, path)
        try fm.createDirectory(at: segmented(root), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: manifest(root, shard), withDestinationURL: root.appendingPathComponent("missing"))
        XCTAssertThrowsError(try Lane2ManagedArtifactSegmentedRuntime(rootURL: root).authority(forShard: shard))
    }

    func testRuntimeRejectsManagedArtifactAncestorSymlink() throws {
        let root = try makeRoot("runtime-parent"); defer { cleanup(root) }
        let external = try makeRoot("runtime-external"); defer { cleanup(external) }
        let target = external.appendingPathComponent("a.m4a")
        try Data([7]).write(to: target)
        try fm.createSymbolicLink(at: root.appendingPathComponent("Imports", isDirectory: true), withDestinationURL: external)
        XCTAssertThrowsError(try Lane2ManagedArtifactSegmentedRuntime(rootURL: root).upsertManaged(relativePaths: ["Imports/a.m4a"]))
        let kept = try Data(contentsOf: target)
        XCTAssertEqual(kept, Data([7]))
    }

    func testRuntimeRejectsSegmentedRootSymlinkPublication() throws {
        let root = try makeRoot("runtime-segmented-root"); defer { cleanup(root) }
        let external = try makeRoot("runtime-segmented-external"); defer { cleanup(external) }
        try makeArtifact(root, "Imports/a.m4a")
        try fm.createDirectory(at: segmented(root).deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: segmented(root), withDestinationURL: external)
        XCTAssertThrowsError(try Lane2ManagedArtifactSegmentedRuntime(rootURL: root).upsertManaged(relativePaths: ["Imports/a.m4a"]))
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testRuntimeRejectsCommittedSegmentSymlink() throws {
        let root = try makeRoot("runtime-segment"); defer { cleanup(root) }
        let external = try makeRoot("runtime-segment-external"); defer { cleanup(external) }
        let path = "Imports/a.m4a", shard = shardIndex(path)
        try makeArtifact(root, path)
        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        try runtime.upsertManaged(relativePaths: [path])
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: manifest(root, shard))) as? [String: Any])
        let generation = try XCTUnwrap(object["generation"] as? String)
        let segment = segmented(root).appendingPathComponent(String(format: "%02x.%@.%04d.json", shard, generation, 0))
        try fm.removeItem(at: segment)
        let target = external.appendingPathComponent("keep.json")
        try Data("keep".utf8).write(to: target)
        try fm.createSymbolicLink(at: segment, withDestinationURL: target)
        XCTAssertThrowsError(try runtime.loadShard(shard))
        XCTAssertEqual(try Data(contentsOf: target), Data("keep".utf8))
    }

    func testBoundedMutationDanglingManifestDoesNotFallback() throws {
        let root = try makeRoot("bounded-dangling"); defer { cleanup(root) }
        let path = "Exports/a.m4a", shard = shardIndex(path)
        try makeArtifact(root, path)
        try fm.createDirectory(at: segmented(root), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: manifest(root, shard), withDestinationURL: root.appendingPathComponent("missing"))
        XCTAssertThrowsError(try Lane2ManagedArtifactSegmentedBoundedMutation(rootURL: root).upsertManaged(relativePaths: [path]))
    }

    func testBoundedMutationRejectsManagedArtifactAncestorSymlink() throws {
        let root = try makeRoot("bounded-parent"); defer { cleanup(root) }
        let external = try makeRoot("bounded-parent-external"); defer { cleanup(external) }
        let target = external.appendingPathComponent("a.m4a")
        try Data([4]).write(to: target)
        try fm.createSymbolicLink(at: root.appendingPathComponent("Stems", isDirectory: true), withDestinationURL: external)
        XCTAssertThrowsError(try Lane2ManagedArtifactSegmentedBoundedMutation(rootURL: root).upsertManaged(relativePaths: ["Stems/a.m4a"]))
        XCTAssertEqual(try Data(contentsOf: target), Data([4]))
    }

    func testBoundedMutationRejectsManifestSymlinkReplacement() throws {
        let root = try makeRoot("bounded-manifest"); defer { cleanup(root) }
        let external = try makeRoot("bounded-manifest-external"); defer { cleanup(external) }
        let path = "Imports/a.m4a", shard = shardIndex(path)
        try makeArtifact(root, path)
        try Lane2ManagedArtifactSegmentedRuntime(rootURL: root).upsertManaged(relativePaths: [path])
        try fm.removeItem(at: manifest(root, shard))
        let target = external.appendingPathComponent("manifest.json")
        try Data("keep".utf8).write(to: target)
        try fm.createSymbolicLink(at: manifest(root, shard), withDestinationURL: target)
        XCTAssertThrowsError(try Lane2ManagedArtifactSegmentedBoundedMutation(rootURL: root).upsertManaged(relativePaths: [path]))
        XCTAssertEqual(try Data(contentsOf: target), Data("keep".utf8))
    }

    func testNormalRuntimeBoundedUpdateAndRemoveRemainConvergent() throws {
        let root = try makeRoot("normal"); defer { cleanup(root) }
        let path = "Imports/a.m4a", shard = shardIndex(path)
        try makeArtifact(root, path, bytes: [1])
        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        try runtime.upsertManaged(relativePaths: [path])
        try Data([2, 3]).write(to: root.appendingPathComponent(path))
        let bounded = Lane2ManagedArtifactSegmentedBoundedMutation(rootURL: root)
        let metrics = try bounded.upsertManaged(relativePaths: [path])
        XCTAssertEqual(metrics.generationsPublished, 1)
        XCTAssertLessThanOrEqual(metrics.maximumDecodedSegmentEntries, 512)
        XCTAssertEqual(try runtime.loadShard(shard).map(\.relativePath), [path])
        _ = try bounded.removeManaged(relativePaths: [path])
        XCTAssertEqual(try runtime.authority(forShard: shard), .segmentedCommitted)
        XCTAssertTrue(try runtime.loadShard(shard).isEmpty)
    }

    private func makeRoot(_ tag: String) throws -> URL {
        let url = fm.temporaryDirectory.appendingPathComponent("aw53-tests-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func cleanup(_ url: URL) { try? fm.removeItem(at: url) }
    private func segmented(_ root: URL) -> URL { root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true) }
    private func manifest(_ root: URL, _ shard: Int) -> URL { segmented(root).appendingPathComponent(String(format: "%02x.manifest.json", shard)) }
    private func makeArtifact(_ root: URL, _ path: String, bytes: [UInt8] = [1]) throws { let url = root.appendingPathComponent(path); try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try Data(bytes).write(to: url) }
    private func shardIndex(_ path: String) -> Int { var hash: UInt64 = 14_695_981_039_346_656_037; for byte in path.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }; return Int(hash % 256) }
}
