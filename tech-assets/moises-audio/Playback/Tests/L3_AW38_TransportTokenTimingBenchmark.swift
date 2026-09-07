import Foundation

@main
struct L3AW38TransportTokenTimingBenchmark {
    static func main() {
        let rounds = 20
        let iterations = 1_000_000
        var elapsed: [Double] = []
        elapsed.reserveCapacity(rounds)
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            var ledger = Lane3TransportTokenTimingLedger(capacity: 4_096)
            let started = ContinuousClock.now
            for index in 1...iterations {
                let generation = UInt64(index)
                ledger.recordIssued(
                    token: PlaybackTransportRescheduleToken(generation: generation, reason: .seek),
                    uptimeNanoseconds: generation
                )
                _ = ledger.markBackendCompleted(
                    generation: generation,
                    uptimeNanoseconds: generation &+ 1,
                    appliedTarget: .seek(positionSeconds: Double(index % 600))
                )
            }
            let duration = started.duration(to: .now)
            let milliseconds = Double(duration.components.seconds) * 1_000
                + Double(duration.components.attoseconds) / 1_000_000_000_000_000
            elapsed.append(milliseconds)
            let snapshot = ledger.snapshot()
            checksum &+= UInt64(snapshot.retainedCount)
            checksum &+= snapshot.capacityDrops
            checksum &+= UInt64(round)
        }

        let sorted = elapsed.sorted()
        let median = sorted[rounds / 2]
        let p95 = sorted[Int(ceil(Double(rounds) * 0.95)) - 1]
        let maximum = sorted.last!
        print(String(format: "L3-AW38 timing benchmark PASS rounds=%d iterations=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu", rounds, iterations, median, p95, maximum, checksum))
    }
}
