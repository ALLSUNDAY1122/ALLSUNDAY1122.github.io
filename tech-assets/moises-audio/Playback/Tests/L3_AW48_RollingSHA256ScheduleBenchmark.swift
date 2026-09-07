import Foundation

private struct Lane3AW48BenchmarkSource: Lane3PCMChunkReadable, Sendable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64 = 360_000

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            output[frame * 2] = Float((absolute * 17) % 997) / 997
            output[frame * 2 + 1] = Float((absolute * 17 + 31) % 997) / 997
        }
        return output
    }
}

@main
struct L3AW48RollingSHA256ScheduleBenchmarkMain {
    static func main() throws {
        let source = Lane3AW48BenchmarkSource()
        let iterations = 5
        var elapsed: Double = 0
        var checksum: UInt64 = 0

        for _ in 0..<iterations {
            let start = Date().timeIntervalSinceReferenceDate
            let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: 4_096
            ) { _, _, _ in }
            elapsed += Date().timeIntervalSinceReferenceDate - start
            checksum ^= UInt64(digest.prefix(16), radix: 16) ?? 0
        }

        let uint32Bytes = MemoryLayout<UInt32>.stride
        let legacyScheduleBytes = 64 * uint32Bytes
        let rollingScheduleBytes = 16 * uint32Bytes
        precondition(legacyScheduleBytes == 256)
        precondition(rollingScheduleBytes == 64)

        print(
            "L3-AW48 benchmark iterations=\(iterations) seconds=\(elapsed) " +
            "legacyScheduleBytes=\(legacyScheduleBytes) rollingScheduleBytes=\(rollingScheduleBytes) " +
            "storageReductionPercent=75 checksum=\(checksum)"
        )
    }
}
