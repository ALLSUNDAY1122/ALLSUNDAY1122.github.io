import Foundation

struct AW38PreflightResult {
    let checked: Int
    let largest: Int
    let safe: Bool
}

func preflight(_ directory: URL, maximumBytes: Int) -> AW38PreflightResult {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
        return AW38PreflightResult(checked: 0, largest: 0, safe: true)
    }
    do {
        let entries = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        var largest = 0
        for url in entries {
            let stem = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == "json", stem.count == 2, Int(stem, radix: 16) != nil else {
                return AW38PreflightResult(checked: entries.count, largest: largest, safe: false)
            }
            let v = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            let bytes = max(v.fileSize ?? 0, 0)
            largest = max(largest, bytes)
            guard v.isRegularFile == true, v.isSymbolicLink != true, bytes > 0, bytes <= maximumBytes else {
                return AW38PreflightResult(checked: entries.count, largest: largest, safe: false)
            }
        }
        return AW38PreflightResult(checked: entries.count, largest: largest, safe: true)
    } catch {
        return AW38PreflightResult(checked: 0, largest: 0, safe: false)
    }
}

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("AW38-" + UUID().uuidString, isDirectory: true)
defer { try? fm.removeItem(at: root) }
try fm.createDirectory(at: root, withIntermediateDirectories: true)
let small = root.appendingPathComponent("00.json")
try Data(repeating: 0x31, count: 64).write(to: small)
let normal = preflight(root, maximumBytes: 128).safe
let oversized = !preflight(root, maximumBytes: 32).safe
try fm.removeItem(at: small)
let target = root.appendingPathComponent("target")
try Data([1]).write(to: target)
try fm.createSymbolicLink(at: root.appendingPathComponent("00.json"), withDestinationURL: target)
let symlink = !preflight(root, maximumBytes: 128).safe
let pass = normal && oversized && symlink
print("L2_AW38_SELF_TEST_\(pass ? "PASS" : "FAIL") normal=\(normal) oversized=\(oversized) symlink=\(symlink)")
if !pass { exit(1) }
