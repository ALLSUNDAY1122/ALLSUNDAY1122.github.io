import Foundation

private final class AW26GeneratedIdentitySource: Lane3PCMChunkReadable, @unchecked Sendable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64
    private(set) var maximumRequestedFrames = 0

    init(frameCount: Int64) { self.frameCount = frameCount }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        maximumRequestedFrames = max(maximumRequestedFrames, frameCount)
        var output: [Float] = []
        output.reserveCapacity(frameCount * 2)
        for local in 0..<frameCount {
            let frame = startFrame + Int64(local)
            output.append(Float(frame & 1_023) / 2_048)
            output.append(Float((frame * 3) & 1_023) / 2_048)
        }
        return output
    }
}

@main
struct L3AW26LongTrackEvidenceBenchmark {
    static func main() throws {
        let rounds = 10
        let framesPerSource: Int64 = 250_000
        var durations: [Double] = []
        var checksum = 0
        for _ in 0..<rounds {
            let reference = AW26GeneratedIdentitySource(frameCount: framesPerSource)
            let observed = AW26GeneratedIdentitySource(frameCount: framesPerSource)
            let start = DispatchTime.now().uptimeNanoseconds
            let receipt = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
                reference: reference,
                observed: observed,
                chunkFrames: 16_384
            )
            let end = DispatchTime.now().uptimeNanoseconds
            durations.append(Double(end - start) / 1_000_000)
            checksum &+= receipt.referenceDigestSHA256.utf8.reduce(0) { $0 + Int($1) }
            precondition(reference.maximumRequestedFrames <= 16_384)
            precondition(observed.maximumRequestedFrames <= 16_384)
        }
        let sorted = durations.sorted()
        let median = sorted[rounds / 2]
        let p95 = sorted[Int((Double(rounds) * 0.95).rounded(.up)) - 1]
        let maximum = sorted.last!
        let profile = try Lane3LongTrackEvidenceResourcePlanner.profile(channels: 2)
        print(String(
            format: "L3-AW26 benchmark PASS rounds=%d framesPerSource=%lld median=%.3fms p95=%.3fms max=%.3fms maxSingleReadFrames=%d majorBufferBound=%d checksum=%d",
            rounds,
            framesPerSource,
            median,
            p95,
            maximum,
            profile.maximumSingleReadFrames,
            profile.estimatedMajorAnalysisBufferBytesUpperBound,
            checksum
        ))
    }
}
