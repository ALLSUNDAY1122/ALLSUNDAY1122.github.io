import Foundation

private struct Lane3AW45BenchmarkPCMSource: Lane3PCMChunkReadable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64

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
struct L3AW45SinglePassCodecIdentityBenchmarkMain {
    static func main() throws {
        let source = Lane3AW45BenchmarkPCMSource(channels: 2, sampleRate: 100, frameCount: 360_000)
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw45-benchmark-clean",
            declaredCodecLabel: "aac-lc",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: 100,
            baselineFrameCount: 360_000,
            rightsCleared: true
        )
        let iterations = 5
        var oldElapsed: Double = 0
        var newElapsed: Double = 0
        var checksum: UInt64 = 0

        for _ in 0..<iterations {
            let oldStart = ContinuousClock.now
            let report = try Lane3RepresentativeCodecExecutionProbe.sweep(
                source: source,
                descriptor: descriptor,
                environment: .portableStructural,
                chunkFrames: 4_096
            )
            let identity = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
                reference: source,
                observed: source,
                chunkFrames: 4_096
            )
            oldElapsed += Double(oldStart.duration(to: .now).components.attoseconds) / 1e18
            checksum ^= report.rollingPCMChecksumFNV1A64 ?? 0
            checksum ^= UInt64(identity.referenceDigestSHA256.prefix(16), radix: 16) ?? 0

            var fnv: UInt64 = 0xcbf29ce484222325
            let newStart = ContinuousClock.now
            let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: 4_096
            ) { _, _, samples in
                for sample in samples {
                    fnv ^= UInt64(sample.bitPattern)
                    fnv = fnv &* 0x100000001b3
                }
            }
            newElapsed += Double(newStart.duration(to: .now).components.attoseconds) / 1e18
            precondition(digest == identity.referenceDigestSHA256)
            precondition(fnv == report.rollingPCMChecksumFNV1A64)
            checksum ^= fnv
        }

        let ratio = oldElapsed / max(newElapsed, 0.000_001)
        print(
            "L3-AW45 benchmark iterations=\(iterations) oldSeconds=\(oldElapsed) " +
            "singlePassSeconds=\(newElapsed) ratio=\(ratio) checksum=\(checksum)"
        )
    }
}