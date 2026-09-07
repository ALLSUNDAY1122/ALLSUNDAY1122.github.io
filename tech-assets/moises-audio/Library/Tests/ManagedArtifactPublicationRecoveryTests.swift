import Foundation
import XCTest

final class Lane2ManagedArtifactPublicationRecoveryTests: XCTestCase {
    func testPublishedPriorSessionIntentIsIndexedAndRetired() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/published.m4a"
        let oldJournal = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "old")
        _ = try oldJournal.begin(relativePath: path)
        try write(path, root: root, contents: "audio")
        try Lane2ManagedArtifactInventory(rootURL: root).markAuthoritativeAfterCompatibilityCensus()

        let report = try Lane2ManagedArtifactPublicationRecovery(
            rootURL: root,
            sessionID: "new"
        ).recoverPreviousSessionPublications(
            candidateLimit: 8,
            recordVisitLimit: 16,
            shardVisitLimit: Lane2ManagedArtifactPublicationJournal.shardCount
        )

        XCTAssertEqual(report.recoveredPublished, [path])
        XCTAssertFalse(try oldJournal.contains(relativePath: path))
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        let slice = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 0,
            now: Date(timeIntervalSince1970: 4_000_000),
            candidateLimit: 64,
            shardVisitLimit: Lane2ManagedArtifactInventory.shardCount
        )
        XCTAssertTrue(slice.candidates.contains { $0.relativePath == path })
    }

    func testMissingPriorSessionPublicationIsRetiredWithoutInventoryEntry() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/missing.m4a"
        let oldJournal = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "old")
        _ = try oldJournal.begin(relativePath: path)

        let report = try Lane2ManagedArtifactPublicationRecovery(
            rootURL: root,
            sessionID: "new"
        ).recoverPreviousSessionPublications(
            candidateLimit: 8,
            recordVisitLimit: 16,
            shardVisitLimit: Lane2ManagedArtifactPublicationJournal.shardCount
        )

        XCTAssertEqual(report.discardedMissing, [path])
        XCTAssertFalse(try oldJournal.contains(relativePath: path))
    }

    func testCurrentSessionIntentIsIgnored() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/current.m4a"
        let journal = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "current")
        _ = try journal.begin(relativePath: path)
        try write(path, root: root, contents: "audio")

        let report = try Lane2ManagedArtifactPublicationRecovery(
            rootURL: root,
            sessionID: "current"
        ).recoverPreviousSessionPublications(
            candidateLimit: 8,
            recordVisitLimit: 16,
            shardVisitLimit: Lane2ManagedArtifactPublicationJournal.shardCount
        )

        XCTAssertTrue(report.recoveredPublished.isEmpty)
        XCTAssertTrue(report.discardedMissing.isEmpty)
        XCTAssertTrue(try journal.contains(relativePath: path))
    }

    func testUnsafePublishedSymlinkRetainsIntentAndRevokesAuthority() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/link.m4a"
        let oldJournal = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "old")
        _ = try oldJournal.begin(relativePath: path)
        let outside = root.appendingPathComponent("outside.bin")
        try Data("outside".utf8).write(to: outside)
        let link = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: link.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        XCTAssertTrue(inventory.hasValidAuthoritativeMarker)

        let report = try Lane2ManagedArtifactPublicationRecovery(
            rootURL: root,
            sessionID: "new"
        ).recoverPreviousSessionPublications(
            candidateLimit: 8,
            recordVisitLimit: 16,
            shardVisitLimit: Lane2ManagedArtifactPublicationJournal.shardCount
        )

        XCTAssertEqual(report.retainedUnsafe, [path])
        XCTAssertTrue(report.authorityInvalidated)
        XCTAssertFalse(inventory.hasValidAuthoritativeMarker)
        XCTAssertTrue(try oldJournal.contains(relativePath: path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testRecoverySelectionIsBounded() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let old = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "old")
        for index in 0..<256 {
            _ = try old.begin(relativePath: "Imports/item-\(String(format: "%04d", index)).m4a")
        }
        let slice = try Lane2ManagedArtifactPublicationJournal(
            rootURL: root,
            sessionID: "new"
        ).preparePreviousSessionRecoverySlice(
            candidateLimit: 5,
            recordVisitLimit: 7,
            shardVisitLimit: 3
        )
        XCTAssertLessThanOrEqual(slice.records.count, 5)
        XCTAssertLessThanOrEqual(slice.visitedRecords, 7)
        XCTAssertLessThanOrEqual(slice.visitedShards, 3)
    }

    func testPriorSessionSamePathCannotBeOverwritten() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/conflict.m4a"
        _ = try Lane2ManagedArtifactPublicationJournal(
            rootURL: root,
            sessionID: "old"
        ).begin(relativePath: path)

        XCTAssertThrowsError(
            try Lane2ManagedArtifactPublicationJournal(
                rootURL: root,
                sessionID: "new"
            ).begin(relativePath: path)
        ) { error in
            XCTAssertEqual(
                error as? Lane2ManagedArtifactPublicationJournalFailure,
                .priorSessionIntentExists(path)
            )
        }
    }

    func testFinalizeImportLeavesIntentUntilReadinessThenCrashRecoveryCanAdopt() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories()
        let staged = store.stagingURL.appendingPathComponent("source.m4a")
        try Data("audio".utf8).write(to: staged)

        let finalized = try store.finalizeImport(stagingFile: staged, preferredName: "source")
        let currentJournal = Lane2ManagedArtifactPublicationJournal(rootURL: root)
        XCTAssertTrue(try currentJournal.contains(relativePath: finalized.relativePath))

        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        try lifecycle.requireReady(relativePath: finalized.relativePath)
        XCTAssertFalse(try currentJournal.contains(relativePath: finalized.relativePath))
        XCTAssertTrue(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)

        let staged2 = store.stagingURL.appendingPathComponent("crash.m4a")
        try Data("audio2".utf8).write(to: staged2)
        let crashed = try store.finalizeImport(stagingFile: staged2, preferredName: "crash")
        XCTAssertTrue(try currentJournal.contains(relativePath: crashed.relativePath))

        let report = try Lane2ManagedArtifactPublicationRecovery(
            rootURL: root,
            sessionID: "simulated-next-process"
        ).recoverPreviousSessionPublications(
            candidateLimit: 64,
            recordVisitLimit: 128,
            shardVisitLimit: Lane2ManagedArtifactPublicationJournal.shardCount
        )
        XCTAssertTrue(report.recoveredPublished.contains(crashed.relativePath))
        XCTAssertFalse(try currentJournal.contains(relativePath: crashed.relativePath))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW31Tests-" + UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ relativePath: String, root: URL, contents: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }
}
