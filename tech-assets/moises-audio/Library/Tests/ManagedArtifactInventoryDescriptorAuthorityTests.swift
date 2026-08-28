import Foundation
import XCTest

final class Lane2ManagedArtifactInventoryDescriptorAuthorityTests: XCTestCase {
    func testAuthoritativeMarkerAndCursorRoundTripRemainUsable() throws {
        let root = try makeRoot(prefix: "roundtrip")
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 8_000_000)
        let relativePath = try pathInShard(0, stem: "roundtrip")
        try writeArtifact(
            relativePath,
            root: root,
            modified: now.addingTimeInterval(-7200)
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: [relativePath])
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        XCTAssertTrue(inventory.isAuthoritative)

        let first = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 1,
            shardVisitLimit: 1
        )
        try inventory.persistTraversal(after: first)

        let second = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 1,
            shardVisitLimit: 1
        )
        XCTAssertEqual(second.priorTraversal, first.nextTraversal)
        XCTAssertTrue(inventory.isAuthoritative)
    }

    func testAuthoritativeMarkerCannotBorrowAuthorityFromSymlinkTarget() throws {
        let root = try makeRoot(prefix: "marker-root")
        let external = try makeRoot(prefix: "marker-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        let v1 = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: v1, withIntermediateDirectories: true)
        let externalMarker = external.appendingPathComponent("authoritative")
        let markerBytes = Data("lane2-managed-artifact-inventory-v1\n".utf8)
        try markerBytes.write(to: externalMarker)
        let marker = v1.appendingPathComponent("authoritative")
        try FileManager.default.createSymbolicLink(
            at: marker,
            withDestinationURL: externalMarker
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertFalse(inventory.isAuthoritative)
        XCTAssertThrowsError(try inventory.markAuthoritativeAfterCompatibilityCensus())
        XCTAssertEqual(try Data(contentsOf: externalMarker), markerBytes)
        let attributes = try FileManager.default.attributesOfItem(atPath: marker.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testCursorSymlinkLeafFailsClosedWithoutMutatingExternalTarget() throws {
        let root = try makeRoot(prefix: "cursor-root")
        let external = try makeRoot(prefix: "cursor-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let now = Date(timeIntervalSince1970: 8_100_000)
        let relativePath = try pathInShard(0, stem: "cursor")
        try writeArtifact(
            relativePath,
            root: root,
            modified: now.addingTimeInterval(-7200)
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: [relativePath])
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        let first = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 1,
            shardVisitLimit: 1
        )
        try inventory.persistTraversal(after: first)

        let cursor = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1/cursor.json"
        )
        try FileManager.default.removeItem(at: cursor)
        let externalCursor = external.appendingPathComponent("cursor.json")
        let sentinel = Data("must-survive".utf8)
        try sentinel.write(to: externalCursor)
        try FileManager.default.createSymbolicLink(
            at: cursor,
            withDestinationURL: externalCursor
        )

        XCTAssertThrowsError(
            try inventory.prepareOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                candidateLimit: 1,
                shardVisitLimit: 1
            )
        ) { error in
            XCTAssertEqual(
                error as? Lane2ManagedArtifactInventoryFailure,
                .corruptTraversalCursor
            )
        }
        XCTAssertEqual(try Data(contentsOf: externalCursor), sentinel)
    }

    func testDescriptorEnumeratorDoesNotFollowDescendantSymlink() throws {
        let root = try makeRoot(prefix: "enumeration-root")
        let external = try makeRoot(prefix: "enumeration-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        let externalFile = external.appendingPathComponent("borrowed.m4a")
        try Data("external-must-not-be-enumerated".utf8).write(to: externalFile)
        let link = imports.appendingPathComponent("borrowed-dir", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)

        let enumerator = Lane2ManagedArtifactInventoryDescriptorEnumerator(rootURL: root)
        let entries = try enumerator.visibleEntriesRecursively(in: imports)

        XCTAssertTrue(entries.contains {
            $0.relativePath == "Imports/borrowed-dir" && $0.kind == .symbolicLink
        })
        XCTAssertFalse(entries.contains {
            $0.relativePath == "Imports/borrowed-dir/borrowed.m4a"
        })
        XCTAssertEqual(try Data(contentsOf: externalFile), Data("external-must-not-be-enumerated".utf8))
    }

    func testFreshActivationAcceptsOnlySingleDescriptorEnumeratedRegularFile() throws {
        let root = try makeRoot(prefix: "activation-single")
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("Imports/session/first.m4a")
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("managed".utf8).write(to: target)

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertTrue(
            try inventory.activateForFirstManagedArtifactIfSafe(
                relativePath: "Imports/session/first.m4a"
            )
        )
        XCTAssertTrue(inventory.isAuthoritative)
    }

    func testFreshActivationRejectsDescendantSymlinkWithoutBorrowingExternalTree() throws {
        let root = try makeRoot(prefix: "activation-symlink-root")
        let external = try makeRoot(prefix: "activation-symlink-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        let target = imports.appendingPathComponent("first.m4a")
        try Data("managed".utf8).write(to: target)
        let externalFile = external.appendingPathComponent("second.m4a")
        let sentinel = Data("external-must-survive".utf8)
        try sentinel.write(to: externalFile)
        try FileManager.default.createSymbolicLink(
            at: imports.appendingPathComponent("borrowed", isDirectory: true),
            withDestinationURL: external
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertFalse(
            try inventory.activateForFirstManagedArtifactIfSafe(
                relativePath: "Imports/first.m4a"
            )
        )
        XCTAssertFalse(inventory.isAuthoritative)
        XCTAssertEqual(try Data(contentsOf: externalFile), sentinel)
    }

    private func makeRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2InventoryDescriptorAuthority-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeArtifact(
        _ relativePath: String,
        root: URL,
        modified: Date
    ) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: modified],
            ofItemAtPath: url.path
        )
    }

    private func pathInShard(_ desiredShard: Int, stem: String) throws -> String {
        var index = 0
        while true {
            let path = "Imports/\(stem)-\(index).m4a"
            if try Lane2ManagedArtifactInventory.shardIndex(for: path) == desiredShard {
                return path
            }
            index += 1
        }
    }
}
