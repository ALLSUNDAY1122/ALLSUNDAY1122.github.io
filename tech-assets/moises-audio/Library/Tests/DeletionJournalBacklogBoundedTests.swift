import Foundation
import XCTest

final class Lane2DeletionJournalBacklogBoundedTests: XCTestCase {
    func testExtremeJournalBacklogReturnsOnlyDefaultRecoveryWindow() throws {
        try withRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let ids = try (0..<300).map(projectUUID)
            for id in ids {
                _ = try lifecycle.persistCommittedDeletion(
                    projectUUID: id,
                    relativePaths: ["Imports/\(id.uuidString)/source.m4a"]
                )
            }

            let slice = try lifecycle.pendingDeletionJournals()
            XCTAssertEqual(slice.count, LibraryArtifactLifecycle.defaultDeletionJournalRecoveryLimit)
            XCTAssertLessThanOrEqual(
                slice.count,
                LibraryArtifactLifecycle.maximumDeletionJournalRecoveryLimit
            )
        }
    }

    func testSuccessfulPassRetirementAdvancesBacklog() throws {
        try withRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            for value in 0..<140 {
                _ = try lifecycle.persistCommittedDeletion(
                    projectUUID: try projectUUID(value),
                    relativePaths: ["Imports/\(value)/source.m4a"]
                )
            }

            let first = try lifecycle.pendingDeletionJournals(limit: 64)
            XCTAssertEqual(first.count, 64)
            for journal in first {
                try lifecycle.executeCommittedDeletion(projectUUID: journal.projectUUID)
                try lifecycle.completeMetadataCompaction(projectUUID: journal.projectUUID)
            }

            let second = try lifecycle.pendingDeletionJournals(limit: 64)
            XCTAssertEqual(second.count, 64)
            XCTAssertTrue(Set(first.map(\.projectUUID)).isDisjoint(with: Set(second.map(\.projectUUID))))

            for journal in second {
                try lifecycle.executeCommittedDeletion(projectUUID: journal.projectUUID)
                try lifecycle.completeMetadataCompaction(projectUUID: journal.projectUUID)
            }
            XCTAssertEqual(try lifecycle.pendingDeletionJournals(limit: 64).count, 12)
        }
    }

    func testLimitIsClampedAndFilenamePayloadMismatchFailsClosed() throws {
        try withRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            for value in 0..<300 {
                _ = try lifecycle.persistCommittedDeletion(
                    projectUUID: try projectUUID(value),
                    relativePaths: ["Imports/\(value)/source.m4a"]
                )
            }
            XCTAssertEqual(
                try lifecycle.pendingDeletionJournals(limit: 10_000).count,
                LibraryArtifactLifecycle.maximumDeletionJournalRecoveryLimit
            )
        }

        try withRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            try lifecycle.ensureLayout()
            let payloadID = try projectUUID(10)
            let filenameID = try projectUUID(11)
            let journal = LibraryDeletionJournal(
                projectUUID: payloadID,
                relativePaths: ["Imports/mismatch/source.m4a"],
                createdAt: Date(timeIntervalSince1970: 1),
                phase: .committed
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let directory = root
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("Delete", isDirectory: true)
            try encoder.encode(journal).write(
                to: directory.appendingPathComponent(filenameID.uuidString + ".json")
            )
            XCTAssertThrowsError(try lifecycle.pendingDeletionJournals(limit: 64))
        }
    }

    func testSymlinkJournalFailsClosed() throws {
        try withRoot { root in
            let lifecycle = LibraryArtifactLifecycle(rootURL: root)
            let targetID = try projectUUID(1)
            _ = try lifecycle.persistCommittedDeletion(
                projectUUID: targetID,
                relativePaths: ["Imports/target/source.m4a"]
            )
            let linkID = try projectUUID(2)
            let directory = root
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("Delete", isDirectory: true)
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent(linkID.uuidString + ".json"),
                withDestinationURL: directory.appendingPathComponent(targetID.uuidString + ".json")
            )
            XCTAssertThrowsError(try lifecycle.pendingDeletionJournals(limit: 64))
        }
    }

    private func projectUUID(_ value: Int) throws -> UUID {
        let suffix = String(format: "%012X", value)
        guard let id = UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") else {
            throw NSError(domain: "AW37", code: 1)
        }
        return id
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW37-DeletionJournalBacklog-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root)
    }
}
