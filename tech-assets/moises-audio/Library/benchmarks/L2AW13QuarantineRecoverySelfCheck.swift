import Foundation

@main
struct L2AW13SelfCheck {
    static func main() async throws {
        var scenarios = 0
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("L2AW13-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        func exportDir() -> URL { root.appendingPathComponent(".LibraryLifecycle/v2/exports", isDirectory: true) }
        func write(_ records: [Lane2ExportRecord], name: String) throws {
            let url = exportDir().appendingPathComponent(name)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
            try e.encode(records).write(to: url)
        }
        func rec(_ project: UUID, _ i: Int) -> Lane2ExportRecord {
            Lane2ExportRecord(id: UUID(), projectUUID: project, relativePath: "Exports/Batches/\(project.uuidString)/Stem\(i).m4a", mediaType: "audio/mp4", createdAt: Date(timeIntervalSince1970: Double(i)), state: .ready)
        }
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "L2AW13", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }

        let valid = UUID()
        try write([rec(valid, 0)], name: valid.uuidString + ".json")
        let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)
        let firstBarrier = try await guarder.prepareBarrierForCurrentCorruptExportShards()
        try expect(firstBarrier == nil, "valid shard created barrier")
        scenarios += 1

        let corrupt = UUID()
        let corruptURL = exportDir().appendingPathComponent(corrupt.uuidString + ".json")
        try Data("broken".utf8).write(to: corruptURL)
        let barrier = try await guarder.prepareBarrierForCurrentCorruptExportShards()
        try expect(barrier?.affectedProjectUUIDs == [corrupt], "attributed corrupt shard not captured")
        try expect(fm.fileExists(atPath: corruptURL.path), "scan moved shard before barrier")
        scenarios += 1

        try fm.removeItem(at: corruptURL)
        do {
            try await guarder.requireExportMetadataConsistent()
            throw NSError(domain: "L2AW13", code: 2)
        } catch Lane2LifecycleQuarantineRecoveryFailure.exportRecoveryBarrierActive {}
        scenarios += 1

        try await guarder.clearBarrier()
        let malformed = exportDir().appendingPathComponent("bad-name.json")
        try Data("[]".utf8).write(to: malformed)
        let unattributed = try await guarder.prepareBarrierForCurrentCorruptExportShards()
        try expect(unattributed?.hasUnattributedShard == true, "malformed filename not unattributed")
        scenarios += 1

        try await guarder.clearBarrier()
        _ = try await guarder.prepareBarrierForLegacyCorruption()
        let v2 = root.appendingPathComponent(".LibraryLifecycle/v2", isDirectory: true)
        try? fm.removeItem(at: v2)
        let legacyBarrier = try await guarder.barrier()
        try expect(legacyBarrier?.hasUnattributedShard == true, "legacy barrier did not survive v2 reset")
        scenarios += 1

        let a = UUID(), b = UUID()
        let explicit = Lane2ExportMetadataQuarantineBarrier(corruptExportShardRelativePaths: ["a","b"], affectedProjectUUIDs: [a,b], hasUnattributedShard: false)
        do {
            try await guarder.validate(resolution: .init(acknowledgedEmptyProjectUUIDs: [a]), against: explicit)
            throw NSError(domain: "L2AW13", code: 3)
        } catch Lane2LifecycleQuarantineRecoveryFailure.incompleteAttributedRecovery {}
        try await guarder.validate(resolution: .init(acknowledgedEmptyProjectUUIDs: [a,b]), against: explicit)
        scenarios += 1

        try await guarder.clearBarrier()
        try? fm.removeItem(at: exportDir())
        try fm.createDirectory(at: exportDir(), withIntermediateDirectories: true)
        let benchmarkCount = 1000
        let start = Date()
        for i in 0..<benchmarkCount {
            let project = UUID()
            try write([rec(project, i)], name: project.uuidString + ".json")
        }
        let badProject = UUID()
        try Data("{".utf8).write(to: exportDir().appendingPathComponent(badProject.uuidString + ".json"))
        let benchBarrier = try await guarder.prepareBarrierForCurrentCorruptExportShards()
        let elapsed = Date().timeIntervalSince(start)
        try expect(benchBarrier?.affectedProjectUUIDs.contains(badProject) == true, "benchmark corrupt shard not found")
        scenarios += 1

        let elapsedText = String(format: "%.6f", elapsed)
        print("L2_AW13_SELF_TEST_PASS scenarios=\(scenarios) shards=\(benchmarkCount + 1) elapsed_seconds=\(elapsedText)")
    }
}
