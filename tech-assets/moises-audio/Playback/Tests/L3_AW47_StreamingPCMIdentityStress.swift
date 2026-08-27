import Foundation

private struct Lane3AW47StressPCMSource: Lane3PCMChunkReadable, Sendable {
    let channels = 2
    let sampleRate = 100.0
    let frameCount: Int64 = 4_096

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
struct L3AW47StreamingPCMIdentityStressMain {
    static func main() throws {
        let source = Lane3AW47StressPCMSource()
        let expectedDigest = "ed3bf31b3d89b21f74063fa60c2b0e77132926abee41a58424469bd943f45353"
        let expectedFNV: UInt64 = 14_500_112_217_335_945_685
        let chunkSizes = [1, 2, 3, 7, 16, 63, 64, 65, 257, 4_096]
        let repetitions = 20
        var verified = 0

        for _ in 0..<repetitions {
            for chunkFrames in chunkSizes {
                var fnv: UInt64 = 0xcbf29ce484222325
                var framesVisited: Int64 = 0
                let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                    source,
                    chunkFrames: chunkFrames
                ) { _, count, samples in
                    framesVisited += Int64(count)
                    for sample in samples {
                        fnv ^= UInt64(sample.bitPattern)
                        fnv = fnv &* 0x100000001b3
                    }
                }
                precondition(digest == expectedDigest, "digest changed at chunkFrames=\(chunkFrames)")
                precondition(fnv == expectedFNV, "FNV changed at chunkFrames=\(chunkFrames)")
                precondition(framesVisited == source.frameCount)
                verified += 1
            }
        }

        precondition(verified == repetitions * chunkSizes.count)
        print("L3-AW47 streaming stress PASS cells=\(verified) digest=\(expectedDigest.prefix(16))")
    }
}
