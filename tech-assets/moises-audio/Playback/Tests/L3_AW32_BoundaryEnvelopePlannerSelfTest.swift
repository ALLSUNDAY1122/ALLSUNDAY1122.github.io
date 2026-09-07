import Foundation

@main
struct L3AW32BoundaryEnvelopePlannerSelfTest {
    static func main() throws {
        let policy = PlaybackBoundaryEnvelopePolicy(
            fadeOutSeconds: 0.008,
            fadeInSeconds: 0.008,
            maximumPendingLoopEnvelopes: 8
        )
        let plan = try PlaybackBoundaryEnvelopePlanner.makePlan(
            sampleRate: 48_000,
            startLeadSeconds: 0.075,
            policy: policy
        )
        precondition(plan.fadeOutFrames == 384)
        precondition(plan.fadeInFrames == 384)
        precondition(abs(plan.minimumRestartMutedLeadSeconds - 0.075) < 1e-12)
        precondition(!plan.parityPromotionAllowed)

        let normalLoop = try PlaybackBoundaryEnvelopePlanner.makeLoopPlan(
            boundaryDelaySeconds: 1.0,
            sampleRate: 48_000,
            policy: policy
        )
        precondition(abs(normalLoop.delayBeforeFadeOutSeconds - 0.992) < 1e-12)
        precondition(!normalLoop.lateArming)
        precondition(!normalLoop.overlapRisk)

        let lateLoop = try PlaybackBoundaryEnvelopePlanner.makeLoopPlan(
            boundaryDelaySeconds: 0.004,
            sampleRate: 48_000,
            policy: policy
        )
        precondition(lateLoop.lateArming)
        precondition(lateLoop.overlapRisk)
        precondition(lateLoop.delayBeforeFadeOutSeconds == 0)

        let shortLoop = try PlaybackBoundaryEnvelopePlanner.makeLoopPlan(
            boundaryDelaySeconds: 0.012,
            sampleRate: 48_000,
            policy: policy
        )
        precondition(!shortLoop.lateArming)
        precondition(shortLoop.overlapRisk)

        for rate in [44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let p = try PlaybackBoundaryEnvelopePlanner.makePlan(
                sampleRate: rate,
                startLeadSeconds: 0.075,
                policy: policy
            )
            precondition(p.fadeOutFrames >= 1 && p.fadeInFrames >= 1)
        }

        for invalidRate in [0.0, -1.0, Double.nan, Double.infinity] {
            do {
                _ = try PlaybackBoundaryEnvelopePlanner.makePlan(
                    sampleRate: invalidRate,
                    startLeadSeconds: 0.075,
                    policy: policy
                )
                preconditionFailure("invalid sample rate accepted")
            } catch PlaybackBoundaryEnvelopeError.invalidSampleRate { }
        }

        do {
            _ = try PlaybackBoundaryEnvelopePlanner.makePlan(
                sampleRate: 48_000,
                startLeadSeconds: -0.001,
                policy: policy
            )
            preconditionFailure("invalid lead accepted")
        } catch PlaybackBoundaryEnvelopeError.invalidStartLead { }

        do {
            _ = try PlaybackBoundaryEnvelopePlanner.makePlan(
                sampleRate: 48_000,
                startLeadSeconds: 0.075,
                policy: PlaybackBoundaryEnvelopePolicy(fadeOutSeconds: 0, fadeInSeconds: 0.008)
            )
            preconditionFailure("zero fade out accepted")
        } catch PlaybackBoundaryEnvelopeError.invalidFadeOutDuration { }

        let runtime = PlaybackBoundaryEnvelopeRuntimeSnapshot(
            fadeOutScheduled: 10,
            restartFadeInArmed: 10,
            restartFadeInApplied: 9,
            loopEnvelopeArmed: 0,
            loopFadeOutApplied: 0,
            loopFadeInApplied: 0,
            staleOrCancelledEnvelopeTasksRejected: 1,
            loopEnvelopeCapacityDrops: 0,
            loopEnvelopeUnsafeDurationDrops: 2,
            counterOverflowed: false,
            pendingLoopEnvelopeTasks: 0,
            restartFadeInPending: false
        )
        precondition(runtime.schemaVersion == 1)
        precondition(runtime.evidenceScope == "LANE3_AW32_BOUNDARY_ENVELOPE_RUNTIME_NON_PARITY")
        precondition(!runtime.parityPromotionAllowed)

        print("L3-AW32 planner PASS frames=\(plan.fadeOutFrames) loopDelay=\(normalLoop.delayBeforeFadeOutSeconds) overlapGuard=PASS")
    }
}
