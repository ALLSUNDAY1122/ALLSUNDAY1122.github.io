import Foundation
import XCTest

final class ExportPublicationGuardTests: XCTestCase {
    private func withRoot(_ body: (URL, IOFileStore, IOExportBatchTransaction, Lane2ExportRegistrationJournal) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw17-test-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories()
        try body(root, store, IOExportBatchTransaction(fileStore: store), Lane2ExportRegistrationJournal(rootURL: root))
    }

    func testCommitPublishesMarkerThenJournalAdoptsIt() throws {
        try withRoot { _, _, tx, journal in
            let plan = try tx.prepare(suggestedFilenameStems: ["mix"], fileExtension: "m4a")
            try Data([1,2,3]).write(to: plan.items[0].stagingURL)
            let finalized = try tx.commit(plan)
            let marker = tx.finalizedBatchesURL.appendingPathComponent(plan.id).appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: [Lane2ExportRegistrationArtifact(relativePath: finalized[0].relativePath, mediaType: "audio/mp4")])
            XCTAssertTrue(journal.exists(intentID: intent.id))
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        }
    }

    func testOldSessionMarkerIsQuarantinedWithoutDeletingBytes() throws {
        try withRoot { root, _, tx, journal in
            let plan = try tx.prepare(suggestedFilenameStems: ["stem"], fileExtension: "m4a")
            try Data([9,8,7]).write(to: plan.items[0].stagingURL)
            _ = try tx.commit(plan)
            let batch = tx.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            try Data("old-session\n".utf8).write(to: batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename), options: [.atomic])
            let report = try journal.recoverPrejournalPublishedBatches()
            XCTAssertEqual(report.quarantinedBatchIDs, [plan.id])
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".LibraryRecovery/PrejournalExport/" + plan.id + "/" + plan.items[0].filename).path))
        }
    }

    func testCurrentSessionMarkerIsNotRacedByRecovery() throws {
        try withRoot { _, _, tx, journal in
            let plan = try tx.prepare(suggestedFilenameStems: ["stem"], fileExtension: "m4a")
            try Data([1]).write(to: plan.items[0].stagingURL)
            _ = try tx.commit(plan)
            let report = try journal.recoverPrejournalPublishedBatches()
            XCTAssertEqual(report.retainedCurrentSessionBatchIDs, [plan.id])
            XCTAssertTrue(report.quarantinedBatchIDs.isEmpty)
        }
    }

    func testPendingRecoversPreviousProcessMarkerBeforeJournalEnumeration() throws {
        try withRoot { _, _, tx, journal in
            let plan = try tx.prepare(suggestedFilenameStems: ["stem"], fileExtension: "m4a")
            try Data([1]).write(to: plan.items[0].stagingURL)
            let finalized = try tx.commit(plan)
            let batch = tx.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            try Data("previous\n".utf8).write(to: batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename), options: [.atomic])
            XCTAssertTrue(try journal.pending().isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: finalized[0].url.path))
        }
    }

    func testNonExportPathStillFailsClosed() throws {
        try withRoot { _, _, _, journal in
            XCTAssertThrowsError(try journal.prepare(projectUUID: UUID(), artifacts: [Lane2ExportRegistrationArtifact(relativePath: "Imports/x.m4a", mediaType: "audio/mp4")]))
        }
    }
}
