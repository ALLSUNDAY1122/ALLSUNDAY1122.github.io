import Foundation
import XCTest

final class Lane2ExportRegistrationIntegrityRevalidationTests: XCTestCase {
    func testValidAW35IntentRevalidates() throws {
        try withPublishedBatch { root, transaction, plan, published in
            let intent = try makeIntent(root: root, published: published)
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            XCTAssertNoThrow(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
            XCTAssertTrue(journal.exists(intentID: intent.id))
            _ = transaction
            _ = plan
        }
    }

    func testByteGrowthAfterPrepareFailsClosedAndKeepsIntent() throws {
        try withPublishedBatch { root, _, _, published in
            let intent = try makeIntent(root: root, published: published)
            let handle = try FileHandle(forWritingTo: published[0].url)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([0xaa]))
            try handle.close()
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            assertIntegrityFailure(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
            XCTAssertTrue(journal.exists(intentID: intent.id))
        }
    }

    func testSameSizeMutationAfterPrepareFailsClosedAndKeepsIntent() throws {
        try withPublishedBatch { root, _, _, published in
            let intent = try makeIntent(root: root, published: published)
            var bytes = try Data(contentsOf: published[0].url)
            bytes[0] ^= 0xff
            try bytes.write(to: published[0].url, options: [.atomic])
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            assertIntegrityFailure(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
            XCTAssertTrue(journal.exists(intentID: intent.id))
        }
    }

    func testSymlinkReplacementAfterPrepareFailsClosedAndKeepsIntent() throws {
        try withPublishedBatch { root, _, _, published in
            let intent = try makeIntent(root: root, published: published)
            let original = published[0].url
            let replacement = root.appendingPathComponent("replacement.m4a")
            try Data(repeating: 0x11, count: 4096).write(to: replacement)
            try FileManager.default.removeItem(at: original)
            try FileManager.default.createSymbolicLink(at: original, withDestinationURL: replacement)
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            assertIntegrityFailure(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
            XCTAssertTrue(journal.exists(intentID: intent.id))
        }
    }

    func testUnexpectedFileAfterPrepareFailsClosedAndKeepsIntent() throws {
        try withPublishedBatch { root, _, plan, published in
            let intent = try makeIntent(root: root, published: published)
            let batch = root
                .appendingPathComponent("Exports", isDirectory: true)
                .appendingPathComponent("Batches", isDirectory: true)
                .appendingPathComponent(plan.id, isDirectory: true)
            try Data([0x01]).write(to: batch.appendingPathComponent("injected.bin"))
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            assertIntegrityFailure(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
            XCTAssertTrue(journal.exists(intentID: intent.id))
        }
    }

    func testManifestCorruptionAfterPrepareFailsClosedAndKeepsIntent() throws {
        try withPublishedBatch { root, _, plan, published in
            let intent = try makeIntent(root: root, published: published)
            let manifest = root
                .appendingPathComponent("Exports", isDirectory: true)
                .appendingPathComponent("Batches", isDirectory: true)
                .appendingPathComponent(plan.id, isDirectory: true)
                .appendingPathComponent(IOExportBatchTransaction.integrityManifestFilename)
            try Data("{broken".utf8).write(to: manifest, options: [.atomic])
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            assertIntegrityFailure(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
            XCTAssertTrue(journal.exists(intentID: intent.id))
        }
    }

    func testLegacyNoManifestRemainsCompatible() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            try store.prepareDirectories()
            let batchID = UUID().uuidString.lowercased()
            let batch = store.exportsURL
                .appendingPathComponent("Batches", isDirectory: true)
                .appendingPathComponent(batchID, isDirectory: true)
            try FileManager.default.createDirectory(at: batch, withIntermediateDirectories: true)
            let output = batch.appendingPathComponent("legacy.m4a")
            try Data(repeating: 0x55, count: 512).write(to: output)
            let artifact = Lane2ExportRegistrationArtifact(
                relativePath: try store.relativePath(for: output),
                mediaType: "audio/mp4"
            )
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: [artifact])
            XCTAssertNoThrow(try journal.revalidatePublishedBatchIntegrityIfPresent(intent: intent))
        }
    }

    private func makeIntent(
        root: URL,
        published: [IOFileStore.FinalizedFile]
    ) throws -> Lane2ExportRegistrationIntent {
        let journal = Lane2ExportRegistrationJournal(rootURL: root)
        return try journal.prepare(
            projectUUID: UUID(),
            artifacts: published.map {
                Lane2ExportRegistrationArtifact(relativePath: $0.relativePath, mediaType: "audio/mp4")
            }
        )
    }

    private func assertIntegrityFailure<T>(_ expression: @autoclosure () throws -> T) {
        XCTAssertThrowsError(try expression()) { error in
            guard let failure = error as? Lane2ExportRegistrationJournalFailure,
                  case .publicationIntegrityFailed = failure else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    private func withPublishedBatch(
        _ body: (URL, IOExportBatchTransaction, IOExportBatchTransaction.Plan, [IOFileStore.FinalizedFile]) throws -> Void
    ) throws {
        try withRoot { root in
            let transaction = IOExportBatchTransaction(fileStore: IOFileStore(rootURL: root))
            let plan = try transaction.prepare(suggestedFilenameStems: ["mix"], fileExtension: "m4a")
            try Data(repeating: 0x11, count: 4096).write(to: plan.items[0].stagingURL)
            let published = try transaction.commit(plan)
            try body(root, transaction, plan, published)
        }
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AW36Registration-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root)
    }
}
