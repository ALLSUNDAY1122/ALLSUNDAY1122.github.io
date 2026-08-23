import Foundation
import XCTest

final class LibraryStoreRecoveryTests: XCTestCase {
    func testMigrationWorkingCopyNeverMutatesOriginal() throws {
        try withStore { manager, storeURL, _ in
            let original = try Data(contentsOf: storeURL)
            let snapshot = try manager.snapshotOriginal(reason: "migration-test")
            let working = try manager.createWorkingCopy(from: snapshot)
            try Data("broken candidate".utf8).write(to: working.storeURL)
            XCTAssertEqual(try Data(contentsOf: storeURL), original)
            try manager.validate(snapshot: snapshot)
        }
    }

    func testActivationUsesPointerAndPreservesOriginalStoreFamily() throws {
        try withStore { manager, storeURL, root in
            let original = try Data(contentsOf: storeURL)
            try Data("wal".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
            let snapshot = try manager.snapshotOriginal(reason: "pre-migration")
            let working = try manager.createWorkingCopy(from: snapshot)
            let active = try manager.activateMigratedCopy(from: working, preservedOriginalSnapshot: snapshot)
            let resolved = try XCTUnwrap(manager.resolveActiveStoreManifest())
            XCTAssertEqual(resolved.activeStorePath, active.activeStorePath)
            XCTAssertEqual(resolved.preservedOriginalStorePath, storeURL.path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.activeStorePath))
            XCTAssertEqual(try Data(contentsOf: storeURL), original)
            XCTAssertTrue(resolved.activeStorePath.hasPrefix(root.appendingPathComponent("Recovery").path))
        }
    }

    func testCorruptionExportPreservesOriginalAndProducesVerifiedPackage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RecoveryTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("Library.sqlite")
        let corrupt = Data("definitely-not-sqlite".utf8)
        try corrupt.write(to: storeURL)
        let manager = try LibraryStoreRecoveryManager(storeURL: storeURL)
        XCTAssertEqual(manager.inspect(), .corruptOrUnreadable)
        XCTAssertEqual(manager.recoveryPlan().action, .quarantineAndRequireExplicitRecovery)
        XCTAssertFalse(manager.recoveryPlan().destructiveResetAllowed)
        let package = try manager.exportRecoveryPackage(reason: "corrupt")
        try manager.validate(snapshot: package)
        XCTAssertEqual(try Data(contentsOf: storeURL), corrupt)
    }

    func testTamperedSnapshotFailsClosed() throws {
        try withStore { manager, _, _ in
            let snapshot = try manager.snapshotOriginal(reason: "tamper-test")
            try Data("tampered".utf8).write(to: snapshot.storeURL)
            XCTAssertThrowsError(try manager.validate(snapshot: snapshot))
        }
    }

    func testRecoveryPlanNeverAuthorizesDestructiveReset() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RecoveryPlanTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("Library.sqlite")
        let manager = try LibraryStoreRecoveryManager(storeURL: storeURL)
        XCTAssertFalse(manager.recoveryPlan().destructiveResetAllowed)
        XCTAssertFalse(manager.migrationPlan().destructiveResetAllowed)
        try Data("broken".utf8).write(to: storeURL)
        XCTAssertFalse(manager.recoveryPlan().destructiveResetAllowed)
    }

    private func withStore(_ body: (LibraryStoreRecoveryManager, URL, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RecoveryTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("Library.sqlite")
        var data = Data("SQLite format 3\0".utf8)
        data.append(Data(repeating: 0, count: 256))
        try data.write(to: storeURL)
        let manager = try LibraryStoreRecoveryManager(storeURL: storeURL)
        try body(manager, storeURL, root)
    }
}
