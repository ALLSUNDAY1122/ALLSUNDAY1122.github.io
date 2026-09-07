import Foundation
import XCTest

final class Lane2ManagedArtifactInventoryShardPreflightTests: XCTestCase {
    func testSmallShardStaysAuthoritativeAndOversizedLimitFailsClosed() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Imports/a.m4a")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: url)
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: ["Imports/a.m4a"])
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        XCTAssertTrue(inventory.authoritativeShardPreflight(maximumEncodedBytes: 4096).safeForAuthoritativeDecode)
        XCTAssertFalse(inventory.authoritativeShardPreflight(maximumEncodedBytes: 8).safeForAuthoritativeDecode)
    }

    func testUnexpectedFilenameAndSymlinkFailClosed() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        let shards = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Shards", isDirectory: true)
        try Data("{}".utf8).write(to: shards.appendingPathComponent("bad.json"))
        XCTAssertFalse(inventory.authoritativeShardPreflight().safeForAuthoritativeDecode)
        try FileManager.default.removeItem(at: shards.appendingPathComponent("bad.json"))
        let target = root.appendingPathComponent("target.json")
        try Data("{}".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: shards.appendingPathComponent("00.json"), withDestinationURL: target)
        XCTAssertFalse(inventory.authoritativeShardPreflight().safeForAuthoritativeDecode)
        XCTAssertFalse(inventory.hasValidAuthoritativeMarker)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("L2AW38-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
