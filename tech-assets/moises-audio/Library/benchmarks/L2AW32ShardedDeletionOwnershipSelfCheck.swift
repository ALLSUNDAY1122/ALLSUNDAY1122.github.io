import Foundation

@main
struct AW32SelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("AW32-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        try index.ensureLayout()

        func record(_ project: UUID, _ n: Int, source: UUID = UUID()) throws -> Lane2DeletionOwnershipRecord {
            try .init(projectUUID: project, sourceAssetUUID: source, artifactRelativePaths: ["Imports/p\(n)/source.m4a", "Stems/p\(n)/vocals.m4a"], createdAt: Date(timeIntervalSince1970: Double(1_000_000 + n)))
        }

        var scenarios = 0
        let p = UUID(); let r = try record(p, 0)
        let url = try index.persist(r)
        precondition(url.path.contains("/Shards/"))
        let roundTrip = try index.record(projectUUID: p)
        precondition(roundTrip == r)
        scenarios += 1

        // Simulate pre-AW32 flat ownership backlog without using persist().
        let flatDir = root.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]; enc.dateEncodingStrategy = .iso8601
        var legacyIDs: [UUID] = []
        for n in 1...257 {
            let id = UUID(); legacyIDs.append(id)
            let rr = try record(id, n)
            try enc.encode(rr).write(to: flatDir.appendingPathComponent(id.uuidString + ".json"), options: [.atomic])
        }
        var migrated = Set<UUID>()
        var passes = 0
        while migrated.count < 257 && passes < 16 {
            let slice = try index.pendingRecordSlice(limit: 64)
            precondition(slice.records.count <= 64)
            for rr in slice.records where legacyIDs.contains(rr.projectUUID) { migrated.insert(rr.projectUUID) }
            for rr in slice.records where rr.projectUUID != p { try index.remove(projectUUID: rr.projectUUID) }
            passes += 1
        }
        precondition(migrated.count == 257)
        scenarios += 1

        // Excluded journal-backed ownership remains directly addressable and is not selected.
        let excluded = UUID(); let excludedRecord = try record(excluded, 500)
        try index.persist(excludedRecord)
        let selected = try index.pendingRecordSlice(limit: 8, excludingProjectUUIDs: [excluded])
        precondition(!selected.records.contains(where: { $0.projectUUID == excluded }))
        let excludedRoundTrip = try index.record(projectUUID: excluded)
        precondition(excludedRoundTrip == excludedRecord)
        scenarios += 1

        // Duplicate flat/sharded disagreement fails closed.
        let conflictProject = UUID(); let sourceA = UUID(); let sourceB = UUID()
        let sharded = try record(conflictProject, 600, source: sourceA)
        try index.persist(sharded)
        let conflicting = try record(conflictProject, 600, source: sourceB)
        try enc.encode(conflicting).write(to: flatDir.appendingPathComponent(conflictProject.uuidString + ".json"), options: [.atomic])
        do {
            _ = try index.record(projectUUID: conflictProject)
            fatalError("expected identity conflict")
        } catch {
            let text = String(describing: error)
            precondition(text.contains("identityConflict"))
            precondition(text.lowercased().contains(conflictProject.uuidString.lowercased()))
        }
        scenarios += 1
        try? fm.removeItem(at: flatDir.appendingPathComponent(conflictProject.uuidString + ".json"))
        try index.remove(projectUUID: conflictProject)

        // Corrupt active-shard manifest fails closed.
        let marker = flatDir.appendingPathComponent(".active-shards-v2.json")
        try Data("not-json".utf8).write(to: marker, options: [.atomic])
        do {
            _ = try index.pendingRecordSlice(limit: 8)
            fatalError("expected corrupt manifest")
        } catch {
            precondition(String(describing: error).contains("recordCorrupt"))
        }
        scenarios += 1

        // Four manifest-only crash signals must not starve a later real shard forever.
        let crashRoot = fm.temporaryDirectory.appendingPathComponent("AW32-empty-signals-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: crashRoot) }
        let crashIndex = Lane2DeletionOwnershipIndex(rootURL: crashRoot)
        try crashIndex.ensureLayout()
        var realProject = UUID()
        while (0...3).contains(Lane2DeletionOwnershipIndex.shardIndex(for: realProject)) { realProject = UUID() }
        let realRecord = try Lane2DeletionOwnershipRecord(projectUUID: realProject, sourceAssetUUID: UUID(), artifactRelativePaths: ["Imports/real/source.m4a"])
        let realShard = Lane2DeletionOwnershipIndex.shardIndex(for: realProject)
        let crashDir = crashRoot.appendingPathComponent(".LibraryRecovery/DeleteOwnership", isDirectory: true)
        let realDir = crashDir.appendingPathComponent("Shards/" + String(format: "%02x", realShard), isDirectory: true)
        try fm.createDirectory(at: realDir, withIntermediateDirectories: true)
        try enc.encode(realRecord).write(to: realDir.appendingPathComponent(realProject.uuidString + ".json"), options: [.atomic])
        let manifestData = try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "shardIndices": [0, 1, 2, 3, realShard]], options: [.sortedKeys])
        try manifestData.write(to: crashDir.appendingPathComponent(".active-shards-v2.json"), options: [.atomic])
        let emptyPass = try crashIndex.pendingRecordSlice(limit: 8)
        precondition(emptyPass.records.isEmpty)
        precondition(emptyPass.hasMore)
        let realPass = try crashIndex.pendingRecordSlice(limit: 8)
        precondition(realPass.records.map(\.projectUUID) == [realProject])
        scenarios += 1

        print("L2_AW32_SELF_TEST_PASS scenarios=\(scenarios) legacy_records=257 migration_passes=\(passes) slice_limit=64 shard_count=\(Lane2DeletionOwnershipIndex.shardCount) shard_visit_limit=\(Lane2DeletionOwnershipIndex.defaultShardVisitLimit) conflict_fail_closed=true manifest_fail_closed=true empty_signal_recovery=true")
    }
}
