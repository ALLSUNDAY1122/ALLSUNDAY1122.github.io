import Foundation
import XCTest

final class LibraryArtifactLifecycleTests: XCTestCase {
    func testPreparedJournalCannotDeleteBeforeCommit() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let file = try write("Imports/p/source.m4a", data: Data("audio".utf8), under: root)
            let project = UUID()
            try lifecycle.persistPreparedDeletion(projectUUID: project, relativePaths: ["Imports/p/source.m4a"])

            XCTAssertThrowsError(try lifecycle.executeCommittedDeletion(projectUUID: project))
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
            XCTAssertEqual(try lifecycle.pendingDeletionJournals().first?.phase, .prepared)
        }
    }

    func testCommittedJournalSurvivesArtifactDeletionUntilMetadataCompaction() throws {
        try withTempRoot { root in
            let first = LibraryArtifactLifecycle(rootURL: root)
            let source = try write("Imports/p/source.m4a", data: Data("source".utf8), under: root)
            let stem = try write("Stems/p/vocals.m4a", data: Data("stem".utf8), under: root)
            let project = UUID()
            try first.persistPreparedDeletion(projectUUID: project, relativePaths: ["Imports/p/source.m4a", "Stems/p/vocals.m4a"])
            try first.markDeletionCommitted(projectUUID: project)

            let relaunched = LibraryArtifactLifecycle(rootURL: root)
            XCTAssertEqual(try relaunched.pendingDeletionJournals().first?.phase, .committed)
            try relaunched.executeCommittedDeletion(projectUUID: project)
            try relaunched.executeCommittedDeletion(projectUUID: project)

            XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: stem.path))
            XCTAssertEqual(try relaunched.pendingDeletionJournals().first?.phase, .artifactsDeleted)

            try relaunched.completeMetadataCompaction(projectUUID: project)
            XCTAssertTrue(try relaunched.pendingDeletionJournals().isEmpty)
        }
    }

    func testMetadataCompactionCannotRetireCommittedJournalEarly() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let project = UUID()
            try lifecycle.persistCommittedDeletion(projectUUID: project, relativePaths: [])
            XCTAssertThrowsError(try lifecycle.completeMetadataCompaction(projectUUID: project)) { error in
                XCTAssertEqual(error as? LibraryArtifactFailure, .journalNotArtifactsDeleted(project))
            }
        }
    }

    func testCommittedBackfillRefusesPathMismatchAgainstExistingJournal() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let project = UUID()
            try lifecycle.persistPreparedDeletion(projectUUID: project, relativePaths: ["Imports/a/source.m4a"])
            XCTAssertThrowsError(
                try lifecycle.persistCommittedDeletion(
                    projectUUID: project,
                    relativePaths: ["Imports/b/source.m4a"]
                )
            ) { error in
                XCTAssertEqual(error as? LibraryArtifactFailure, .journalCorrupt(project.uuidString + ".json"))
            }
        }
    }

    func testPreparedIntentCanBeDiscardedWithoutDeletingLiveFiles() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let source = try write("Imports/live/source.m4a", data: Data("live".utf8), under: root)
            let project = UUID()
            try lifecycle.persistPreparedDeletion(projectUUID: project, relativePaths: ["Imports/live/source.m4a"])
            try lifecycle.discardPreparedDeletion(projectUUID: project)
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
            XCTAssertTrue(try lifecycle.pendingDeletionJournals().isEmpty)
        }
    }

    func testPromotionRejectsEmptyOrExistingFinalAndNeverExposesPartialFile() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            _ = try write("Staging/p/empty.part", data: Data(), under: root)
            XCTAssertThrowsError(try lifecycle.promoteReadyArtifact(stagingRelativePath: "Staging/p/empty.part", finalRelativePath: "Stems/p/vocals.m4a"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Stems/p/vocals.m4a").path))

            _ = try write("Staging/p/ready.part", data: Data("ready".utf8), under: root)
            _ = try write("Stems/p/vocals.m4a", data: Data("existing".utf8), under: root)
            XCTAssertThrowsError(try lifecycle.promoteReadyArtifact(stagingRelativePath: "Staging/p/ready.part", finalRelativePath: "Stems/p/vocals.m4a"))
        }
    }

    func testOrphanSweepRetainsReferencesAndYoungFiles() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let referenced = try write("Imports/keep.m4a", data: Data("keep".utf8), under: root)
            let orphan = try write("Exports/orphan.m4a", data: Data("old".utf8), under: root)
            let young = try write("Stems/young.m4a", data: Data("young".utf8), under: root)
            let oldDate = Date(timeIntervalSinceNow: -7200)
            try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: referenced.path)
            try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: orphan.path)

            let result = try lifecycle.sweepOrphans(referencedRelativePaths: ["Imports/keep.m4a"], gracePeriod: 3600, now: Date())
            XCTAssertEqual(result.removed, ["Exports/orphan.m4a"])
            XCTAssertTrue(FileManager.default.fileExists(atPath: referenced.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: young.path))
        }
    }

    func testTraversalIsRejectedForEveryDestructiveOperation() throws {
        try withTempRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            XCTAssertThrowsError(try lifecycle.requireReady(relativePath: "../outside"))
            XCTAssertThrowsError(try lifecycle.persistPreparedDeletion(projectUUID: UUID(), relativePaths: ["../../outside"]))
        }
    }

    private func withTempRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryArtifactTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    @discardableResult
    private func write(_ relativePath: String, data: Data, under root: URL) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }
}
