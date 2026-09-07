import Foundation
import XCTest

final class IOStagingOwnershipTests: XCTestCase {
    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testReservationMathUsesRemainingBytes() throws {
        let now = Date()
        let records = [
            IOStagingOwnershipRecord(token: UUID().uuidString, stagingFilename: "a.tmp", reservedBytes: 100, writtenBytes: 25, heartbeatAt: now, expiresAt: now.addingTimeInterval(60)),
            IOStagingOwnershipRecord(token: UUID().uuidString, stagingFilename: "b.tmp", reservedBytes: 200, writtenBytes: 200, heartbeatAt: now, expiresAt: now.addingTimeInterval(60))
        ]
        XCTAssertEqual(try IOStagingOwnershipRegistry.totalRemainingReservation(records), 75)
    }

    func testActiveLeaseProtectsOldStagingCandidate() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root); try store.prepareDirectories()
        let registry = IOStagingOwnershipRegistry(fileStore: store, storageReserveBytes: 0, leaseDuration: 3600)
        let token = UUID().uuidString.lowercased()
        let name = token + ".provider-partial"
        let candidate = store.stagingURL.appendingPathComponent(name)
        _ = FileManager.default.createFile(atPath: candidate.path, contents: Data([1]))
        let old = Date().addingTimeInterval(-7200)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: candidate.path)
        let lease = try registry.acquire(token: token, stagingFilename: name, reservedBytes: 1)
        defer { lease.release() }

        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, now: Date())
        XCTAssertTrue(removed.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidate.path))
    }

    func testReleasedLeaseAllowsStaleCleanup() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root); try store.prepareDirectories()
        let registry = IOStagingOwnershipRegistry(fileStore: store, storageReserveBytes: 0)
        let token = UUID().uuidString.lowercased(); let name = token + ".wav"
        let candidate = store.stagingURL.appendingPathComponent(name)
        _ = FileManager.default.createFile(atPath: candidate.path, contents: Data([1]))
        let lease = try registry.acquire(token: token, stagingFilename: name, reservedBytes: 1)
        lease.release()
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: candidate.path)
        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, now: Date())
        XCTAssertEqual(removed, [name])
    }

    func testExpiredLeaseAllowsRecovery() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root); try store.prepareDirectories()
        let registry = IOStagingOwnershipRegistry(fileStore: store, storageReserveBytes: 0, leaseDuration: 1)
        let token = UUID().uuidString.lowercased(); let name = token + ".provider-partial"
        let candidate = store.stagingURL.appendingPathComponent(name)
        _ = FileManager.default.createFile(atPath: candidate.path, contents: Data([1]))
        _ = try registry.acquire(token: token, stagingFilename: name, reservedBytes: 1, now: Date(timeIntervalSince1970: 100))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: candidate.path)
        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 1, now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(removed, [name])
    }

    func testFreshCorruptLeaseFailsClosed() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = IOFileStore(rootURL: root); try store.prepareDirectories()
        let registry = IOStagingOwnershipRegistry(fileStore: store, storageReserveBytes: 0, leaseDuration: 3600)
        let token = UUID().uuidString.lowercased(); let name = token + ".provider-partial"
        let candidate = store.stagingURL.appendingPathComponent(name)
        _ = FileManager.default.createFile(atPath: candidate.path, contents: Data([1]))
        let lease = try registry.acquire(token: token, stagingFilename: name, reservedBytes: 1)
        defer { lease.release() }
        let leaseURL = registry.ledgerURL.appendingPathComponent(token).appendingPathExtension("json")
        try Data("broken".utf8).write(to: leaseURL)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: candidate.path)

        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, now: Date())
        XCTAssertTrue(removed.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidate.path))
    }

    func testProviderSnapshotRetainsReadyOwnershipUntilRelease() throws {
        let root = try makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString).appendingPathExtension("wma")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data(repeating: 7, count: 64 * 1024).write(to: source)
        let store = IOFileStore(rootURL: root)
        let acquirer = IOProviderSnapshotAcquirer(fileStore: store, maximumFileBytes: 1024 * 1024, storageReserveBytes: 0, chunkBytes: 4096, ownershipHeartbeatBytes: 8192)
        let snapshot = try acquirer.stageProviderSnapshot(at: source, accessMode: .direct)
        XCTAssertEqual(snapshot.stagedFile.descriptor.pathExtension, "wma")
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: snapshot.stagedFile.stagingURL.path)
        XCTAssertTrue(try IOStagingRecovery(fileStore: store).sweep(olderThan: 60).isEmpty)
        snapshot.ownership.release()
        XCTAssertEqual(try IOStagingRecovery(fileStore: store).sweep(olderThan: 60), [snapshot.stagedFile.stagingURL.lastPathComponent])
    }
}
