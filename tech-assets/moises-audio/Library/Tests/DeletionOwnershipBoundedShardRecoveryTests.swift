import Foundation
import XCTest

final class DeletionOwnershipBoundedShardRecoveryTests: XCTestCase {
    func testPathologicallyConcentratedShardReturnsBoundedRecoverySlice() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("L2-AW45-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let targetShard = 0
        var projectIDs: [UUID] = []
        while projectIDs.count < 1_300 {
            let id = UUID()
            if Lane2DeletionOwnershipIndex.shardIndex(for: id) == targetShard {
                projectIDs.append(id)
            }
        }

        for projectID in projectIDs {
            let sourceID = UUID()
            let record = try Lane2DeletionOwnershipRecord(
                projectUUID: projectID,
                sourceAssetUUID: sourceID,
                artifactRelativePaths: ["Imports/\(sourceID.uuidString).m4a"]
            )
            try index.persist(record)
        }

        let slice = try index.pendingRecordSlice(limit: 64)
        XCTAssertEqual(slice.records.count, 64)
        XCTAssertEqual(slice.limit, 64)
        XCTAssertTrue(slice.hasMore)
        XCTAssertEqual(Lane2DeletionOwnershipIndex.defaultShardDirectoryScanBudget, 1_024)
    }

    func testEmptyShardRetiresWithoutWholeDirectoryMaterialization() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("L2-AW45-empty-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let projectID = UUID()
        let sourceID = UUID()
        let record = try Lane2DeletionOwnershipRecord(
            projectUUID: projectID,
            sourceAssetUUID: sourceID,
            artifactRelativePaths: ["Imports/\(sourceID.uuidString).m4a"]
        )
        try index.persist(record)
        try index.remove(projectUUID: projectID)

        let slice = try index.pendingRecordSlice(limit: 64)
        XCTAssertTrue(slice.records.isEmpty)
        XCTAssertFalse(slice.hasMore)
    }

    func testSymlinkRecordFailsClosedWhenVisited() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("L2-AW45-symlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let projectID = UUID()
        let sourceID = UUID()
        let record = try Lane2DeletionOwnershipRecord(
            projectUUID: projectID,
            sourceAssetUUID: sourceID,
            artifactRelativePaths: ["Imports/\(sourceID.uuidString).m4a"]
        )
        let recordURL = try index.persist(record)
        try FileManager.default.removeItem(at: recordURL)

        let target = root.appendingPathComponent("target.txt")
        try Data("x".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: recordURL, withDestinationURL: target)

        XCTAssertThrowsError(try index.pendingRecordSlice(limit: 64))
    }
}
