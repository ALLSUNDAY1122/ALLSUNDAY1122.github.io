import Foundation

private struct Lane3AW45StressPCMSource: Lane3PCMChunkReadable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<channels {
                output[frame * channels + channel] = Float((absolute * 23 + Int64(channel) * 41) % 1_009) / 1_009
            }
        }
        return output
    }
}

@main
struct L3AW45SinglePassCodecIdentityStressMain {
    static func main() throws {
        let source = Lane3AW45StressPCMSource(channels: 2, sampleRate: 44_100, frameCount: 90_123)
        let baseline = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
            reference: source,
            observed: source,
            chunkFrames: 4_096
        )
        let chunkSizes = [1, 7, 64, 257, 1_024, 4_096, 16_384, 65_536]
        var checksum: UInt64 = 0

        for round in 0..<20 {
            for chunk in chunkSizes {
                var fnv: UInt64 = 0xcbf29ce484222325
                var observedFrames: UInt64 = 0
                let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                    source,
                    chunkFrames: chunk
                ) { _, count, samples in
                    observedFrames += UInt64(count)
                    for sample in samples {
                        fnv ^= UInt64(sample.bitPattern)
                        fnv = fnv &* 0x100000001b3
                    }
                }
                precondition(digest == baseline.referenceDigestSHA256)
                precondition(observedFrames == UInt64(source.frameCount))
                checksum ^= UInt64(digest.prefix(16), radix: 16) ?? 0
                checksum = checksum &+ fnv &+ UInt64(round) &+ UInt64(chunk)
            }
        }

        print(
            "L3-AW45 stress PASS traversals=\(20 * chunkSizes.count) " +
            "chunkVariants=\(chunkSizes.count) checksum=\(checksum)"
        )
    }
}