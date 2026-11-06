import Foundation
import XCTest

final class PrejournalDispositionPathAuthorityTests: XCTestCase {
    private let fm = FileManager.default

    func testDispositionRootSymlinkFailsRecoveryWithoutFollowingExternal() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let external = f.base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try fm.createDirectory(at: f.recovery, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: f.dispositions, withDestinationURL: external)

        let manager = Lane2PrejournalExportQuarantineManager(rootURL: f.root, fileManager: fm)
        do {
            _ = try await manager.recoverPendingDispositions()
            XCTFail("expected fail-closed disposition root")
        } catch Lane2PrejournalQuarantineFailure.fileOperationFailed {
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
        }
    }

    func testDanglingRecoveredDestinationBlocksPreserveAndKeepsPending() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let id = UUID().uuidString.lowercased()
        try f.makeBatch(id: id)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: f.root, fileManager: fm)
        let inventory = await manager.inventory()
        let batch = try XCTUnwrap(inventory.pending.first)

        try fm.createDirectory(at: f.recovered, withIntermediateDirectories: true)
        let destination = f.recovered.appendingPathComponent(id, isDirectory: true)
        let missingExternal = f.base.appendingPathComponent("missing-external", isDirectory: true)
        try fm.createSymbolicLink(at: destination, withDestinationURL: missingExternal)

        await XCTAssertThrowsErrorAsync {
            _ = try await manager.preserveForUser(batchID: id, snapshotToken: batch.snapshotToken)
        }
        XCTAssertTrue(try f.isRealDirectory(f.pending.appendingPathComponent(id, isDirectory: true)))
        XCTAssertFalse(fm.fileExists(atPath: missingExternal.path))
    }

    func testDispositionLeafSymlinkFailsRecoveryWithoutTouchingTarget() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        try fm.createDirectory(at: f.dispositions, withIntermediateDirectories: true)
        let target = f.base.appendingPathComponent("target.json")
        try Data("sentinel".utf8).write(to: target)
        let link = f.dispositions.appendingPathComponent(UUID().uuidString + ".json")
        try fm.createSymbolicLink(at: link, withDestinationURL: target)

        let manager = Lane2PrejournalExportQuarantineManager(rootURL: f.root, fileManager: fm)
        do {
            _ = try await manager.recoverPendingDispositions()
            XCTFail("expected corrupt disposition")
        } catch Lane2PrejournalQuarantineFailure.corruptDisposition {
            XCTAssertEqual(try Data(contentsOf: target), Data("sentinel".utf8))
        }
    }

    func testUnsafePendingRootIsInventoryIssueAndExternalIsNotEnumerated() async throws {
        let f = try Fixture(createPending: false)
        defer { f.cleanup() }
        let external = f.base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: external.appendingPathComponent("not-a-batch"))
        try fm.createDirectory(at: f.recovery, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: f.pending, withDestinationURL: external)

        let report = await Lane2PrejournalExportQuarantineManager(rootURL: f.root, fileManager: fm).inventory()
        XCTAssertTrue(report.pending.isEmpty)
        XCTAssertTrue(report.issues.contains { $0.batchName == "<root>" && $0.stableCode == "UNSAFE_ROOT" })
    }

    func testRelaunchPreserveIntentStillConverges() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let id = UUID().uuidString.lowercased()
        try f.makeBatch(id: id)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: f.root, fileManager: fm)
        let inventory = await manager.inventory()
        let batch = try XCTUnwrap(inventory.pending.first)
        try f.writeIntent(kind: "preserveForUser", batchID: id, snapshotToken: batch.snapshotToken)

        let report = try await manager.recoverPendingDispositions()
        XCTAssertEqual(report.completedPreserves, 1)
        XCTAssertTrue(try f.isRealDirectory(f.recovered.appendingPathComponent(id, isDirectory: true)))
        XCTAssertFalse(fm.fileExists(atPath: f.pending.appendingPathComponent(id).path))
        XCTAssertFalse(fm.fileExists(atPath: f.dispositions.path))
    }

    func testPurgeIntentCannotDeleteThroughSymlinkBatchAndIntentRemains() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let external = f.base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data("sentinel".utf8).write(to: external.appendingPathComponent("keep.txt"))
        let id = UUID().uuidString.lowercased()
        try fm.createSymbolicLink(
            at: f.pending.appendingPathComponent(id, isDirectory: true),
            withDestinationURL: external
        )
        try f.writeIntent(kind: "purgePending", batchID: id, snapshotToken: "v1-deadbeef")

        let manager = Lane2PrejournalExportQuarantineManager(rootURL: f.root, fileManager: fm)
        do {
            _ = try await manager.recoverPendingDispositions()
            XCTFail("expected symlink rejection")
        } catch Lane2PrejournalQuarantineFailure.symlinkRejected {
            XCTAssertEqual(
                try Data(contentsOf: external.appendingPathComponent("keep.txt")),
                Data("sentinel".utf8)
            )
            XCTAssertFalse(try fm.contentsOfDirectory(atPath: f.dispositions.path).isEmpty)
        }
    }
}

private final class AW51Fixture {
    let base: URL
    let root: URL
    let recovery: URL
    let pending: URL
    let recovered: URL
    let dispositions: URL
    private let fm = FileManager.default

    init(createPending: Bool = true) throws {
        base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-TEST-\(UUID().uuidString)", isDirectory: true)
        root = base.appendingPathComponent("root", isDirectory: true)
        recovery = root.appendingPathComponent(".LibraryRecovery", isDirectory: true)
        pending = recovery.appendingPathComponent("PrejournalExport", isDirectory: true)
        recovered = recovery.appendingPathComponent("RecoveredPrejournalExport", isDirectory: true)
        dispositions = recovery.appendingPathComponent("PrejournalExportDisposition", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        if createPending {
            try fm.createDirectory(at: pending, withIntermediateDirectories: true)
        }
    }

    func cleanup() { try? fm.removeItem(at: base) }

    func makeBatch(id: String) throws {
        let dir = pending.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: false)
        try Data("previous-process-session\n".utf8).write(
            to: dir.appendingPathComponent(".lane2-registration-pending")
        )
        try Data(repeating: 0x44, count: 32).write(to: dir.appendingPathComponent("Mix.m4a"))
    }

    func writeIntent(kind: String, batchID: String, snapshotToken: String) throws {
        try fm.createDirectory(at: dispositions, withIntermediateDirectories: true)
        let id = UUID()
        let payload: [String: Any] = [
            "id": id.uuidString,
            "kind": kind,
            "batchID": batchID,
            "snapshotToken": snapshotToken,
            "createdAt": "2026-08-27T02:00:00Z"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: dispositions.appendingPathComponent(id.uuidString + ".json"), options: [.atomic])
    }

    func isRealDirectory(_ url: URL) throws -> Bool {
        (try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeDirectory
    }
}

private typealias Fixture = AW51Fixture

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("expected error", file: file, line: line)
    } catch {
        // Expected.
    }
}
