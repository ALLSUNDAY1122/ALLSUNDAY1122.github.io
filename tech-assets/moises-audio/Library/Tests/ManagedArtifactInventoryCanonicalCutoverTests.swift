import Foundation
import XCTest

final class ManagedArtifactInventoryCanonicalCutoverTests: XCTestCase {
    func testCanonicalFacadePromotesLegacyCompatiblePathToSegmentedRuntime() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        let artifact = imports.appendingPathComponent("song.wav")
        try Data([1, 2, 3, 4]).write(to: artifact)

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        XCTAssertTrue(try inventory.registerIfManaged(relativePath: "Imports/song.wav"))

        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        let shard = try Lane2ManagedArtifactInventory.shardIndex(for: "Imports/song.wav")
        XCTAssertEqual(try runtime.authority(forShard: shard), .segmentedCommitted)
        XCTAssertEqual(try runtime.loadShard(shard).map(\.relativePath), ["Imports/song.wav"])
    }

    func testPrepareDoesNotAdvanceCursorUntilExplicitPersist() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.markAuthoritativeAfterCompatibilityCensus()

        let first = try inventory.prepareOrphanCandidateSlice(candidateLimit: 1, shardVisitLimit: 1)
        let second = try inventory.prepareOrphanCandidateSlice(candidateLimit: 1, shardVisitLimit: 1)
        XCTAssertEqual(first.priorTraversal, second.priorTraversal)
        XCTAssertEqual(first.nextTraversal, second.nextTraversal)

        try inventory.persistTraversal(after: first)
        let third = try inventory.prepareOrphanCandidateSlice(candidateLimit: 1, shardVisitLimit: 1)
        XCTAssertEqual(third.priorTraversal, first.nextTraversal)
    }

    func testFinalRemovalKeepsSegmentedZeroEntryAuthority() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        let artifact = imports.appendingPathComponent("remove.wav")
        try Data([7]).write(to: artifact)

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        try inventory.registerManaged(relativePaths: ["Imports/remove.wav"])
        let shard = try Lane2ManagedArtifactInventory.shardIndex(for: "Imports/remove.wav")
        try inventory.remove(relativePaths: ["Imports/remove.wav"])

        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        XCTAssertEqual(try runtime.authority(forShard: shard), .segmentedCommitted)
        XCTAssertTrue(try runtime.loadShard(shard).isEmpty)
    }

    func testUnsafeSymlinkRegistrationFailsClosed() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("target.wav")
        try Data([9]).write(to: target)
        try FileManager.default.createSymbolicLink(at: imports.appendingPathComponent("link.wav"), withDestinationURL: target)

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertThrowsError(try inventory.registerIfManaged(relativePath: "Imports/link.wav"))
    }

    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lane2-aw42-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
