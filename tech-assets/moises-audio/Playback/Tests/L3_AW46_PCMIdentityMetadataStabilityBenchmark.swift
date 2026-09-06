import Foundation

private final class Lane3AW46BenchmarkStableSource: Lane3PCMChunkReadable, @unchecked Sendable {
    private let baseChannels: Int
    private let baseSampleRate: Double
    private let baseFrameCount: Int64
    private(set) var channelGetterCalls = 0
    private(set) var sampleRateGetterCalls = 0
    private(set) var frameCountGetterCalls = 0
    private(set) var readCalls = 0

    init(channels: Int, sampleRate: Double, frameCount: Int64) {
        self.baseChannels = channels
        self.baseSampleRate = sampleRate
        self.baseFrameCount = frameCount
    }

    var channels: Int {
        channelGetterCalls += 1
        return baseChannels
    }

    var sampleRate: Double {
        sampleRateGetterCalls += 1
        return baseSampleRate
    }

    var frameCount: Int64 {
        frameCountGetterCalls += 1
        return baseFrameCount
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        readCalls += 1
        var output = [Float](repeating: 0, count: frameCount * baseChannels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<baseChannels {
                output[frame * baseChannels + channel] = Float((absolute * 17 + Int64(channel) * 31) % 997) / 997
            }
        }
        return output
    }
}

@main
struct L3AW46PCMIdentityMetadataStabilityBenchmarkMain {
    static func main() throws {
        let iterations = 10
        let chunkFrames = 4_096
        var totalSeconds = 0.0
        var totalReads = 0
        var totalMetadataGetterCalls = 0
        var digestPrefixAccumulator: UInt64 = 0

        for _ in 0..<iterations {
            let source = Lane3AW46BenchmarkStableSource(
                channels: 2,
                sampleRate: 100,
                frameCount: 360_000
            )
            let start = ContinuousClock.now
            let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: chunkFrames
            ) { _, _, _ in }
            totalSeconds += Double(start.duration(to: .now).components.attoseconds) / 1e18
            totalReads += source.readCalls
            totalMetadataGetterCalls += source.channelGetterCalls
                + source.sampleRateGetterCalls
                + source.frameCountGetterCalls
            digestPrefixAccumulator ^= UInt64(digest.prefix(16), radix: 16) ?? 0
        }

        let expectedReadsPerIteration = Int((360_000 + Int64(chunkFrames) - 1) / Int64(chunkFrames))
        precondition(totalReads == expectedReadsPerIteration * iterations)
        print(
            "L3-AW46 benchmark iterations=\(iterations) seconds=\(totalSeconds) " +
            "readCalls=\(totalReads) metadataGetterCalls=\(totalMetadataGetterCalls) " +
            "digestPrefixAccumulator=\(digestPrefixAccumulator)"
        )
    }
}
