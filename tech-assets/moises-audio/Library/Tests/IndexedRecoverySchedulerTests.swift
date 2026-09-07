import Foundation
import XCTest

final class Lane2IndexedRecoverySchedulerTests: XCTestCase {
    func testBudgetClampsAndCounts() {
        XCTAssertEqual(Lane2IndexedRecoveryBudget(ownershipOnlyPerPass: 1).ownershipOnlyPerPass, 8)
        XCTAssertEqual(Lane2IndexedRecoveryBudget(ownershipOnlyPerPass: 999).ownershipOnlyPerPass, 256)
        let budget = Lane2IndexedRecoveryBudget(ownershipOnlyPerPass: 64)
        XCTAssertEqual(budget.selectedCount(availableOwnershipOnlyRecords: 100), 64)
        XCTAssertEqual(budget.passCount(forOwnershipOnlyRecordCount: 100_000), 1_563)
    }

    func testSliceIsBoundedDeterministicAndExcludesJournalProjects() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let ids = try (0..<20).map { try projectUUID($0) }
            for (offset, id) in ids.reversed().enumerated() {
                try index.persist(
                    Lane2DeletionOwnershipRecord(
                        projectUUID: id,
                        sourceAssetUUID: UUID(),
                        artifactRelativePaths: ["Imports/\(offset)/source.m4a"],
                        createdAt: Date(timeIntervalSince1970: 100)
                    )
                )
            }
            let excluded = Set([ids[0], ids[1], ids[2]])
            let slice = try index.pendingRecordSlice(limit: 8, excludingProjectUUIDs: excluded)
            XCTAssertEqual(slice.records.count, 8)
            XCTAssertTrue(slice.hasMore)
            XCTAssertEqual(slice.limit, 8)
            XCTAssertEqual(slice.records.map(\.projectUUID), Array(ids[3...10]))
        }
    }

    func testRemovingSliceAdvancesWithoutStarvingRemainingRecords() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let ids = try (0..<18).map { try projectUUID($0) }
            for id in ids {
                try index.persist(
                    Lane2DeletionOwnershipRecord(
                        projectUUID: id,
                        sourceAssetUUID: UUID(),
                        artifactRelativePaths: ["Imports/\(id.uuidString)/source.m4a"]
                    )
                )
            }
            let first = try index.pendingRecordSlice(limit: 8)
            XCTAssertEqual(first.records.map(\.projectUUID), Array(ids[0..<8]))
            first.records.forEach { try? index.remove(projectUUID: $0.projectUUID) }
            let second = try index.pendingRecordSlice(limit: 8)
            XCTAssertEqual(second.records.map(\.projectUUID), Array(ids[8..<16]))
            second.records.forEach { try? index.remove(projectUUID: $0.projectUUID) }
            let third = try index.pendingRecordSlice(limit: 8)
            XCTAssertEqual(third.records.map(\.projectUUID), Array(ids[16..<18]))
            XCTAssertFalse(third.hasMore)
        }
    }

    func testCorruptPayloadOutsideCurrentSliceIsNotDecodedEarly() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            for value in 0..<8 {
                let id = try projectUUID(value)
                try index.persist(
                    Lane2DeletionOwnershipRecord(
                        projectUUID: id,
                        sourceAssetUUID: UUID(),
                        artifactRelativePaths: ["Imports/\(value)/source.m4a"]
                    )
                )
            }
            let corruptID = try projectUUID(999)
            let directory = root
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("DeleteOwnership", isDirectory: true)
            try Data("not-json".utf8).write(
                to: directory.appendingPathComponent(corruptID.uuidString + ".json")
            )
            let first = try index.pendingRecordSlice(limit: 8)
            XCTAssertEqual(first.records.count, 8)
            XCTAssertTrue(first.hasMore)
            for record in first.records { try index.remove(projectUUID: record.projectUUID) }
            XCTAssertThrowsError(try index.pendingRecordSlice(limit: 8))
        }
    }

    func testFilenamePayloadIdentityMismatchFailsClosed() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            try index.ensureLayout()
            let filenameID = try projectUUID(10)
            let payloadID = try projectUUID(11)
            let record = try Lane2DeletionOwnershipRecord(
                projectUUID: payloadID,
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Imports/mismatch/source.m4a"]
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let directory = root
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("DeleteOwnership", isDirectory: true)
            try encoder.encode(record).write(
                to: directory.appendingPathComponent(filenameID.uuidString + ".json")
            )
            XCTAssertThrowsError(try index.pendingRecordSlice(limit: 8)) { error in
                XCTAssertEqual(
                    error as? Lane2DeletionOwnershipIndexFailure,
                    .recordIdentityMismatch(expected: filenameID, actual: payloadID)
                )
            }
        }
    }

    func testSymlinkRecordFailsClosed() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            try index.ensureLayout()
            let targetID = try projectUUID(20)
            try index.persist(
                Lane2DeletionOwnershipRecord(
                    projectUUID: targetID,
                    sourceAssetUUID: UUID(),
                    artifactRelativePaths: ["Imports/target/source.m4a"]
                )
            )
            let linkID = try projectUUID(21)
            let directory = root
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("DeleteOwnership", isDirectory: true)
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent(linkID.uuidString + ".json"),
                withDestinationURL: directory.appendingPathComponent(targetID.uuidString + ".json")
            )
            XCTAssertThrowsError(try index.pendingRecordSlice(limit: 8))
        }
    }

    private func projectUUID(_ value: Int) throws -> UUID {
        let suffix = String(format: "%012X", value)
        guard let id = UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") else {
            throw NSError(domain: "test", code: 1)
        }
        return id
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW25-IndexedRecoveryTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
