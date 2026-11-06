import Foundation

private struct Lane3AW47BenchmarkPCMSource: Lane3PCMChunkReadable, Sendable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64 = 360_000

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<channels {
                output[frame * channels + channel] = Float((absolute * 17 + Int64(channel) * 31) % 997) / 997
            }
        }
        return output
    }
}

@main
struct L3AW47StreamingPCMIdentityBenchmarkMain {
    static func main() throws {
        let source = Lane3AW47BenchmarkPCMSource()
        let chunkFrames = 4_096
        let iterations = 10
        let oldConversionBytesPerFullChunk = chunkFrames * source.channels * MemoryLayout<Float>.stride
        let newConversionBytesPerChunk = 0
        var elapsed = 0.0
        var digestXOR: UInt64 = 0
        var totalVisitedFrames: Int64 = 0

        for _ in 0..<iterations {
            var visitedFrames: Int64 = 0
            let started = Date().timeIntervalSinceReferenceDate
            let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: chunkFrames
            ) { _, count, _ in
                visitedFrames += Int64(count)
            }
            elapsed += Date().timeIntervalSinceReferenceDate - started
            precondition(visitedFrames == source.frameCount)
            totalVisitedFrames += visitedFrames
            digestXOR ^= UInt64(digest.prefix(16), radix: 16) ?? 0
        }

        let audioSeconds = Double(totalVisitedFrames) / source.sampleRate
        let realtimeMultiple = audioSeconds / max(elapsed, 0.000_001)
        print(
            "L3-AW47 benchmark iterations=\(iterations) elapsed=\(elapsed) " +
            "audioSeconds=\(audioSeconds) realtimeMultiple=\(realtimeMultiple) " +
            "legacyConversionBytesPerFullChunk=\(oldConversionBytesPerFullChunk) " +
            "streamingConversionBytesPerChunk=\(newConversionBytesPerChunk) digestXOR=\(digestXOR)"
        )
    }
}
