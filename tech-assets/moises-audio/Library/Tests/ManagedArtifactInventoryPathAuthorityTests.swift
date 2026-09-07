import Foundation
import XCTest

final class Lane2ManagedArtifactInventoryPathAuthorityTests: XCTestCase {
    func testDanglingAuthoritativeMarkerIsNotAuthorityAndCannotBeOverwritten() throws {
        let root = try makeRoot(prefix: "marker")
        defer { try? FileManager.default.removeItem(at: root) }
        let v1 = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: v1, withIntermediateDirectories: true)
        let marker = v1.appendingPathComponent("authoritative")
        let missing = root.appendingPathComponent("outside-missing-marker")
        try FileManager.default.createSymbolicLink(at: marker, withDestinationURL: missing)

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertFalse(inventory.isAuthoritative)
        XCTAssertThrowsError(try inventory.markAuthoritativeAfterCompatibilityCensus()) { error in
            guard case Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: marker.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testSymlinkManagedRootPreventsFreshActivation() throws {
        let root = try makeRoot(prefix: "activation-root")
        let external = try makeRoot(prefix: "activation-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let externalFile = external.appendingPathComponent("first.m4a")
        try Data("external".utf8).write(to: externalFile)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Imports", isDirectory: true),
            withDestinationURL: external
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertThrowsError(
            try inventory.activateForFirstManagedArtifactIfSafe(relativePath: "Imports/first.m4a")
        ) { error in
            guard case Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertFalse(inventory.isAuthoritative)
        XCTAssertEqual(try Data(contentsOf: externalFile), Data("external".utf8))
    }

    func testOrphanApplyRejectsManagedRootSubstitutionWithoutDeletingExternalTarget() throws {
        let root = try makeRoot(prefix: "orphan-root")
        let external = try makeRoot(prefix: "orphan-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let now = Date(timeIntervalSince1970: 5_000_000)
        let relativePath = try pathInShard(0, stem: "orphan")
        let internalURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: internalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("internal".utf8).write(to: internalURL)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-7200)],
            ofItemAtPath: internalURL.path
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: [relativePath])
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        let slice = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 1,
            shardVisitLimit: 1
        )
        XCTAssertEqual(slice.candidates.map(\.relativePath), [relativePath])

        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.removeItem(at: imports)
        let externalTarget = external.appendingPathComponent(
            String(relativePath.split(separator: "/").last!),
            isDirectory: false
        )
        try Data("must-survive".utf8).write(to: externalTarget)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-7200)],
            ofItemAtPath: externalTarget.path
        )
        try FileManager.default.createSymbolicLink(at: imports, withDestinationURL: external)

        XCTAssertThrowsError(
            try inventory.applyOrphanCandidateSlice(
                slice,
                referencedRelativePaths: [],
                gracePeriod: 3600,
                now: now
            )
        ) { error in
            guard case Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: externalTarget), Data("must-survive".utf8))
    }

    func testOrphanApplyRetainsChangedModificationWitnessEvenWhenReplacementIsOld() throws {
        let root = try makeRoot(prefix: "orphan-witness")
        defer { try? FileManager.default.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 7_000_000)
        let originalModification = now.addingTimeInterval(-7200)
        let replacementModification = now.addingTimeInterval(-7100)
        let relativePath = try pathInShard(0, stem: "witness")
        let file = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("original".utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: originalModification],
            ofItemAtPath: file.path
        )

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: [relativePath])
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        let slice = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 1,
            shardVisitLimit: 1
        )
        let firstCandidate = try XCTUnwrap(slice.candidates.first)
        XCTAssertEqual(firstCandidate.relativePath, relativePath)
        XCTAssertEqual(
            firstCandidate.recordedModificationTime,
            originalModification.timeIntervalSince1970,
            accuracy: 0.001
        )

        try Data("replacement".utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: replacementModification],
            ofItemAtPath: file.path
        )
        XCTAssertGreaterThan(now.timeIntervalSince(replacementModification), 3600)

        let result = try inventory.applyOrphanCandidateSlice(
            slice,
            referencedRelativePaths: [],
            gracePeriod: 3600,
            now: now
        )
        XCTAssertTrue(result.removed.isEmpty)
        XCTAssertEqual(result.retainedYoung, 1)
        XCTAssertEqual(try Data(contentsOf: file), Data("replacement".utf8))

        let refreshed = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 1,
            shardVisitLimit: 1
        )
        let refreshedCandidate = try XCTUnwrap(refreshed.candidates.first)
        XCTAssertEqual(refreshedCandidate.relativePath, relativePath)
        XCTAssertEqual(
            refreshedCandidate.recordedModificationTime,
            replacementModification.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testCursorPersistenceRejectsSymlinkedV1AncestorWithoutExternalWrite() throws {
        let root = try makeRoot(prefix: "cursor-root")
        let external = try makeRoot(prefix: "cursor-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        let slice = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 0,
            now: Date(),
            candidateLimit: 1,
            shardVisitLimit: 1
        )

        let v1 = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1",
            isDirectory: true
        )
        let displacedV1 = external.appendingPathComponent("displaced-v1", isDirectory: true)
        try FileManager.default.moveItem(at: v1, to: displacedV1)
        try FileManager.default.createSymbolicLink(at: v1, withDestinationURL: displacedV1)
        let externalCursor = displacedV1.appendingPathComponent("cursor.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: externalCursor.path))

        XCTAssertThrowsError(try inventory.persistTraversal(after: slice)) { error in
            XCTAssertEqual(
                error as? Lane2ManagedArtifactInventoryFailure,
                .corruptTraversalCursor
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: externalCursor.path))
    }

    func testStreamingTraversalRejectsSymlinkedSegmentedAncestor() throws {
        let root = try makeRoot(prefix: "stream-root")
        let external = try makeRoot(prefix: "stream-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let now = Date(timeIntervalSince1970: 6_000_000)
        let relativePath = try pathInShard(0, stem: "stream")
        let file = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-7200)],
            ofItemAtPath: file.path
        )
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: [relativePath])
        try inventory.markAuthoritativeAfterCompatibilityCensus()

        let segmented = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1/Segmented",
            isDirectory: true
        )
        let displaced = external.appendingPathComponent("segmented", isDirectory: true)
        try FileManager.default.moveItem(at: segmented, to: displaced)
        try FileManager.default.createSymbolicLink(at: segmented, withDestinationURL: displaced)

        XCTAssertThrowsError(
            try inventory.prepareOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                candidateLimit: 1,
                shardVisitLimit: 1
            )
        )
    }

    private func makeRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2InventoryAuthority-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
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
