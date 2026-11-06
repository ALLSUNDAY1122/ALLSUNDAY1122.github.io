import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOStagingRecoveryTests: XCTestCase {
    func testSweepRemovesOnlyStaleDirectFiles() throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("io-staging-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: base)
        try store.prepareDirectories(fileManager: fm)
        let recovery = IOStagingRecovery(fileStore: store)
        let now = Date(timeIntervalSince1970: 10_000)

        let stale = store.stagingURL.appendingPathComponent("stale.tmp")
        let fresh = store.stagingURL.appendingPathComponent("fresh.tmp")
        let nested = store.stagingURL.appendingPathComponent("nested", isDirectory: true)
        try Data([1]).write(to: stale)
        try Data([2]).write(to: fresh)
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)

        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-3_600)], ofItemAtPath: stale.path)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-30)], ofItemAtPath: fresh.path)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-3_600)], ofItemAtPath: nested.path)

        let removed = try recovery.sweep(olderThan: 300, now: now, fileManager: fm)

        XCTAssertEqual(removed, ["stale.tmp"])
        XCTAssertFalse(fm.fileExists(atPath: stale.path))
        XCTAssertTrue(fm.fileExists(atPath: fresh.path))
        XCTAssertTrue(fm.fileExists(atPath: nested.path))
    }

    func testSweepIsIdempotent() throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("io-staging-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: base)
        try store.prepareDirectories(fileManager: fm)
        let recovery = IOStagingRecovery(fileStore: store)
        let now = Date(timeIntervalSince1970: 10_000)
        let stale = store.stagingURL.appendingPathComponent("stale.tmp")
        try Data([1]).write(to: stale)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-600)], ofItemAtPath: stale.path)

        XCTAssertEqual(try recovery.sweep(olderThan: 60, now: now, fileManager: fm), ["stale.tmp"])
        XCTAssertEqual(try recovery.sweep(olderThan: 60, now: now, fileManager: fm), [])
    }

    func testInvalidGraceFailsClosed() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("io-staging-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let recovery = IOStagingRecovery(fileStore: IOFileStore(rootURL: base))
        XCTAssertThrowsError(try recovery.sweep(olderThan: -1)) { error in
            XCTAssertEqual(error as? IOStagingRecoveryError, .invalidGraceInterval)
        }
    }
}
