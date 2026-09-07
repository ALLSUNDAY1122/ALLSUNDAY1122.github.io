import Foundation

@main
struct L3AW36CancellationAdmissionFenceBenchmark {
    static func main() {
        let rounds = 20
        let ops = 1_000_000
        var samples: [Double] = []
        var checksum: UInt64 = 0
        samples.reserveCapacity(rounds)

        for round in 0..<rounds {
            var fence = Lane3UnifiedCancellationAdmissionFence()
            let start = ContinuousClock.now
            for i in 0..<ops {
                let ticket = UInt64(i + 1)
                fence.beginAdmission(ticket: ticket)
                if (i + round) % 4 == 0 {
                    _ = fence.markCancellationIfAdmitting(ticket: ticket)
                }
                let cancelled = fence.consumeAdmission(ticket: ticket)
                if !cancelled && (i + round) % 3 == 0 {
                    fence.noteLateRetiredCancellationIgnored()
                }
            }
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            let ms = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
            samples.append(ms)
            let s = fence.snapshot()
            precondition(s.admittingTicketCount == 0)
            precondition(s.cancelledBeforeEnqueueTicketCount == 0)
            precondition(s.invariantHolds)
            checksum &+= s.lateRetiredCancellationIgnored &+ UInt64(round)
        }

        samples.sort()
        func percentile(_ p: Double) -> Double {
            let rank = max(0, min(samples.count - 1, Int(ceil(p * Double(samples.count))) - 1))
            return samples[rank]
        }
        let median = (samples[9] + samples[10]) / 2
        print(String(format: "L3-AW36 benchmark PASS rounds=%d ops=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu", rounds, ops, median, percentile(0.95), samples.last!, checksum))
    }
}
