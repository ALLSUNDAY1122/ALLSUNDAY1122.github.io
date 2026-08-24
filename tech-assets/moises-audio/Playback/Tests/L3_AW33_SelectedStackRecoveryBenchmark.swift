import Foundation

@main
struct L3AW33SelectedStackRecoveryBenchmark {
    static func main() throws {
        let rounds = 20
        let operationsPerRound = 100_000
        var samples: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            var local: UInt64 = 0
            for index in 0..<operationsPerRound {
                var state = Lane3SelectedTransportRecoveryState()
                let ticket = state.latch(
                    reason: .tempoBoundaryCancelFailure,
                    failedTempoSerial: UInt64(index + round + 1),
                    failedBoundarySerial: UInt64(index & 255)
                )
                let repeated = state.latch(
                    reason: .playbackBoundaryBackendPoisoned,
                    failedTempoSerial: UInt64(index + round + 99),
                    failedBoundarySerial: nil
                )
                precondition(ticket == repeated)
                precondition(state.requiresReconstruction)
                precondition(!ticket.parityPromotionAllowed)
                local &+= ticket.failedTempoSerial &+ UInt64(ticket.failedBoundarySerial ?? 0)
            }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
            samples.append(elapsed)
            checksum &+= local
        }

        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count - 1) * 0.95)]
        let maximum = sorted.last ?? 0
        print(
            String(
                format: "L3-AW33 benchmark PASS rounds=%d ops=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu",
                rounds,
                operationsPerRound,
                median,
                p95,
                maximum,
                checksum
            )
        )
    }
}
