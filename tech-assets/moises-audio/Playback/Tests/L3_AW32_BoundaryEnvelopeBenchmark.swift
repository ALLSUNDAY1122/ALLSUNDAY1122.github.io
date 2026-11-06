import Foundation
import Dispatch

@main
struct L3AW32BoundaryEnvelopeBenchmark {
    static func main() throws {
        let rounds = 20
        let operations = 250_000
        let policy = PlaybackBoundaryEnvelopePolicy()
        var durations: [Double] = []
        var checksum = 0.0
        durations.reserveCapacity(rounds)

        for round in 0..<rounds {
            let started = DispatchTime.now().uptimeNanoseconds
            var local = 0.0
            for index in 0..<operations {
                let rate = index.isMultiple(of: 2) ? 48_000.0 : 44_100.0
                let plan = try PlaybackBoundaryEnvelopePlanner.makePlan(
                    sampleRate: rate,
                    startLeadSeconds: 0.075,
                    policy: policy
                )
                let boundaryDelay = 0.004 + Double((index + round) % 20_000) / 1000.0
                let loop = try PlaybackBoundaryEnvelopePlanner.makeLoopPlan(
                    boundaryDelaySeconds: boundaryDelay,
                    sampleRate: rate,
                    policy: policy
                )
                local += Double(plan.fadeOutFrames + plan.fadeInFrames)
                local += loop.delayBeforeFadeOutSeconds
                if loop.overlapRisk { local += 1 }
            }
            let ended = DispatchTime.now().uptimeNanoseconds
            durations.append(Double(ended - started) / 1_000_000)
            checksum += local
        }

        let sorted = durations.sorted()
        let median = sorted[sorted.count / 2]
        let p95 = sorted[Int((Double(sorted.count - 1) * 0.95).rounded(.up))]
        let maximum = sorted.last ?? 0
        print(String(format: "L3-AW32 benchmark PASS rounds=%d ops=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%.3f", rounds, operations, median, p95, maximum, checksum))
    }
}
