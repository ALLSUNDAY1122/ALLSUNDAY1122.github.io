import Foundation
import XCTest

final class Lane2ExportRegistrationJournalTests: XCTestCase {
    func testIntentSurvivesReopenAndClassifiesRegisteredUnregisteredAndPartial() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("L2AW10Journal-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = UUID()
        let journal = Lane2ExportRegistrationJournal(rootURL: root)
        let intent = try journal.prepare(projectUUID: project, artifacts: [
            .init(relativePath: "Exports/Batches/x/Vocals.m4a", mediaType: "audio/mp4"),
            .init(relativePath: "Exports/Batches/x/Drums.m4a", mediaType: "audio/mp4")
        ])

        let reopened = Lane2ExportRegistrationJournal(rootURL: root)
        let pending = try reopened.pending()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, intent.id)
        XCTAssertEqual(
            Lane2ExportRegistrationJournal.disposition(intent: intent, registeredRelativePaths: []),
            .unregistered
        )
        XCTAssertEqual(
            Lane2ExportRegistrationJournal.disposition(
                intent: intent,
                registeredRelativePaths: ["Exports/Batches/x/Vocals.m4a", "Exports/Batches/x/Drums.m4a"]
            ),
            .alreadyRegistered
        )
        XCTAssertEqual(
            Lane2ExportRegistrationJournal.disposition(
                intent: intent,
                registeredRelativePaths: ["Exports/Batches/x/Vocals.m4a"]
            ),
            .partial
        )
    }

    func testUnsafeDuplicateAndCorruptIntentFailClosed() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("L2AW10Journal-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let journal = Lane2ExportRegistrationJournal(rootURL: root)

        XCTAssertThrowsError(try journal.prepare(projectUUID: UUID(), artifacts: [
            .init(relativePath: "Imports/source.m4a", mediaType: "audio/mp4")
        ]))
        XCTAssertThrowsError(try journal.prepare(projectUUID: UUID(), artifacts: [
            .init(relativePath: "Exports/a.m4a", mediaType: "audio/mp4"),
            .init(relativePath: "Exports/a.m4a", mediaType: "audio/mp4")
        ]))

        let directory = root.appendingPathComponent(".LibraryRecovery/ExportRegistration", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let corruptURL = directory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("broken".utf8).write(to: corruptURL)
        XCTAssertThrowsError(try journal.pending())
        XCTAssertTrue(fm.fileExists(atPath: corruptURL.path))
    }

    func testCompleteIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("L2AW10Journal-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = Lane2ExportRegistrationJournal(rootURL: root)
        let intent = try journal.prepare(projectUUID: UUID(), artifacts: [
            .init(relativePath: "Exports/Batches/y/Mix.m4a", mediaType: "audio/mp4")
        ])
        try journal.complete(intentID: intent.id)
        try journal.complete(intentID: intent.id)
        XCTAssertFalse(journal.exists(intentID: intent.id))
        XCTAssertTrue(try journal.pending().isEmpty)
    }
}
