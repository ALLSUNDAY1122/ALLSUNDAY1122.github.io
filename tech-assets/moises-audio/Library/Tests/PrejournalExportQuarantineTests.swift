import Foundation
import XCTest

final class PrejournalExportQuarantineTests: XCTestCase {
    private let marker = ".lane2-registration-pending"

    func testInventoryReportsValidBatchAndArtifactMetadata() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let id = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: id, files: ["Vocals.m4a": 128, "Drums.m4a": 64])
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let report = await manager.inventory()
        XCTAssertEqual(report.pending.count, 1)
        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertEqual(report.pending[0].batchID, id)
        XCTAssertEqual(report.pending[0].artifacts.map(\.filename), ["Drums.m4a", "Vocals.m4a"])
        XCTAssertEqual(report.pending[0].totalBytes, 192)
        XCTAssertTrue(report.pending[0].snapshotToken.hasPrefix("v1-"))
    }

    func testMalformedBatchDoesNotHideOtherValidInventory() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let good = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: good, files: ["Mix.m4a": 32])
        let bad = UUID().uuidString.lowercased()
        let badURL = fixture.pending.appendingPathComponent(bad, isDirectory: true)
        try FileManager.default.createDirectory(at: badURL, withIntermediateDirectories: true)
        try Data([1]).write(to: badURL.appendingPathComponent("Mix.m4a"))

        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let report = await manager.inventory()
        XCTAssertEqual(report.pending.map(\.batchID), [good])
        XCTAssertEqual(report.issues.count, 1)
        XCTAssertEqual(report.issues[0].stableCode, "MISSING_MARKER")
    }

    func testPreserveForUserMovesWholeBatchAndExcludesMarkerFromArtifactURLs() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let id = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: id, files: ["Vocals.m4a": 100, "Other.m4a": 75])
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let beforeInventory = await manager.inventory()
        let before = try XCTUnwrap(beforeInventory.pending.first)
        let recovered = try await manager.preserveForUser(batchID: id, snapshotToken: before.snapshotToken)
        XCTAssertEqual(recovered.location, .recoveredForUser)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.pending.appendingPathComponent(id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recovered.appendingPathComponent(id).path))
        let urls = try await manager.recoveredArtifactURLs(batchID: id, snapshotToken: recovered.snapshotToken)
        XCTAssertEqual(Set(urls.map(\.lastPathComponent)), Set(["Vocals.m4a", "Other.m4a"]))
        XCTAssertFalse(urls.contains(where: { $0.lastPathComponent == marker }))
    }

    func testStaleSnapshotRejectsDestructivePurge() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let id = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: id, files: ["Mix.m4a": 10])
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let beforeInventory = await manager.inventory()
        let before = try XCTUnwrap(beforeInventory.pending.first)
        let file = fixture.pending.appendingPathComponent(id).appendingPathComponent("Mix.m4a")
        try Data(repeating: 9, count: 11).write(to: file)

        do {
            try await manager.purgePending(batchID: id, snapshotToken: before.snapshotToken)
            XCTFail("expected stale snapshot")
        } catch Lane2PrejournalQuarantineFailure.staleSnapshot(let rejected) {
            XCTAssertEqual(rejected, id)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testPendingPreserveIntentRecoversAfterRelaunch() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let id = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: id, files: ["Mix.m4a": 20])
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let batchInventory = await manager.inventory()
        let batch = try XCTUnwrap(batchInventory.pending.first)
        try fixture.writeIntent(kind: "preserveForUser", batchID: id, snapshotToken: batch.snapshotToken)

        let report = try await manager.recoverPendingDispositions()
        XCTAssertEqual(report.completedPreserves, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recovered.appendingPathComponent(id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.pending.appendingPathComponent(id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.dispositions.path))
    }

    func testPreserveIntentRecoversWhenMoveAlreadyHappened() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let id = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: id, files: ["Mix.m4a": 20])
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let batchInventory = await manager.inventory()
        let batch = try XCTUnwrap(batchInventory.pending.first)
        try fixture.writeIntent(kind: "preserveForUser", batchID: id, snapshotToken: batch.snapshotToken)
        try FileManager.default.createDirectory(at: fixture.recovered, withIntermediateDirectories: true)
        try FileManager.default.moveItem(
            at: fixture.pending.appendingPathComponent(id),
            to: fixture.recovered.appendingPathComponent(id)
        )

        let report = try await manager.recoverPendingDispositions()
        XCTAssertEqual(report.completedPreserves, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recovered.appendingPathComponent(id).path))
    }

    func testPendingAndRecoveredPurgesAreExplicitAndRecoverable() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let first = UUID().uuidString.lowercased()
        let second = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: first, files: ["One.m4a": 20])
        try fixture.makeBatch(id: second, files: ["Two.m4a": 30])
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: fixture.root)
        let initial = await manager.inventory()
        let firstBatch = try XCTUnwrap(initial.pending.first(where: { $0.batchID == first }))
        let secondBatch = try XCTUnwrap(initial.pending.first(where: { $0.batchID == second }))
        try await manager.purgePending(batchID: first, snapshotToken: firstBatch.snapshotToken)
        let recovered = try await manager.preserveForUser(batchID: second, snapshotToken: secondBatch.snapshotToken)
        try await manager.purgeRecovered(batchID: second, snapshotToken: recovered.snapshotToken)
        let final = await manager.inventory()
        XCTAssertTrue(final.pending.isEmpty)
        XCTAssertTrue(final.recoveredForUser.isEmpty)
    }

    func testNestedDirectoryAndSymlinkAreFailClosedInventoryIssues() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let nestedID = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: nestedID, files: ["Mix.m4a": 20])
        try FileManager.default.createDirectory(
            at: fixture.pending.appendingPathComponent(nestedID).appendingPathComponent("nested"),
            withIntermediateDirectories: false
        )

        let symlinkID = UUID().uuidString.lowercased()
        try fixture.makeBatch(id: symlinkID, files: ["Mix.m4a": 20])
        let target = fixture.root.appendingPathComponent("target.bin")
        try Data([1]).write(to: target)
        try FileManager.default.createSymbolicLink(
            at: fixture.pending.appendingPathComponent(symlinkID).appendingPathComponent("link.m4a"),
            withDestinationURL: target
        )

        let report = await Lane2PrejournalExportQuarantineManager(rootURL: fixture.root).inventory()
        XCTAssertEqual(report.pending.count, 0)
        XCTAssertEqual(Set(report.issues.map(\.stableCode)), Set(["NESTED_ENTRY", "SYMLINK_REJECTED"]))
    }
}

