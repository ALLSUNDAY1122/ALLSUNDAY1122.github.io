import Foundation

private struct Journal: Codable {
    let projectUUID: UUID
    let createdAt: Date
}

private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", value))!
}

private func write(_ journal: Journal, to directory: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(journal).write(
        to: directory.appendingPathComponent(journal.projectUUID.uuidString + ".json"),
        options: [.atomic]
    )
}

private func bounded(_ directory: URL, limit: Int) throws -> [Journal] {
    let effective = min(max(limit, 1), 256)
    let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    ) else { return [] }
    var urls: [URL] = []
    for case let url as URL in enumerator {
        guard url.pathExtension == "json" else { continue }
        let values = try url.resourceValues(forKeys: Set(keys))
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw NSError(domain: "AW37", code: 1)
        }
        urls.append(url)
        if urls.count >= effective { break }
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try urls.map { try decoder.decode(Journal.self, from: Data(contentsOf: $0)) }
}

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("L2AW37-" + UUID().uuidString, isDirectory: true)
defer { try? fm.removeItem(at: root) }
try fm.createDirectory(at: root, withIntermediateDirectories: true)
for value in 0..<10_000 {
    try write(Journal(projectUUID: id(value), createdAt: Date(timeIntervalSince1970: Double(value))), to: root)
}
let first = try bounded(root, limit: 64)
let boundedCount = first.count == 64
for journal in first {
    try fm.removeItem(at: root.appendingPathComponent(journal.projectUUID.uuidString + ".json"))
}
let second = try bounded(root, limit: 64)
let progress = second.count == 64 && Set(first.map(\.projectUUID)).isDisjoint(with: Set(second.map(\.projectUUID)))
let maxClamp = try bounded(root, limit: 10_000).count == 256
let pass = boundedCount && progress && maxClamp
print("L2_AW37_SELF_TEST_\(pass ? "PASS" : "FAIL") backlog=10000 first=\(first.count) second=\(second.count) max_clamp=\(maxClamp) progress=\(progress)")
if !pass { exit(1) }
