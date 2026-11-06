import Foundation

@main
struct L3AW43RepresentativeCodecExecutionBenchmark {
    static func main() throws {
        let runs = 20
        let frames: Int64 = 100_000
        let sampleRate = Double(frames) / 1_800.0
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-benchmark-clean",
            declaredCodecLabel: "benchmark-pcm",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: sampleRate,
            baselineFrameCount: frames,
            rightsCleared: true
        )
        let source = Lane3ClosurePCMChunkSource(channels: 2, sampleRate: sampleRate, frameCount: frames) { start, count in
            let seed = Float((start / 1024) % 127) / 127.0
            return [Float](repeating: seed, count: count * 2)
        }
        var samples: [UInt64] = []
        var checksum: UInt64 = 0
        for _ in 0..<runs {
            let start = DispatchTime.now().uptimeNanoseconds
            let report = try Lane3RepresentativeCodecExecutionProbe.sweep(
                source: source,
                descriptor: descriptor,
                environment: .portableStructural,
                chunkFrames: 4096
            )
            let end = DispatchTime.now().uptimeNanoseconds
            precondition(report.cleanDecodeContractSatisfied)
            samples.append(end - start)
            checksum = checksum &+ (report.rollingPCMChecksumFNV1A64 ?? 0)
        }
        samples.sort()
        let median = samples[samples.count / 2]
        let p95 = samples[min(samples.count - 1, Int(Double(samples.count - 1) * 0.95))]
        print("L3-AW43 benchmark PASS runs=\(runs) framesPerRun=\(frames) medianNs=\(median) p95Ns=\(p95) maxNs=\(samples.last!) checksum=\(checksum)")
    }
}
