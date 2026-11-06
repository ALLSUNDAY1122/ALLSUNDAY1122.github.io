import Foundation
import XCTest

final class ExportRegistrationPathAuthorityTests: XCTestCase {
    private let fm = FileManager.default

    func testGenuinelyMissingIntegrityManifestRetainsLegacyCompatibility() throws {
        let root = try makeRoot()
        defer { try? fm.removeItem(at: root.deletingLastPathComponent()) }

        let batch = root.appendingPathComponent("Exports/Batches/legacy", isDirectory: true)
        try fm.createDirectory(at: batch, withIntermediateDirectories: true)
        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)

        let intent = try journal.prepare(
            projectUUID: UUID(),
            artifacts: [.init(relativePath: "Exports/Batches/legacy/Mix.m4a", mediaType: "audio/mp4")]
        )

        XCTAssertTrue(journal.exists(intentID: intent.id))
    }

    func testDanglingIntegrityManifestCannotMasqueradeAsLegacyAbsence() throws {
        let root = try makeRoot()
        defer { try? fm.removeItem(at: root.deletingLastPathComponent()) }

        let batch = root.appendingPathComponent("Exports/Batches/dangling", isDirectory: true)
        try fm.createDirectory(at: batch, withIntermediateDirectories: true)
        let manifest = batch.appendingPathComponent(IOExportBatchTransaction.integrityManifestFilename)
        let externalMissing = root.deletingLastPathComponent().appendingPathComponent("missing-manifest.json")
        try fm.createSymbolicLink(at: manifest, withDestinationURL: externalMissing)

        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(
            try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/Batches/dangling/Vocals.m4a", mediaType: "audio/mp4")]
            )
        ) { error in
            guard case Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testRegistrationDirectorySymlinkCannotRedirectIntentWrite() throws {
        let root = try makeRoot()
        let base = root.deletingLastPathComponent()
        defer { try? fm.removeItem(at: base) }

        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        let recovery = root.appendingPathComponent(".LibraryRecovery", isDirectory: true)
        try fm.createDirectory(at: recovery, withIntermediateDirectories: true)
        let registration = recovery.appendingPathComponent("ExportRegistration", isDirectory: true)
        try fm.createSymbolicLink(at: registration, withDestinationURL: external)

        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(
            try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/plain.m4a", mediaType: "audio/mp4")]
            )
        )
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testIntentLeafSymlinkCannotBeAtomicallyOverwritten() throws {
        let root = try makeRoot()
        let base = root.deletingLastPathComponent()
        defer { try? fm.removeItem(at: base) }

        let external = base.appendingPathComponent("external.json")
        try Data("sentinel".utf8).write(to: external)
        let registration = root.appendingPathComponent(
            ".LibraryRecovery/ExportRegistration",
            isDirectory: true
        )
        try fm.createDirectory(at: registration, withIntermediateDirectories: true)

        let id = UUID()
        let link = registration.appendingPathComponent(id.uuidString + ".json")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)

        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(
            try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/plain.m4a", mediaType: "audio/mp4")],
                id: id
            )
        )
        XCTAssertEqual(try Data(contentsOf: external), Data("sentinel".utf8))
    }

    func testSymlinkPublicationMarkerIsNotClearedAndIntentRemains() throws {
        let root = try makeRoot()
        let base = root.deletingLastPathComponent()
        defer { try? fm.removeItem(at: base) }

        let batch = root.appendingPathComponent("Exports/Batches/marker", isDirectory: true)
        try fm.createDirectory(at: batch, withIntermediateDirectories: true)
        let external = base.appendingPathComponent("external-marker.txt")
        try Data("outside".utf8).write(to: external)
        let marker = batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
        try fm.createSymbolicLink(at: marker, withDestinationURL: external)

        let id = UUID()
        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(
            try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/Batches/marker/Mix.m4a", mediaType: "audio/mp4")],
                id: id
            )
        ) { error in
            guard case Lane2ExportRegistrationJournalFailure.publicationMarkerClearFailed = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }

        XCTAssertTrue(journal.exists(intentID: id))
        XCTAssertEqual(try Data(contentsOf: external), Data("outside".utf8))
    }

    func testFinalizedBatchRootSymlinkFailsRecoveryClosed() throws {
        let root = try makeRoot()
        let base = root.deletingLastPathComponent()
        defer { try? fm.removeItem(at: base) }

        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        let exports = root.appendingPathComponent("Exports", isDirectory: true)
        try fm.createDirectory(at: exports, withIntermediateDirectories: true)
        let batches = exports.appendingPathComponent("Batches", isDirectory: true)
        try fm.createSymbolicLink(at: batches, withDestinationURL: external)

        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(try journal.recoverPrejournalPublishedBatches()) { error in
            guard case Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testDanglingQuarantineDestinationCannotConsumePublishedBatch() throws {
        let root = try makeRoot()
        let base = root.deletingLastPathComponent()
        defer { try? fm.removeItem(at: base) }

        let batchID = UUID().uuidString.lowercased()
        let batch = root.appendingPathComponent("Exports/Batches/\(batchID)", isDirectory: true)
        try fm.createDirectory(at: batch, withIntermediateDirectories: true)
        let marker = batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
        try Data("previous-session\n".utf8).write(to: marker)

        let quarantine = root.appendingPathComponent(
            ".LibraryRecovery/PrejournalExport",
            isDirectory: true
        )
        try fm.createDirectory(at: quarantine, withIntermediateDirectories: true)
        let destination = quarantine.appendingPathComponent(batchID, isDirectory: true)
        let missingExternal = base.appendingPathComponent("missing-external", isDirectory: true)
        try fm.createSymbolicLink(at: destination, withDestinationURL: missingExternal)

        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(try journal.recoverPrejournalPublishedBatches())
        XCTAssertTrue(fm.fileExists(atPath: batch.path))
        XCTAssertFalse(fm.fileExists(atPath: missingExternal.path))
    }

    func testCompleteDoesNotFollowSymlinkIntentLeaf() throws {
        let root = try makeRoot()
        let base = root.deletingLastPathComponent()
        defer { try? fm.removeItem(at: base) }

        let registration = root.appendingPathComponent(
            ".LibraryRecovery/ExportRegistration",
            isDirectory: true
        )
        try fm.createDirectory(at: registration, withIntermediateDirectories: true)
        let external = base.appendingPathComponent("external.json")
        try Data("sentinel".utf8).write(to: external)

        let id = UUID()
        let link = registration.appendingPathComponent(id.uuidString + ".json")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)

        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        XCTAssertThrowsError(try journal.complete(intentID: id))
        XCTAssertEqual(try Data(contentsOf: external), Data("sentinel".utf8))
    }

    private func makeRoot() throws -> URL {
        let base = fm.temporaryDirectory.appendingPathComponent(
            "L2-AW50-TEST-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = base.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
