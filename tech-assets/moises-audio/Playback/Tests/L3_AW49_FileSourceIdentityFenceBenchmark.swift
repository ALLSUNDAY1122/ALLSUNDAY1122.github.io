import Foundation

@main
struct L3AW49FileSourceIdentityFenceBenchmarkMain {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("l3-aw49-benchmark-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("fixture.bin")
        try Data(repeating: 0x5a, count: 1_048_576).write(to: fileURL)
        let baseline = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)

        let iterations = 10_000
        let started = Date().timeIntervalSinceReferenceDate
        for _ in 0..<iterations {
            try Lane3FileSourceIdentityFence.requireUnchanged(fileURL: fileURL, expected: baseline)
        }
        let elapsed = Date().timeIntervalSinceReferenceDate - started
        let averageMicroseconds = elapsed * 1_000_000 / Double(iterations)

        print("L3-AW49 file source identity benchmark iterations=\(iterations) elapsedSeconds=\(elapsed) averageMicroseconds=\(averageMicroseconds)")
    }
}
