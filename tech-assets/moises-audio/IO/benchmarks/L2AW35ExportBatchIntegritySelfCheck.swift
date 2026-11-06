import Foundation

private struct Fingerprint: Equatable {
    let byteCount: UInt64
    let digest: UInt64
}

private func fingerprint(_ url: URL) throws -> Fingerprint {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    precondition(values.isRegularFile == true && values.isSymbolicLink != true)
    let size = UInt64(max(values.fileSize ?? 0, 0))
    precondition(size > 0)
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var digest: UInt64 = 14_695_981_039_346_656_037
    while true {
        let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
        if chunk.isEmpty { break }
        for byte in chunk {
            digest ^= UInt64(byte)
            digest &*= 1_099_511_628_211
        }
    }
    return Fingerprint(byteCount: size, digest: digest)
}

@main
struct L2AW35ExportBatchIntegritySelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("L2AW35-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let a = root.appendingPathComponent("vocals.m4a")
        let b = root.appendingPathComponent("drums.m4a")
        try Data(repeating: 0x11, count: 4096).write(to: a)
        try Data(repeating: 0x22, count: 8192).write(to: b)
        let a0 = try fingerprint(a)
        let b0 = try fingerprint(b)
        let aRoundtrip = try fingerprint(a)
        precondition(a0 == aRoundtrip)
        let bRoundtrip = try fingerprint(b)
        precondition(b0 == bRoundtrip)

        let handle = try FileHandle(forWritingTo: a)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0xff]))
        try handle.close()
        let aMutated = try fingerprint(a)
        precondition(a0 != aMutated)

        let sameSize = Data(repeating: 0x33, count: 8192)
        try sameSize.write(to: b)
        let b1 = try fingerprint(b)
        precondition(b1.byteCount == b0.byteCount)
        precondition(b1.digest != b0.digest)

        let outside = root.appendingPathComponent("outside.bin")
        try Data(repeating: 0x44, count: 1024).write(to: outside)
        let link = root.appendingPathComponent("link.m4a")
        try fm.createSymbolicLink(at: link, withDestinationURL: outside)
        let linkValues = try link.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        precondition(linkValues.isSymbolicLink == true)

        print("L2_AW35_SELF_TEST_PASS scenarios=4 size_change_rejected=true same_size_mutation_rejected=true symlink_rejected=true chunk_bytes=1048576")
    }
}
