import Foundation
import XCTest

final class Lane2DeletionOwnershipIndexTests: XCTestCase {
    func testRoundTripAndIdempotentPersist() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let project = UUID()
            let source = UUID()
            let record = try Lane2DeletionOwnershipRecord(
                projectUUID: project,
                sourceAssetUUID: source,
                artifactRelativePaths: ["Stems/p/vocals.m4a", "Imports/p/source.m4a", "Stems/p/vocals.m4a"]
            )
            try index.persist(record)
            try index.persist(record)
            XCTAssertEqual(try index.record(projectUUID: project), record)
            XCTAssertEqual(try index.pendingRecords(), [record])
        }
    }

    func testIdentityConflictFailsClosed() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let project = UUID()
            try index.persist(try .init(
                projectUUID: project,
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Imports/p/source.m4a"]
            ))
            XCTAssertThrowsError(try index.persist(try .init(
                projectUUID: project,
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Imports/p/source.m4a"]
            )))
        }
    }

    func testUnsafeArtifactRootIsRejected() throws {
        XCTAssertThrowsError(try Lane2DeletionOwnershipRecord(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["Exports/p/mix.m4a"]
        ))
        XCTAssertThrowsError(try Lane2DeletionOwnershipRecord(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["../outside"]
        ))
    }

    func testCorruptRecordFailsClosed() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            try index.ensureLayout()
            let directory = root.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
            try Data("not-json".utf8).write(to: directory.appendingPathComponent(UUID().uuidString + ".json"))
            XCTAssertThrowsError(try index.pendingRecords())
        }
    }

    func testLegacyMarkerPersistsAcrossInstances() throws {
        try withRoot { root in
            let first = Lane2DeletionOwnershipIndex(rootURL: root)
            XCTAssertFalse(first.isLegacyScanComplete)
            try first.markLegacyScanComplete()
            XCTAssertTrue(Lane2DeletionOwnershipIndex(rootURL: root).isLegacyScanComplete)
        }
    }

    func testRemoveIsIdempotent() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let record = try Lane2DeletionOwnershipRecord(
                projectUUID: UUID(),
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Imports/p/source.m4a"]
            )
            try index.persist(record)
            try index.remove(projectUUID: record.projectUUID)
            try index.remove(projectUUID: record.projectUUID)
            XCTAssertNil(try index.record(projectUUID: record.projectUUID))
        }
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW22-IndexTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
