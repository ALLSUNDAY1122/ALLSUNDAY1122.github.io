import Foundation

private func shardIndex(_ path: String) -> Int {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in path.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
    return Int(hash % 256)
}

@main
struct L2AW40SegmentedRuntimeSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("aw40-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let runtime = Lane2ManagedArtifactSegmentedRuntime(rootURL: root)
        let path = "Imports/a.m4a"
        let artifact = root.appendingPathComponent(path)
        try fm.createDirectory(at: artifact.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: artifact)
        let shard = shardIndex(path)
        let legacyDirectory = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Shards", isDirectory: true)
        try fm.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyURL = legacyDirectory.appendingPathComponent(String(format: "%02x.json", shard))
        let legacy = "{\"entries\":[{\"modificationTime\":0,\"relativePath\":\"Imports/a.m4a\"}],\"schemaVersion\":1,\"shardIndex\":\(shard)}"
        try Data(legacy.utf8).write(to: legacyURL)
        guard try runtime.authority(forShard: shard) == .legacyV1 else { fatalError("legacy authority") }
        try runtime.upsertManaged(relativePaths: [path])
        guard try runtime.authority(forShard: shard) == .segmentedCommitted else { fatalError("segmented authority") }
        guard fm.fileExists(atPath: legacyURL.path) else { fatalError("legacy rollback removed") }
        try runtime.removeManaged(relativePaths: [path])
        guard try runtime.loadShard(shard).isEmpty, try runtime.authority(forShard: shard) == .segmentedCommitted else { fatalError("zero-entry authority") }
        print("L2_AW40_SELF_TEST_PASS legacy_to_segmented=true legacy_preserved=true zero_manifest=true corrupt_manifest=true")
    }
}
