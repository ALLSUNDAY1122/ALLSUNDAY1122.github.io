import Foundation

@main
struct L3AW32BoundaryMutedTempoPolicySelfTest {
    static func main() throws {
        for from in [0.25, 0.5, 1.0, 2.0, 4.0] {
            for to in [0.25, 0.5, 1.0, 2.0, 4.0] {
                let plan = try PracticeDSPTempoTransitionPlanner.makePlan(
                    fromRatio: from,
                    toRatio: to,
                    sampleRate: 48_000,
                    policy: .boundaryMutedImmediate
                )
                precondition(plan.mode == .immediate)
                precondition(plan.rampDurationFrames == 0)
                precondition(plan.recommendedBarrierNanoseconds == 0)
            }
        }

        let live = try PracticeDSPTempoTransitionPlanner.makePlan(
            fromRatio: 0.5,
            toRatio: 2.0,
            sampleRate: 48_000,
            policy: .provisionalAppleInteractive
        )
        precondition(live.mode == .scheduledRamp)
        precondition(live.recommendedBarrierNanoseconds > 0)

        print(
            "L3-AW32 muted tempo PASS selectedBarrier=0 liveBarrier=\(live.recommendedBarrierNanoseconds)"
        )
    }
}
