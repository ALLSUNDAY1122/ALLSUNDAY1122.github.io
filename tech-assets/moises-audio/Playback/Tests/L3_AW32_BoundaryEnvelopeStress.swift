import Foundation

@main
struct L3AW32BoundaryEnvelopeStress {
    static func main() throws {
        let rates = [44_100.0, 48_000.0, 96_000.0, 192_000.0]
        let tempos = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let policy = PlaybackBoundaryEnvelopePolicy()
        var safe = 0
        var overlap = 0
        var late = 0
        var checksum = 0.0

        for index in 0..<1_000_000 {
            let rate = rates[index % rates.count]
            let tempo = tempos[index % tempos.count]
            let projectDuration = 0.001 + Double((index * 37) % 20_000) / 1000.0
            let hostDuration = projectDuration / tempo
            let plan = try PlaybackBoundaryEnvelopePlanner.makePlan(
                sampleRate: rate,
                startLeadSeconds: 0.075,
                policy: policy
            )
            let loop = try PlaybackBoundaryEnvelopePlanner.makeLoopPlan(
                boundaryDelaySeconds: hostDuration,
                sampleRate: rate,
                policy: policy
            )
            if loop.lateArming { late += 1 }
            if loop.overlapRisk { overlap += 1 } else { safe += 1 }
            checksum += Double(plan.fadeOutFrames + plan.fadeInFrames) * 0.000001
            checksum += loop.delayBeforeFadeOutSeconds * 0.00001
        }

        precondition(safe > 0)
        precondition(overlap > 0)
        precondition(late > 0)
        precondition(safe + overlap == 1_000_000)
        print(String(format: "L3-AW32 stress PASS cycles=1000000 safe=%d overlap=%d late=%d checksum=%.6f", safe, overlap, late, checksum))
    }
}
