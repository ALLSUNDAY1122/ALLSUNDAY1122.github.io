import Foundation

@main
struct L2AW52SegmentedMigrationAuthoritySelfCheck {
    static let fm = FileManager.default

    static func root(_ tag: String) throws -> URL {
        let r = fm.temporaryDirectory.appendingPathComponent("aw52-\(tag)-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: r, withIntermediateDirectories: true)
        return r
    }

    static func legacyURL(_ root: URL, _ shard: Int) -> URL {
        root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Shards", isDirectory: true)
            .appendingPathComponent(String(format: "%02x.json", shard))
    }

    static func segmented(_ root: URL) -> URL {
        root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true)
    }

    static func writeLegacy(_ root: URL, shard: Int, count: Int) throws -> [Lane2ManagedArtifactSegmentEntry] {
        struct Legacy: Codable { let schemaVersion: Int; let shardIndex: Int; let entries: [Lane2ManagedArtifactSegmentEntry] }
        let entries = (0..<count).map { Lane2ManagedArtifactSegmentEntry(relativePath: String(format: "Imports/%04d.m4a", $0), modificationTime: Double($0)) }
        let u = legacyURL(root, shard)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Legacy(schemaVersion: 1, shardIndex: shard, entries: entries)).write(to: u, options: [.atomic])
        return entries
    }

    static func expectThrow(_ body: () throws -> Void) -> Bool {
        do { try body(); return false } catch { return true }
    }

    static func main() throws {
        var checks = 0

        do {
            let r = try root("normal"); defer { try? fm.removeItem(at: r) }
            let entries = try writeLegacy(r, shard: 7, count: 1300)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            let result = try s.migrateLegacyShardIfNeeded(7)
            precondition(result.migrated && result.entryCount == 1300 && result.segmentCount == 3)
            let loaded7 = try s.loadCommittedEntries(7)
            precondition(loaded7 == entries)
            precondition(!fm.fileExists(atPath: segmented(r).appendingPathComponent("07.pending.json").path))
            checks += 1
        }

        do {
            let r = try root("segdir"); defer { try? fm.removeItem(at: r) }
            let ext = try root("external-seg"); defer { try? fm.removeItem(at: ext) }
            let parent = segmented(r).deletingLastPathComponent()
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let outside = ext.appendingPathComponent("01.pending.json")
            try Data("keep".utf8).write(to: outside)
            try fm.createSymbolicLink(at: segmented(r), withDestinationURL: ext)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            precondition(expectThrow { _ = try s.removeUncommittedGenerations(shardIndex: 1) })
            let outsideData = try Data(contentsOf: outside)
            precondition(outsideData == Data("keep".utf8))
            checks += 1
        }

        do {
            let r = try root("dangling-manifest"); defer { try? fm.removeItem(at: r) }
            _ = try writeLegacy(r, shard: 2, count: 1)
            let seg = segmented(r); try fm.createDirectory(at: seg, withIntermediateDirectories: true)
            let missing = r.appendingPathComponent("missing-manifest-target")
            try fm.createSymbolicLink(at: seg.appendingPathComponent("02.manifest.json"), withDestinationURL: missing)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            precondition(expectThrow { _ = try s.migrateLegacyShardIfNeeded(2) })
            checks += 1
        }

        do {
            let r = try root("legacy-parent"); defer { try? fm.removeItem(at: r) }
            let ext = try root("external-legacy"); defer { try? fm.removeItem(at: ext) }
            let v1 = r.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1", isDirectory: true)
            try fm.createDirectory(at: v1, withIntermediateDirectories: true)
            let externalLegacy = ext.appendingPathComponent("03.json")
            let payload = "{\"schemaVersion\":1,\"shardIndex\":3,\"entries\":[]}"
            try Data(payload.utf8).write(to: externalLegacy)
            try fm.createSymbolicLink(at: v1.appendingPathComponent("Shards", isDirectory: true), withDestinationURL: ext)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            precondition(expectThrow { _ = try s.migrateLegacyShardIfNeeded(3) })
            let externalLegacyData = try Data(contentsOf: externalLegacy)
            precondition(externalLegacyData == Data(payload.utf8))
            checks += 1
        }

        do {
            let r = try root("segment-link"); defer { try? fm.removeItem(at: r) }
            let ext = try root("external-segment"); defer { try? fm.removeItem(at: ext) }
            let seg = segmented(r); try fm.createDirectory(at: seg, withIntermediateDirectories: true)
            let generation = UUID()
            let manifest: [String: Any] = ["schemaVersion": 1, "shardIndex": 4, "generation": generation.uuidString, "segmentCount": 1, "entryCount": 1]
            let md = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
            try md.write(to: seg.appendingPathComponent("04.manifest.json"))
            let target = ext.appendingPathComponent("segment.json")
            try Data("{}".utf8).write(to: target)
            let name = String(format: "04.%@.%04d.json", generation.uuidString, 0)
            try fm.createSymbolicLink(at: seg.appendingPathComponent(name), withDestinationURL: target)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            precondition(expectThrow { _ = try s.loadCommittedEntries(4) })
            let segmentTargetData = try Data(contentsOf: target)
            precondition(segmentTargetData == Data("{}".utf8))
            checks += 1
        }

        do {
            let r = try root("pending-link"); defer { try? fm.removeItem(at: r) }
            let ext = try root("external-pending"); defer { try? fm.removeItem(at: ext) }
            let seg = segmented(r); try fm.createDirectory(at: seg, withIntermediateDirectories: true)
            let target = ext.appendingPathComponent("keep.json")
            try Data("keep".utf8).write(to: target)
            try fm.createSymbolicLink(at: seg.appendingPathComponent("01.pending.json"), withDestinationURL: target)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            precondition(expectThrow { _ = try s.removeUncommittedGenerations(shardIndex: 1) })
            let pendingTargetData = try Data(contentsOf: target)
            precondition(pendingTargetData == Data("keep".utf8))
            checks += 1
        }

        do {
            let r = try root("cleanup"); defer { try? fm.removeItem(at: r) }
            let entries = try writeLegacy(r, shard: 1, count: 3)
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            _ = try s.migrateLegacyShardIfNeeded(1)
            let seg = segmented(r)
            try Data("junk".utf8).write(to: seg.appendingPathComponent("01.pending.json"))
            try Data("junk".utf8).write(to: seg.appendingPathComponent("01.00000000-0000-0000-0000-000000000000.0000.json"))
            let removedCleanup = try s.removeUncommittedGenerations(shardIndex: 1)
            let loadedCleanup = try s.loadCommittedEntries(1)
            precondition(removedCleanup == 2)
            precondition(loadedCleanup == entries)
            checks += 1
        }

        do {
            let r = try root("overflow"); defer { try? fm.removeItem(at: r) }
            let seg = segmented(r); try fm.createDirectory(at: seg, withIntermediateDirectories: true)
            let payload = "{\"schemaVersion\":1,\"shardIndex\":6,\"generation\":\"\(UUID().uuidString)\",\"segmentCount\":1,\"entryCount\":9223372036854775807}"
            try Data(payload.utf8).write(to: seg.appendingPathComponent("06.manifest.json"))
            let s = Lane2ManagedArtifactSegmentedShardStore(rootURL: r)
            precondition(expectThrow { _ = try s.loadCommittedEntries(6) })
            checks += 1
        }

        let benchRoot = try root("bench"); defer { try? fm.removeItem(at: benchRoot) }
        let seg = segmented(benchRoot); try fm.createDirectory(at: seg, withIntermediateDirectories: true)
        for i in 0..<1000 {
            try Data([0x41]).write(to: seg.appendingPathComponent(String(format: "05.junk.%04d.json", i)))
        }
        let store = Lane2ManagedArtifactSegmentedShardStore(rootURL: benchRoot)
        let start = ContinuousClock.now
        let removed = try store.removeUncommittedGenerations(shardIndex: 5)
        let elapsed = start.duration(to: .now)
        let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        precondition(removed == 1000)

        print(String(format: "L2_AW52_SELF_TEST_PASS checks=%d segmented_symlink=true dangling_manifest=true legacy_parent=true segment_symlink=true pending_symlink=true cleanup=true overflow_guard=true cleanup_1000_ms=%.3f", checks, ms))
    }
}
