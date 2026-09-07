import Foundation

@main
struct L3AW27BoundedPCMSourcePolicyBenchmark {
    static func main() throws {
        let rounds = 20
        let operations = 100_000
        let totalFrames: Int64 = 86_400_000
        let policy = try Lane3PCMChunkReadPolicy(maximumFramesPerRead: 65_536)
        var durations: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            var state = UInt64(0x9e3779b97f4a7c15) ^ UInt64(round + 1)
            var audit = Lane3PCMChunkReadAudit()
            let start = ContinuousClock.now
            for index in 0..<operations {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let count = Int((state >> 32) % 40_962) + 1
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let maxStart = totalFrames - Int64(count)
                let frame = Int64(state % UInt64(maxStart + 1))
                let samples = try policy.expectedInterleavedSampleCount(
                    startFrame: frame,
                    frameCount: count,
                    totalFrames: totalFrames,
                    channels: 2
                )
                audit.recordSuccessfulRead(startFrame: frame, frameCount: count)
                checksum &+= UInt64(samples &+ index & 0xff)
            }
            let elapsed = ContinuousClock.now - start
            let milliseconds = Double(elapsed.components.seconds) * 1_000
                + Double(elapsed.components.attoseconds) / 1e15
            durations.append(milliseconds)
            let snapshot = audit.snapshot()
            precondition(snapshot.successfulReadCalls == UInt64(operations))
            precondition(snapshot.maximumRequestedFrames <= 40_962)
            precondition(!snapshot.counterOverflowed)
        }

        let sorted = durations.sorted()
        let median = sorted[sorted.count / 2]
        let p95Index = min(
            sorted.count - 1,
            Int((0.95 * Double(sorted.count - 1)).rounded(.up))
        )
        print(String(
            format: "L3-AW27 policy benchmark PASS rounds=%d ops=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu",
            rounds,
            operations,
            median,
            sorted[p95Index],
            sorted.last!,
            checksum
        ))
    }
}
