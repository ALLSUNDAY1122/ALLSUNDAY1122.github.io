import Foundation

@main
struct AW11Benchmark {
    static func main() throws {
        let rounds = 20
        let operationsPerRound = 100_000
        var durations: [Double] = []
        durations.reserveCapacity(rounds)
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let start = ContinuousClock.now
            let report = try Lane3CombinedRecoveryStressRunner.run(
                seed: 0xA1100000 + UInt64(round),
                operations: operationsPerRound,
                stemCount: 6
            )
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            let milliseconds = Double(components.seconds) * 1_000
                + Double(components.attoseconds) / 1e15
            durations.append(milliseconds)
            checksum &+= report.finalState.playbackGeneration
            checksum &+= report.finalState.clickGeneration
            checksum &+= UInt64(report.counters.staleCompletionRejected)
            checksum &+= UInt64(report.counters.staleReplacementRejected)
        }

        let sorted = durations.sorted()
        let median = (sorted[9] + sorted[10]) / 2
        let p95 = sorted[Int(ceil(0.95 * Double(rounds))) - 1]
        let maximum = sorted.last!
        print(String(format: "L3-AW11 benchmark rounds=%d operations=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu", rounds, operationsPerRound, median, p95, maximum, checksum))
    }
}
