import Foundation

@main
struct L2AW51PrejournalDispositionAuthoritySelfCheck {
    static let fm = FileManager.default

    static func main() async throws {
        var checks = 0
        try await checkUnsafeDispositionRoot(&checks)
        try await checkDanglingRecoveredDestination(&checks)
        try await checkDispositionLeafSymlink(&checks)
        try await checkPendingRootSymlinkInventory(&checks)
        try await checkRelaunchPreserveIntent(&checks)
        try await checkSymlinkBatchPurgeIntent(&checks)
        try await checkNormalPreservePurge(&checks)

        let benchBase = fm.temporaryDirectory.appendingPathComponent("L2-AW51-BENCH-\(UUID().uuidString)", isDirectory: true)
        let benchRoot = benchBase.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: benchRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: benchBase) }
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: benchRoot, fileManager: fm)
        let rounds = 200
        let start = Date()
        for _ in 0..<rounds {
            let id = UUID().uuidString.lowercased()
            try makeBatch(root: benchRoot, id: id)
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else {
                fatalError("missing benchmark batch")
            }
            let recovered = try await manager.preserveForUser(batchID: id, snapshotToken: batch.snapshotToken)
            try await manager.purgeRecovered(batchID: id, snapshotToken: recovered.snapshotToken)
        }
        let ms = Date().timeIntervalSince(start) * 1000
        print(String(
            format: "L2_AW51_SELF_TEST_PASS checks=%d disposition_root=true dangling_destination=true disposition_leaf=true pending_root=true relaunch_preserve=true symlink_purge=true normal_preserve_purge=true preserve_purge_200_ms=%.3f per_cycle_us=%.3f",
            checks, ms, ms * 1000 / Double(rounds)
        ))
    }

    static func checkUnsafeDispositionRoot(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-A-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root.appendingPathComponent(".LibraryRecovery", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let disposition = root.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
        try fm.createSymbolicLink(at: disposition, withDestinationURL: external)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        do {
            _ = try await manager.recoverPendingDispositions()
            fatalError("disposition root symlink accepted")
        } catch Lane2PrejournalQuarantineFailure.fileOperationFailed {
            guard try fm.contentsOfDirectory(atPath: external.path).isEmpty else { fatalError("external changed") }
            checks += 1
        }
    }

    static func checkDanglingRecoveredDestination(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-B-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let id = UUID().uuidString.lowercased()
        try makeBatch(root: root, id: id)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        let inv = await manager.inventory()
        guard let batch = inv.pending.first else { fatalError("missing pending") }

        let recoveredRoot = root.appendingPathComponent(".LibraryRecovery/RecoveredPrejournalExport", isDirectory: true)
        try fm.createDirectory(at: recoveredRoot, withIntermediateDirectories: true)
        let destination = recoveredRoot.appendingPathComponent(id, isDirectory: true)
        let externalMissing = base.appendingPathComponent("external-missing", isDirectory: true)
        try fm.createSymbolicLink(at: destination, withDestinationURL: externalMissing)
        do {
            _ = try await manager.preserveForUser(batchID: id, snapshotToken: batch.snapshotToken)
            fatalError("dangling destination accepted")
        } catch {
            let pending = root.appendingPathComponent(".LibraryRecovery/PrejournalExport/\(id)", isDirectory: true)
            guard try FileManager.default.attributesOfItem(atPath: pending.path)[.type] as? FileAttributeType == .typeDirectory else {
                fatalError("pending batch lost")
            }
            guard !fm.fileExists(atPath: externalMissing.path) else { fatalError("external target created") }
            checks += 1
        }
    }

    static func checkDispositionLeafSymlink(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-C-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external.json")
        let dispositions = root.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
        try fm.createDirectory(at: dispositions, withIntermediateDirectories: true)
        try Data("sentinel".utf8).write(to: external)
        defer { try? fm.removeItem(at: base) }
        let link = dispositions.appendingPathComponent(UUID().uuidString + ".json")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        do {
            _ = try await manager.recoverPendingDispositions()
            fatalError("disposition leaf symlink accepted")
        } catch Lane2PrejournalQuarantineFailure.corruptDisposition {
            guard try Data(contentsOf: external) == Data("sentinel".utf8) else { fatalError("external mutated") }
            checks += 1
        }
    }

    static func checkPendingRootSymlinkInventory(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-D-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root.appendingPathComponent(".LibraryRecovery", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let pending = root.appendingPathComponent(".LibraryRecovery/PrejournalExport", isDirectory: true)
        try fm.createSymbolicLink(at: pending, withDestinationURL: external)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        let inv = await manager.inventory()
        guard inv.pending.isEmpty, inv.issues.contains(where: { $0.stableCode == "UNSAFE_ROOT" }) else {
            fatalError("unsafe pending root not surfaced")
        }
        checks += 1
    }

    static func checkRelaunchPreserveIntent(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-F-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let id = UUID().uuidString.lowercased()
        try makeBatch(root: root, id: id)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        let inv = await manager.inventory()
        guard let batch = inv.pending.first else { fatalError("missing relaunch batch") }
        try writeIntent(root: root, kind: "preserveForUser", batchID: id, snapshotToken: batch.snapshotToken)
        let report = try await manager.recoverPendingDispositions()
        guard report.completedPreserves == 1 else { fatalError("relaunch preserve not counted") }
        let recovered = root.appendingPathComponent(".LibraryRecovery/RecoveredPrejournalExport/\(id)", isDirectory: true)
        guard fm.fileExists(atPath: recovered.path) else { fatalError("relaunch preserve did not move") }
        checks += 1
    }

    static func checkSymlinkBatchPurgeIntent(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-G-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root.appendingPathComponent(".LibraryRecovery/PrejournalExport", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data("sentinel".utf8).write(to: external.appendingPathComponent("keep.txt"))
        defer { try? fm.removeItem(at: base) }
        let id = UUID().uuidString.lowercased()
        let link = root.appendingPathComponent(".LibraryRecovery/PrejournalExport/\(id)", isDirectory: true)
        try fm.createSymbolicLink(at: link, withDestinationURL: external)
        try writeIntent(root: root, kind: "purgePending", batchID: id, snapshotToken: "v1-deadbeef")
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        do {
            _ = try await manager.recoverPendingDispositions()
            fatalError("symlink batch purge intent executed")
        } catch Lane2PrejournalQuarantineFailure.symlinkRejected {
            guard try Data(contentsOf: external.appendingPathComponent("keep.txt")) == Data("sentinel".utf8) else {
                fatalError("external purge target changed")
            }
            let dispositions = root.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
            guard !(try fm.contentsOfDirectory(atPath: dispositions.path)).isEmpty else {
                fatalError("failed destructive intent was retired")
            }
            checks += 1
        }
    }

    static func writeIntent(root: URL, kind: String, batchID: String, snapshotToken: String) throws {
        let dispositions = root.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
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

    static func checkNormalPreservePurge(_ checks: inout Int) async throws {
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW51-E-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let id = UUID().uuidString.lowercased()
        try makeBatch(root: root, id: id)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root, fileManager: fm)
        let inv = await manager.inventory()
        guard let batch = inv.pending.first else { fatalError("missing normal pending") }
        let recovered = try await manager.preserveForUser(batchID: id, snapshotToken: batch.snapshotToken)
        let urls = try await manager.recoveredArtifactURLs(batchID: id, snapshotToken: recovered.snapshotToken)
        guard urls.map(\.lastPathComponent) == ["Mix.m4a"] else { fatalError("bad recovered urls") }
        try await manager.purgeRecovered(batchID: id, snapshotToken: recovered.snapshotToken)
        let final = await manager.inventory()
        guard final.pending.isEmpty, final.recoveredForUser.isEmpty else { fatalError("normal purge incomplete") }
        checks += 1
    }

    static func makeBatch(root: URL, id: String) throws {
        let dir = root.appendingPathComponent(".LibraryRecovery/PrejournalExport/\(id)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("previous-process-session\n".utf8).write(
            to: dir.appendingPathComponent(".lane2-registration-pending")
        )
        try Data(repeating: 0x44, count: 32).write(
            to: dir.appendingPathComponent("Mix.m4a")
        )
    }
}
