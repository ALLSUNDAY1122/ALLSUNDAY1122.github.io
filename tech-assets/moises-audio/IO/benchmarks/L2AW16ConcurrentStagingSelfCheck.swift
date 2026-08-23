import Foundation

@main
struct L2AW16ConcurrentStagingSelfCheck {
    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("l2-aw16-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories(fileManager: fm)
        var scenarios = 0

        let now = Date()
        let arithmetic = [
            IOStagingOwnershipRecord(token: UUID().uuidString, stagingFilename: "x", reservedBytes: 100, writtenBytes: 40, heartbeatAt: now, expiresAt: now.addingTimeInterval(60)),
            IOStagingOwnershipRecord(token: UUID().uuidString, stagingFilename: "y", reservedBytes: 50, writtenBytes: 50, heartbeatAt: now, expiresAt: now.addingTimeInterval(60))
        ]
        guard try IOStagingOwnershipRegistry.totalRemainingReservation(arithmetic) == 60 else { fatalError("reservation arithmetic") }
        scenarios += 1

        let attrs = try fm.attributesOfFileSystem(forPath: root.path)
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard free > 16 * 1024 * 1024 else { fatalError("insufficient runner free space") }
        let registry = IOStagingOwnershipRegistry(fileStore: store, storageReserveBytes: 0, leaseDuration: 3600, fileManager: fm)
        let token1 = UUID().uuidString.lowercased()
        let reserve1 = max(1, free / 2)
        let lease1 = try registry.acquire(token: token1, stagingFilename: token1 + ".provider-partial", reservedBytes: reserve1)
        let token2 = UUID().uuidString.lowercased()
        var rejected = false
        do {
            _ = try registry.acquire(token: token2, stagingFilename: token2 + ".provider-partial", reservedBytes: reserve1 + 8 * 1024 * 1024)
        } catch IOFileStore.StoreError.insufficientStorage {
            rejected = true
        }
        guard rejected else { fatalError("concurrent reservation should reject") }
        scenarios += 1

        try lease1.heartbeat(writtenBytes: reserve1)
        let lease2 = try registry.acquire(token: token2, stagingFilename: token2 + ".provider-partial", reservedBytes: min(reserve1, 8 * 1024 * 1024))
        lease2.release(); lease1.release()
        scenarios += 1

        let token3 = UUID().uuidString.lowercased(); let name3 = token3 + ".provider-partial"
        let file3 = store.stagingURL.appendingPathComponent(name3)
        _ = fm.createFile(atPath: file3.path, contents: Data([1,2,3]))
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: file3.path)
        let lease3 = try registry.acquire(token: token3, stagingFilename: name3, reservedBytes: 3)
        guard try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, fileManager: fm).isEmpty else { fatalError("active partial swept") }
        guard fm.fileExists(atPath: file3.path) else { fatalError("active partial missing") }
        scenarios += 1

        let readyName = token3 + ".wma"
        let ready3 = store.stagingURL.appendingPathComponent(readyName)
        try fm.moveItem(at: file3, to: ready3)
        try lease3.retarget(stagingFilename: readyName, writtenBytes: 3)
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: ready3.path)
        guard try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, fileManager: fm).isEmpty else { fatalError("active ready swept") }
        lease3.release()
        guard try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, fileManager: fm) == [readyName] else { fatalError("released ready not swept") }
        scenarios += 1

        let short = IOStagingOwnershipRegistry(fileStore: store, storageReserveBytes: 0, leaseDuration: 1, fileManager: fm)
        let token4 = UUID().uuidString.lowercased(); let name4 = token4 + ".provider-partial"
        let file4 = store.stagingURL.appendingPathComponent(name4)
        _ = fm.createFile(atPath: file4.path, contents: Data([9]))
        _ = try short.acquire(token: token4, stagingFilename: name4, reservedBytes: 1, now: Date(timeIntervalSince1970: 100))
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: file4.path)
        guard try IOStagingRecovery(fileStore: store).sweep(olderThan: 1, now: Date(timeIntervalSince1970: 200), fileManager: fm) == [name4] else { fatalError("expired partial not swept") }
        scenarios += 1

        let token5 = UUID().uuidString.lowercased(); let name5 = token5 + ".provider-partial"
        let file5 = store.stagingURL.appendingPathComponent(name5)
        _ = fm.createFile(atPath: file5.path, contents: Data([5]))
        let lease5 = try registry.acquire(token: token5, stagingFilename: name5, reservedBytes: 1)
        let leaseURL5 = registry.ledgerURL.appendingPathComponent(token5).appendingPathExtension("json")
        try Data("corrupt".utf8).write(to: leaseURL5)
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: file5.path)
        guard try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, fileManager: fm).isEmpty else { fatalError("corrupt fresh lease not fail-closed") }
        let token6 = UUID().uuidString.lowercased()
        var corruptAdmissionBlocked = false
        do {
            _ = try registry.acquire(token: token6, stagingFilename: token6 + ".provider-partial", reservedBytes: 1)
        } catch IOStagingOwnershipError.leaseCorrupt {
            corruptAdmissionBlocked = true
        }
        guard corruptAdmissionBlocked else { fatalError("corrupt ledger did not block admission") }
        lease5.release(); try? fm.removeItem(at: file5)
        scenarios += 1

        let source = fm.temporaryDirectory.appendingPathComponent("aw16-" + UUID().uuidString).appendingPathExtension("wma")
        defer { try? fm.removeItem(at: source) }
        try Data(repeating: 0x41, count: 512 * 1024).write(to: source)
        let acquirer = IOProviderSnapshotAcquirer(fileStore: store, maximumFileBytes: 2 * 1024 * 1024, storageReserveBytes: 0, chunkBytes: 4096, ownershipHeartbeatBytes: 32 * 1024, fileManager: fm)
        let snapshot = try acquirer.stageProviderSnapshot(at: source, accessMode: .direct, fileManager: fm)
        guard snapshot.stagedFile.descriptor.pathExtension == "wma" else { fatalError("wma extension lost") }
        guard fm.fileExists(atPath: snapshot.stagedFile.stagingURL.path) else { fatalError("ready missing") }
        snapshot.ownership.release(); try? fm.removeItem(at: snapshot.stagedFile.stagingURL)
        scenarios += 1

        let before = Set(try fm.contentsOfDirectory(atPath: store.stagingURL.path))
        let cancelled = await Task.detached { () -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try acquirer.stageProviderSnapshot(at: source, accessMode: .direct, fileManager: fm)
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }.value
        let after = Set(try fm.contentsOfDirectory(atPath: store.stagingURL.path))
        guard cancelled, before == after else { fatalError("cancelled snapshot leaked staging") }
        scenarios += 1

        let clock = ContinuousClock(); let start = clock.now
        for _ in 0..<1_000 {
            let t = UUID().uuidString.lowercased()
            let lease = try registry.acquire(token: t, stagingFilename: t + ".provider-partial", reservedBytes: 1024)
            try lease.heartbeat(writtenBytes: 512)
            try lease.heartbeat(writtenBytes: 1024)
            lease.release()
        }
        let elapsed = start.duration(to: clock.now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        scenarios += 1
        print(String(format: "L2_AW16_SELF_TEST_PASS scenarios=%d lease_cycles=1000 elapsed_seconds=%.6f", scenarios, seconds))
    }
}
