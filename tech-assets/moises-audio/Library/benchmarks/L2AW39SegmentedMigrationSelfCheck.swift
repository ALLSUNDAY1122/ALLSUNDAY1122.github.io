import Foundation

private struct Entry: Codable, Hashable {
    let relativePath: String
    let modificationTime: Double
}
private struct Legacy: Codable { let schemaVersion: Int; let shardIndex: Int; let entries: [Entry] }
private struct Manifest: Codable { let schemaVersion: Int; let shardIndex: Int; let generation: UUID; let segmentCount: Int; let entryCount: Int }
private struct Segment: Codable { let schemaVersion: Int; let shardIndex: Int; let generation: UUID; let segmentIndex: Int; let entries: [Entry] }

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("L2AW39-" + UUID().uuidString)
defer { try? fm.removeItem(at: root) }
let shards = root.appendingPathComponent("Shards")
let segmented = root.appendingPathComponent("Segmented")
try fm.createDirectory(at: shards, withIntermediateDirectories: true)
try fm.createDirectory(at: segmented, withIntermediateDirectories: true)
let entries = (0..<1300).map { Entry(relativePath: String(format: "Imports/%04d.m4a", $0), modificationTime: Double($0)) }
let legacyURL = shards.appendingPathComponent("07.json")
try JSONEncoder().encode(Legacy(schemaVersion: 1, shardIndex: 7, entries: entries)).write(to: legacyURL, options: [.atomic])

let generation = UUID()
let perSegment = 512
let segmentCount = (entries.count + perSegment - 1) / perSegment
for index in 0..<segmentCount {
    let start = index * perSegment
    let end = min(start + perSegment, entries.count)
    let segment = Segment(schemaVersion: 1, shardIndex: 7, generation: generation, segmentIndex: index, entries: Array(entries[start..<end]))
    try JSONEncoder().encode(segment).write(
        to: segmented.appendingPathComponent(String(format: "07.%@.%04d.json", generation.uuidString, index)),
        options: [.atomic]
    )
}
let pending = segmented.appendingPathComponent("07.pending.json")
let manifest = Manifest(schemaVersion: 1, shardIndex: 7, generation: generation, segmentCount: segmentCount, entryCount: entries.count)
try JSONEncoder().encode(manifest).write(to: pending, options: [.atomic])
let legacyPreserved = fm.fileExists(atPath: legacyURL.path)
let noAuthorityBeforeCommit = !fm.fileExists(atPath: segmented.appendingPathComponent("07.manifest.json").path)
var verified = 0
var bounded = true
for index in 0..<segmentCount {
    let url = segmented.appendingPathComponent(String(format: "07.%@.%04d.json", generation.uuidString, index))
    let segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
    bounded = bounded && segment.entries.count <= perSegment
    verified += segment.entries.count
}
try fm.moveItem(at: pending, to: segmented.appendingPathComponent("07.manifest.json"))
let committed = fm.fileExists(atPath: segmented.appendingPathComponent("07.manifest.json").path)
let pass = legacyPreserved && noAuthorityBeforeCommit && bounded && verified == entries.count && committed
print("L2_AW39_SELF_TEST_\(pass ? "PASS" : "FAIL") entries=\(entries.count) segments=\(segmentCount) legacy_preserved=\(legacyPreserved) precommit_manifest_absent=\(noAuthorityBeforeCommit) bounded=\(bounded)")
if !pass { exit(1) }
