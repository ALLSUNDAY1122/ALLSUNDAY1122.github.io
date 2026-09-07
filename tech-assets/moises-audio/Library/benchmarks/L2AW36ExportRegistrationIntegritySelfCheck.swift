import Foundation

struct Fingerprint: Codable, Equatable {
    let name: String
    let bytes: Int
    let digest: UInt64
}

func digest(_ data: Data) -> UInt64 {
    var value: UInt64 = 14_695_981_039_346_656_037
    for byte in data {
        value ^= UInt64(byte)
        value &*= 1_099_511_628_211
    }
    return value
}

func fingerprint(_ url: URL) throws -> Fingerprint {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else { throw NSError(domain: "AW36", code: 1) }
    let data = try Data(contentsOf: url)
    guard !data.isEmpty else { throw NSError(domain: "AW36", code: 2) }
    return Fingerprint(name: url.lastPathComponent, bytes: data.count, digest: digest(data))
}

func verify(directory: URL, expected: [Fingerprint]) throws {
    let expectedNames = Set(expected.map(\.name))
    for item in expected {
        guard try fingerprint(directory.appendingPathComponent(item.name)) == item else { throw NSError(domain: "AW36", code: 3) }
    }
    let children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    guard Set(children.map(\.lastPathComponent)) == expectedNames else { throw NSError(domain: "AW36", code: 4) }
}

func rejected(_ body: () throws -> Void) -> Bool {
    do { try body(); return false } catch { return true }
}

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("L2AW36-" + UUID().uuidString, isDirectory: true)
defer { try? fm.removeItem(at: root) }
try fm.createDirectory(at: root, withIntermediateDirectories: true)
let media = root.appendingPathComponent("mix.m4a")
let original = Data(repeating: 0x31, count: 4096)
try original.write(to: media)
let manifest = [try fingerprint(media)]
try verify(directory: root, expected: manifest)

try (original + Data([0x41])).write(to: media)
let sizeChange = rejected { try verify(directory: root, expected: manifest) }
try original.write(to: media)
var sameSize = original
sameSize[0] ^= 0xff
try sameSize.write(to: media)
let sameSizeMutation = rejected { try verify(directory: root, expected: manifest) }
try original.write(to: media)
let extra = root.appendingPathComponent("unexpected.bin")
try Data([1]).write(to: extra)
let unexpectedFile = rejected { try verify(directory: root, expected: manifest) }
try fm.removeItem(at: extra)
let replacement = root.appendingPathComponent("replacement.m4a")
try original.write(to: replacement)
try fm.removeItem(at: media)
try fm.createSymbolicLink(at: media, withDestinationURL: replacement)
let symlink = rejected { try verify(directory: root, expected: manifest) }

let pass = sizeChange && sameSizeMutation && unexpectedFile && symlink
print("L2_AW36_SELF_TEST_\(pass ? "PASS" : "FAIL") size_change=\(sizeChange) same_size=\(sameSizeMutation) unexpected=\(unexpectedFile) symlink=\(symlink)")
if !pass { exit(1) }
