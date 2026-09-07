import Foundation
import XCTest

final class Lane2DeletionOwnershipShardingTests: XCTestCase {
    func testPersistUsesDeterministicShardAndDirectLookup() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let record = try makeRecord(1)
            let url = try index.persist(record)
            let shard = String(format: "%02x", Lane2DeletionOwnershipIndex.shardIndex(for: record.projectUUID))
            XCTAssertTrue(url.path.contains("/DeleteOwnership/Shards/\(shard)/"))
            XCTAssertEqual(try index.record(projectUUID: record.projectUUID), record)
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".LibraryRecovery/DeleteOwnership/\(record.projectUUID.uuidString).json").path))
        }
    }

    func testLegacyFlatBacklogMigratesInBoundedSlices() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            try index.ensureLayout()
            let flat = root.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
            let encoder = stableEncoder()
            var expected = Set<UUID>()
            for n in 0..<17 {
                let record = try makeRecord(n)
                expected.insert(record.projectUUID)
                try encoder.encode(record).write(to: flat.appendingPathComponent(record.projectUUID.uuidString + ".json"), options: [.atomic])
            }
            var seen = Set<UUID>()
            for _ in 0..<4 {
                let slice = try index.pendingRecordSlice(limit: 8)
                XCTAssertLessThanOrEqual(slice.records.count, 8)
                for record in slice.records {
                    seen.insert(record.projectUUID)
                    try index.remove(projectUUID: record.projectUUID)
                }
            }
            XCTAssertEqual(seen, expected)
        }
    }

    func testJournalExcludedRecordRemainsDirectlyAddressable() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let journalRecord = try makeRecord(50)
            try index.persist(journalRecord)
            let slice = try index.pendingRecordSlice(limit: 8, excludingProjectUUIDs: [journalRecord.projectUUID])
            XCTAssertFalse(slice.records.contains(where: { $0.projectUUID == journalRecord.projectUUID }))
            XCTAssertEqual(try index.record(projectUUID: journalRecord.projectUUID), journalRecord)
        }
    }

    func testFlatAndShardedIdentityMismatchFailsClosed() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let project = UUID()
            let first = try Lane2DeletionOwnershipRecord(projectUUID: project, sourceAssetUUID: UUID(), artifactRelativePaths: ["Imports/a/source.m4a"])
            try index.persist(first)
            let conflict = try Lane2DeletionOwnershipRecord(projectUUID: project, sourceAssetUUID: UUID(), artifactRelativePaths: ["Imports/a/source.m4a"])
            let flat = root.appendingPathComponent(".LibraryRecovery/DeleteOwnership/\(project.uuidString).json")
            try stableEncoder().encode(conflict).write(to: flat, options: [.atomic])
            XCTAssertThrowsError(try index.record(projectUUID: project))
        }
    }

    func testEmptyActiveShardCrashSignalsAreRetiredWithoutPermanentStarvation() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            try index.ensureLayout()
            var project = UUID()
            while (0...3).contains(Lane2DeletionOwnershipIndex.shardIndex(for: project)) { project = UUID() }
            let record = try Lane2DeletionOwnershipRecord(projectUUID: project, sourceAssetUUID: UUID(), artifactRelativePaths: ["Imports/real/source.m4a"])
            let shard = Lane2DeletionOwnershipIndex.shardIndex(for: project)
            let base = root.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
            let shardDir = base.appendingPathComponent("Shards/" + String(format: "%02x", shard), isDirectory: true)
            try FileManager.default.createDirectory(at: shardDir, withIntermediateDirectories: true)
            try stableEncoder().encode(record).write(to: shardDir.appendingPathComponent(project.uuidString + ".json"), options: [.atomic])
            let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "shardIndices": [0, 1, 2, 3, shard]], options: [.sortedKeys])
            try manifest.write(to: base.appendingPathComponent(".active-shards-v2.json"), options: [.atomic])

            let first = try index.pendingRecordSlice(limit: 8)
            XCTAssertTrue(first.records.isEmpty)
            XCTAssertTrue(first.hasMore)
            let second = try index.pendingRecordSlice(limit: 8)
            XCTAssertEqual(second.records.map(\.projectUUID), [project])
        }
    }

    func testCorruptActiveManifestAndShardSymlinkFailClosed() throws {
        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            try index.ensureLayout()
            let base = root.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
            let manifest = base.appendingPathComponent(".active-shards-v2.json")
            try Data("bad".utf8).write(to: manifest)
            XCTAssertThrowsError(try index.pendingRecordSlice(limit: 8))
        }

        try withRoot { root in
            let index = Lane2DeletionOwnershipIndex(rootURL: root)
            let record = try makeRecord(91)
            let url = try index.persist(record)
            try FileManager.default.removeItem(at: url)
            let outside = root.appendingPathComponent("outside.json")
            try stableEncoder().encode(record).write(to: outside)
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
            XCTAssertThrowsError(try index.record(projectUUID: record.projectUUID))
        }
    }

    private func makeRecord(_ n: Int) throws -> Lane2DeletionOwnershipRecord {
        try Lane2DeletionOwnershipRecord(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["Imports/p\(n)/source.m4a", "Stems/p\(n)/vocals.m4a"],
            createdAt: Date(timeIntervalSince1970: Double(1_000_000 + n))
        )
    }

    private func stableEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AW32Tests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root)
    }
}
