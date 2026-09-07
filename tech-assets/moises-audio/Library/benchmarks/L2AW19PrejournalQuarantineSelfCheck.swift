import Foundation

@main
struct L2AW19PrejournalQuarantineSelfCheck {
    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("l2-aw19-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let pending = root.appendingPathComponent(".LibraryRecovery/PrejournalExport", isDirectory: true)
        let recovered = root.appendingPathComponent(".LibraryRecovery/RecoveredPrejournalExport", isDirectory: true)
        let dispositions = root.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
        try fm.createDirectory(at: pending, withIntermediateDirectories: true)
        let manager = Lane2PrejournalExportQuarantineManager(rootURL: root)
        var scenarios = 0

        func makeBatch(_ id: String, files: [(String, Int)]) throws {
            let dir = pending.appendingPathComponent(id, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: false)
            try Data("old-process\n".utf8).write(to: dir.appendingPathComponent(".lane2-registration-pending"))
            for (name, count) in files {
                try Data(repeating: 0x55, count: count).write(to: dir.appendingPathComponent(name))
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

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Vocals.m4a", 128), ("Drums.m4a", 64)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }), batch.totalBytes == 192,
                  batch.artifacts.map(\.filename) == ["Drums.m4a", "Vocals.m4a"] else {
                fatalError("inventory mismatch")
            }
            scenarios += 1
        }

        do {
            let good = UUID().uuidString.lowercased()
            try makeBatch(good, files: [("Mix.m4a", 32)])
            let bad = UUID().uuidString.lowercased()
            let badDir = pending.appendingPathComponent(bad, isDirectory: true)
            try fm.createDirectory(at: badDir, withIntermediateDirectories: false)
            try Data([1]).write(to: badDir.appendingPathComponent("Mix.m4a"))
            let inv = await manager.inventory()
            guard inv.pending.contains(where: { $0.batchID == good }),
                  inv.issues.contains(where: { $0.batchName == bad && $0.stableCode == "MISSING_MARKER" }) else {
                fatalError("malformed batch hid inventory")
            }
            try fm.removeItem(at: badDir)
            scenarios += 1
        }

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Keep.m4a", 80)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else { fatalError("missing preserve batch") }
            let kept = try await manager.preserveForUser(batchID: id, snapshotToken: batch.snapshotToken)
            let urls = try await manager.recoveredArtifactURLs(batchID: id, snapshotToken: kept.snapshotToken)
            guard urls.map(\.lastPathComponent) == ["Keep.m4a"],
                  fm.fileExists(atPath: recovered.appendingPathComponent(id).path),
                  !fm.fileExists(atPath: pending.appendingPathComponent(id).path) else {
                fatalError("preserve failed")
            }
            scenarios += 1
        }

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Stale.m4a", 10)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else { fatalError("missing stale batch") }
            try Data(repeating: 0x11, count: 11).write(to: pending.appendingPathComponent(id).appendingPathComponent("Stale.m4a"))
            var rejected = false
            do {
                try await manager.purgePending(batchID: id, snapshotToken: batch.snapshotToken)
            } catch Lane2PrejournalQuarantineFailure.staleSnapshot {
                rejected = true
            }
            guard rejected, fm.fileExists(atPath: pending.appendingPathComponent(id).path) else { fatalError("stale purge not rejected") }
            try fm.removeItem(at: pending.appendingPathComponent(id))
            scenarios += 1
        }

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Resume.m4a", 20)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else { fatalError("missing resume batch") }
            try writeIntent(kind: "preserveForUser", batchID: id, snapshotToken: batch.snapshotToken)
            let report = try await manager.recoverPendingDispositions()
            guard report.completedPreserves == 1,
                  fm.fileExists(atPath: recovered.appendingPathComponent(id).path) else { fatalError("intent recovery failed") }
            scenarios += 1
        }

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Moved.m4a", 20)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else { fatalError("missing moved batch") }
            try writeIntent(kind: "preserveForUser", batchID: id, snapshotToken: batch.snapshotToken)
            try fm.createDirectory(at: recovered, withIntermediateDirectories: true)
            try fm.moveItem(at: pending.appendingPathComponent(id), to: recovered.appendingPathComponent(id))
            let report = try await manager.recoverPendingDispositions()
            guard report.completedPreserves == 1 else { fatalError("post-move intent recovery failed") }
            scenarios += 1
        }

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Delete.m4a", 40)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else { fatalError("missing purge batch") }
            try await manager.purgePending(batchID: id, snapshotToken: batch.snapshotToken)
            guard !fm.fileExists(atPath: pending.appendingPathComponent(id).path) else { fatalError("pending purge failed") }
            scenarios += 1
        }

        do {
            let id = UUID().uuidString.lowercased()
            try makeBatch(id, files: [("Recovered.m4a", 44)])
            let inv = await manager.inventory()
            guard let batch = inv.pending.first(where: { $0.batchID == id }) else { fatalError("missing recovered purge batch") }
            let kept = try await manager.preserveForUser(batchID: id, snapshotToken: batch.snapshotToken)
            try await manager.purgeRecovered(batchID: id, snapshotToken: kept.snapshotToken)
            guard !fm.fileExists(atPath: recovered.appendingPathComponent(id).path) else { fatalError("recovered purge failed") }
            scenarios += 1
        }

        let benchRoot = fm.temporaryDirectory.appendingPathComponent("l2-aw19-bench-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: benchRoot) }
        let benchPending = benchRoot.appendingPathComponent(".LibraryRecovery/PrejournalExport", isDirectory: true)
        try fm.createDirectory(at: benchPending, withIntermediateDirectories: true)
        for _ in 0..<1000 {
            let id = UUID().uuidString.lowercased()
            let dir = benchPending.appendingPathComponent(id, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: false)
            try Data("old-process\n".utf8).write(to: dir.appendingPathComponent(".lane2-registration-pending"))
            try Data(repeating: 0x22, count: 1024).write(to: dir.appendingPathComponent("Vocals.m4a"))
            try Data(repeating: 0x33, count: 1024).write(to: dir.appendingPathComponent("Drums.m4a"))
        }
        let benchManager = Lane2PrejournalExportQuarantineManager(rootURL: benchRoot)
        let clock = ContinuousClock()
        let start = clock.now
        let bench = await benchManager.inventory()
        let elapsed = start.duration(to: clock.now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        guard bench.pending.count == 1000, bench.issues.isEmpty,
              bench.pending.reduce(UInt64(0), { $0 + $1.totalBytes }) == UInt64(1000 * 2048) else {
            fatalError("scale inventory failed")
        }
        scenarios += 1

        print(String(format: "L2_AW19_SELF_TEST_PASS scenarios=%d batches=1000 artifacts=2000 elapsed_seconds=%.6f", scenarios, seconds))
    }
}
