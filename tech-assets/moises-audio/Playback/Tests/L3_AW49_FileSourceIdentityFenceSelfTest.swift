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
        try Data(repeating: 0x11, count: 4_096).write(to: fileURL)

        let baseline = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)

        // Same-inode, same-size in-place rewrite. Normal filesystem mutation advances mtime even when
        // channels/sample-rate/frame-count style metadata outside this layer could remain identical.
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: Data(repeating: 0x22, count: 4_096))
        try handle.synchronize()
        try handle.close()
        let inPlace = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        precondition(inPlace.systemNumber == baseline.systemNumber)
        precondition(inPlace.systemFileNumber == baseline.systemFileNumber)
        precondition(inPlace.fileSize == baseline.fileSize)
        do {
            try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)
            preconditionFailure("same-inode in-place rewrite escaped the source identity fence")
        } catch Lane3FileSourceIdentityFenceError.changed {
            // expected
        }

        // Atomic replace with the same byte length. Public PCM metadata could remain unchanged, but the
        // backing filesystem object must not be accepted as the same evidence source generation.
        let beforeAtomicReplace = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        try Data(repeating: 0x33, count: 4_096).write(to: fileURL, options: .atomic)
        precondition((try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.uint64Value == 4_096)
        do {
            try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: beforeAtomicReplace)
            preconditionFailure("same-size atomic replacement escaped the source identity fence")
        } catch Lane3FileSourceIdentityFenceError.changed {
            // expected
        }

        let replaced = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        precondition(replaced.fileSize == beforeAtomicReplace.fileSize)
        precondition(replaced.systemNumber != beforeAtomicReplace.systemNumber
            || replaced.systemFileNumber != beforeAtomicReplace.systemFileNumber
            || replaced.creationDateBitPattern != beforeAtomicReplace.creationDateBitPattern
            || replaced.modificationDateBitPattern != beforeAtomicReplace.modificationDateBitPattern
            || replaced.resourceIdentifierHash != beforeAtomicReplace.resourceIdentifierHash
            || replaced.generationIdentifierHash != beforeAtomicReplace.generationIdentifierHash)

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

        precondition(baseline.fileSize == 4_096)
        print("L3-AW49 file source identity self-test PASS inPlaceRejected=true atomicReplaceRejected=true pathPersisted=false")
    }
}
