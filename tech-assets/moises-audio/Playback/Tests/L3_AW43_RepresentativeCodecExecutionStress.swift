import Foundation

@main
struct L3AW43RepresentativeCodecExecutionStress {
    static func main() throws {
        let frames: Int64 = 1_000_000
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-stress-clean",
            declaredCodecLabel: "stress-pcm",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: Double(frames) / 1_800.0,
            baselineFrameCount: frames,
            rightsCleared: true
        )
        let source = Lane3ClosurePCMChunkSource(
            channels: 2,
            sampleRate: descriptor.expectedSampleRate,
            frameCount: frames
        ) { start, count in
            let seed = Float(start % 997) / 997.0
            return [Float](repeating: seed, count: count * 2)
        }
        let start = ContinuousClock.now
        let report = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: source,
            descriptor: descriptor,
            environment: .portableStructural,
            chunkFrames: 4096
        )
        let elapsed = ContinuousClock.now - start
        precondition(report.cleanDecodeContractSatisfied)
        precondition(report.framesRead == 1_000_000)
        precondition(report.readCalls == 245)
        precondition(report.nonFiniteSampleCount == 0)
        precondition(report.rollingPCMChecksumFNV1A64 != nil)
        print("L3-AW43 1M-frame stress PASS reads=\(report.readCalls) frames=\(report.framesRead) elapsed=\(elapsed) checksum=\(report.rollingPCMChecksumFNV1A64!)")
    }
}
