import Foundation

@main
struct L3AW49FileSourceIdentityFenceStressMain {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("l3-aw49-stress-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("fixture.bin")
        let payloadSize = 4096
        try Data(repeating: 0x11, count: payloadSize).write(to: fileURL)

        var replacementRejections = 0
        var stableChecks = 0
        let rounds = 100

        for round in 0..<rounds {
            let baseline = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
            for _ in 0..<10 {
                try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)
                stableChecks += 1
            }

            let replacementByte = UInt8(truncatingIfNeeded: round &+ 0x40)
            try Data(repeating: replacementByte, count: payloadSize).write(to: fileURL, options: .atomic)
            do {
                try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)
                preconditionFailure("atomic replacement escaped at round \(round)")
            } catch Lane3FileSourceIdentityFenceError.changed {
                replacementRejections += 1
            }
        }

        precondition(stableChecks == 1_000)
        precondition(replacementRejections == rounds)
        print("L3-AW49 file source identity stress PASS stableChecks=\(stableChecks) replacementRejections=\(replacementRejections)/\(rounds)")
    }
}