private final class Fixture {
    let root: URL
    let pending: URL
    let recovered: URL
    let dispositions: URL
    private let fm = FileManager.default

    init() throws {
        root = fm.temporaryDirectory.appendingPathComponent("aw19-tests-" + UUID().uuidString, isDirectory: true)
        pending = root.appendingPathComponent(".LibraryRecovery/PrejournalExport", isDirectory: true)
        recovered = root.appendingPathComponent(".LibraryRecovery/RecoveredPrejournalExport", isDirectory: true)
        dispositions = root.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
        try fm.createDirectory(at: pending, withIntermediateDirectories: true)
    }

    func cleanup() { try? fm.removeItem(at: root) }

    func makeBatch(id: String, files: [String: Int]) throws {
        let dir = pending.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: false)
        try Data("previous-process-session\n".utf8).write(to: dir.appendingPathComponent(".lane2-registration-pending"))
        for (name, count) in files {
            try Data(repeating: 0x44, count: count).write(to: dir.appendingPathComponent(name))
        }
    }

    func writeIntent(kind: String, batchID: String, snapshotToken: String) throws {
        try fm.createDirectory(at: dispositions, withIntermediateDirectories: true)
        let id = UUID()
        let payload: [String: Any] = [
            "id": id.uuidString,
            "kind": kind,
            "batchID": batchID,
            "snapshotToken": snapshotToken,
            "createdAt": "2026-08-24T03:00:00Z"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: dispositions.appendingPathComponent(id.uuidString + ".json"), options: [.atomic])
    }
}
