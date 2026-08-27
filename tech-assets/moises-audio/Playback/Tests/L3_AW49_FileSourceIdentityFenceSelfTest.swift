import Foundation

@main
struct L3AW49FileSourceIdentityFenceSelfTestMain {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("l3-aw49-selftest-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("fixture.bin")
        try Data("AAAA".utf8).write(to: fileURL)

        let baseline = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)

        // Atomic replace with the same byte length. Public PCM metadata could remain unchanged, but the
        // backing filesystem object must not be accepted as the same evidence source generation.
        try Data("BBBB".utf8).write(to: fileURL, options: .atomic)
        precondition((try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.uint64Value == 4)
        do {
            try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)
            preconditionFailure("same-size atomic replacement escaped the source identity fence")
        } catch Lane3FileSourceIdentityFenceError.changed {
            // expected
        }

        let replaced = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        precondition(replaced.fileSize == baseline.fileSize)
        precondition(replaced.systemNumber != baseline.systemNumber
            || replaced.systemFileNumber != baseline.systemFileNumber
            || replaced.creationDateBitPattern != baseline.creationDateBitPattern
            || replaced.modificationDateBitPattern != baseline.modificationDateBitPattern
            || replaced.resourceIdentifierHash != baseline.resourceIdentifierHash
            || replaced.generationIdentifierHash != baseline.generationIdentifierHash)

        let directoryURL = root.appendingPathComponent("directory", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        do {
            _ = try Lane3FileSourceIdentityFence.capture(fileURL: directoryURL)
            preconditionFailure("directory was accepted as a regular evidence file")
        } catch Lane3FileSourceIdentityFenceError.notRegularFile {
            // expected
        }

        let missingURL = root.appendingPathComponent("missing.bin")
        do {
            _ = try Lane3FileSourceIdentityFence.capture(fileURL: missingURL)
            preconditionFailure("missing file was accepted")
        } catch Lane3FileSourceIdentityFenceError.unavailable {
            // expected
        }

        precondition(baseline.fileSize == 4)
        print("L3-AW49 file source identity self-test PASS sameSizeAtomicReplaceRejected=true pathPersisted=false")
    }
}
