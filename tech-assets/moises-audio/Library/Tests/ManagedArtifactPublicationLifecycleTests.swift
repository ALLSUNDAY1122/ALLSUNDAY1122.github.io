import Foundation
import XCTest

final class Lane2ManagedArtifactPublicationLifecycleTests: XCTestCase {
    func testFinalizeImportKeepsIntentUntilLibraryReadiness() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories()
        let staged = store.stagingURL.appendingPathComponent("input.m4a")
        try Data("audio".utf8).write(to: staged)

        let final = try store.finalizeImport(stagingFile: staged, preferredName: "input")
        let journal = Lane2ManagedArtifactPublicationJournal(rootURL: root)
        XCTAssertTrue(try journal.contains(relativePath: final.relativePath))

        try LibraryArtifactLifecycle(rootURL: root).requireReady(relativePath: final.relativePath)
        XCTAssertFalse(try journal.contains(relativePath: final.relativePath))
    }

    func testRemoveIfExistsRetiresCurrentSessionIntentOnlyAfterFileIsGone() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories()
        let staged = store.stagingURL.appendingPathComponent("rollback.m4a")
        try Data("audio".utf8).write(to: staged)

        let final = try store.finalizeExport(stagingFile: staged, preferredName: "rollback")
        let journal = Lane2ManagedArtifactPublicationJournal(rootURL: root)
        XCTAssertTrue(try journal.contains(relativePath: final.relativePath))
        store.removeIfExists(final.url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: final.url.path))
        XCTAssertFalse(try journal.contains(relativePath: final.relativePath))
    }

    func testManagedPromotionRegistersBeforeIntentRetirement() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let stagedPath = "Staging/stem.partial"
        let finalPath = "Stems/vocals.m4a"
        let staged = root.appendingPathComponent(stagedPath)
        try FileManager.default.createDirectory(
            at: staged.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("stem".utf8).write(to: staged)

        try lifecycle.promoteReadyArtifact(
            stagingRelativePath: stagedPath,
            finalRelativePath: finalPath
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(finalPath).path))
        XCTAssertFalse(
            try Lane2ManagedArtifactPublicationJournal(rootURL: root).contains(relativePath: finalPath)
        )
        XCTAssertTrue(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    func testNonManagedPromotionRetainsLegacyBehaviorWithoutPublicationJournal() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let stagedPath = "Staging/recovery.partial"
        let finalPath = "Recovery/recovery.bin"
        let staged = root.appendingPathComponent(stagedPath)
        try FileManager.default.createDirectory(
            at: staged.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("payload".utf8).write(to: staged)

        try lifecycle.promoteReadyArtifact(
            stagingRelativePath: stagedPath,
            finalRelativePath: finalPath
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(finalPath).path))
        XCTAssertFalse(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW31Lifecycle-" + UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
