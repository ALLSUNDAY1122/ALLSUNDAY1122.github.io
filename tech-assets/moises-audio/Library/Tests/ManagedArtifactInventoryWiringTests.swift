import Foundation
import XCTest

final class Lane2ManagedArtifactInventoryWiringTests: XCTestCase {
    func testRequireReadyActivatesFreshInventoryAndBoundedSweepUsesIt() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = now.addingTimeInterval(-7200)

        try write("Imports/first.m4a", root: root, modified: old)
        try lifecycle.requireReady(relativePath: "Imports/first.m4a")
        XCTAssertTrue(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)

        for index in 0..<32 {
            let path = "Stems/stem-\(index).m4a"
            try write(path, root: root, modified: old)
            try lifecycle.requireReady(relativePath: path)
        }

        let slice = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 8
        )
        XCTAssertTrue(slice.usesManagedArtifactInventory)
        XCTAssertLessThanOrEqual(slice.candidates.count, 8)
        XCTAssertLessThanOrEqual(
            try XCTUnwrap(slice.inventorySlice).visitedShards,
            Lane2ManagedArtifactInventory.defaultShardVisitLimit
        )
    }

    func testUpgradeWithMultiplePreexistingFilesStaysOnFilesystemCompatibilityPath() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let old = Date(timeIntervalSince1970: 1_000_000)
        let now = Date(timeIntervalSince1970: 2_000_000)

        try write("Imports/existing-a.m4a", root: root, modified: old)
        try write("Stems/existing-b.m4a", root: root, modified: old)
        try lifecycle.requireReady(relativePath: "Imports/existing-a.m4a")

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertFalse(inventory.hasValidAuthoritativeMarker)
        let slice = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 1
        )
        XCTAssertFalse(slice.usesManagedArtifactInventory)
        XCTAssertGreaterThanOrEqual(slice.scannedRegularFiles, 2)
    }

    func testMalformedAuthoritativeMarkerFailsBackToFilesystemCompatibility() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let old = Date(timeIntervalSince1970: 1_000_000)
        let now = Date(timeIntervalSince1970: 2_000_000)
        try write("Imports/existing.m4a", root: root, modified: old)
        let marker = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1/authoritative"
        )
        try FileManager.default.createDirectory(
            at: marker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("corrupt".utf8).write(to: marker)

        XCTAssertFalse(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
        let slice = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 1
        )
        XCTAssertFalse(slice.usesManagedArtifactInventory)
        XCTAssertEqual(slice.candidates.first?.relativePath, "Imports/existing.m4a")
    }

    func testReadyStagingOutsideManagedRootsDoesNotEnterInventory() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let path = "Staging/temp.m4a"
        try write(path, root: root, modified: Date())
        try lifecycle.requireReady(relativePath: path)
        XCTAssertFalse(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW29Wiring-" + UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ relativePath: String, root: URL, modified: Date) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }
}
