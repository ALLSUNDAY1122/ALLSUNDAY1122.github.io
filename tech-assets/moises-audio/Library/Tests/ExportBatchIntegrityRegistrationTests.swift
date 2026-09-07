import Foundation
import XCTest

final class Lane2ExportBatchIntegrityRegistrationTests: XCTestCase {
    func testAW35BatchIntegrityIsVerifiedBeforeMarkerClear() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(suggestedFilenameStems: ["vocals", "drums"], fileExtension: "m4a")
            try Data(repeating: 0x11, count: 1024).write(to: plan.items[0].stagingURL)
            try Data(repeating: 0x22, count: 1024).write(to: plan.items[1].stagingURL)
            let published = try transaction.commit(plan)
            let artifacts = published.map {
                Lane2ExportRegistrationArtifact(relativePath: $0.relativePath, mediaType: "audio/mp4")
            }
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: artifacts)
            XCTAssertTrue(journal.exists(intentID: intent.id))

            let batch = transaction.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename).path
                )
            )
        }
    }

    func testTamperedAW35BatchDoesNotClearMarkerOrPersistIntent() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(suggestedFilenameStems: ["mix"], fileExtension: "m4a")
            try Data(repeating: 0x33, count: 2048).write(to: plan.items[0].stagingURL)
            let published = try transaction.commit(plan)
            let handle = try FileHandle(forWritingTo: published[0].url)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([0xfe]))
            try handle.close()

            let artifact = Lane2ExportRegistrationArtifact(
                relativePath: published[0].relativePath,
                mediaType: "audio/mp4"
            )
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            XCTAssertThrowsError(try journal.prepare(projectUUID: UUID(), artifacts: [artifact])) { error in
                guard let failure = error as? Lane2ExportRegistrationJournalFailure,
                      case .publicationIntegrityFailed = failure else {
                    return XCTFail("unexpected error: \(error)")
                }
            }
            let batch = transaction.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename).path
                )
            )
        }
    }

    func testPreAW35BatchWithoutManifestRetainsCompatibilityRegistration() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            try store.prepareDirectories()
            let batchID = UUID().uuidString.lowercased()
            let batch = store.exportsURL
                .appendingPathComponent("Batches", isDirectory: true)
                .appendingPathComponent(batchID, isDirectory: true)
            try FileManager.default.createDirectory(at: batch, withIntermediateDirectories: true)
            let output = batch.appendingPathComponent("legacy.m4a")
            try Data(repeating: 0x44, count: 1024).write(to: output)
            let marker = batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
            XCTAssertTrue(
                FileManager.default.createFile(
                    atPath: marker.path,
                    contents: Data((IOExportBatchTransaction.publicationSessionID + "\n").utf8)
                )
            )
            let artifact = Lane2ExportRegistrationArtifact(
                relativePath: try store.relativePath(for: output),
                mediaType: "audio/mp4"
            )
            let journal = Lane2ExportRegistrationJournal(rootURL: root)
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: [artifact])
            XCTAssertTrue(journal.exists(intentID: intent.id))
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        }
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AW35Registration-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root)
    }
}
