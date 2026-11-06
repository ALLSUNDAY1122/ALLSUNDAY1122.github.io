import Foundation

@main
struct L3AW38TransportTokenTimingSelfTest {
    static func main() {
        var ledger = Lane3TransportTokenTimingLedger(capacity: 64)
        for generation in 1...100 {
            let reason: PlaybackTransportDiscontinuityReason = generation.isMultiple(of: 2) ? .seek : .loopChange
            ledger.recordIssued(
                token: PlaybackTransportRescheduleToken(generation: UInt64(generation), reason: reason),
                uptimeNanoseconds: UInt64(generation * 1_000)
            )
        }

        var snapshot = ledger.snapshot()
        precondition(snapshot.capacity == 64)
        precondition(snapshot.retainedCount == 64)
        precondition(snapshot.capacityDrops == 36)
        precondition(snapshot.completionMissesAfterEviction == 0)
        precondition(!snapshot.counterOverflowed)
        precondition(!snapshot.parityPromotionAllowed)
        precondition(ledger.sample(generation: 36) == nil)
        precondition(ledger.sample(generation: 37)?.issuedUptimeNanoseconds == 37_000)

        precondition(ledger.markBackendCompleted(
            generation: 100,
            uptimeNanoseconds: 100_500,
            appliedTarget: .seek(positionSeconds: 42.25)
        ))
        let seek = ledger.sample(generation: 100)!
        precondition(seek.reason == .seek)
        precondition(seek.backendCompletedUptimeNanoseconds == 100_500)
        precondition(seek.appliedTarget == .seek(positionSeconds: 42.25))

        precondition(ledger.markBackendCompleted(
            generation: 99,
            uptimeNanoseconds: 99_500,
            appliedTarget: .loopDisabled
        ))
        precondition(ledger.sample(generation: 99)?.appliedTarget == .loopDisabled)

        precondition(!ledger.markBackendCompleted(
            generation: 1,
            uptimeNanoseconds: 200_000,
            appliedTarget: .seek(positionSeconds: 1)
        ))
        snapshot = ledger.snapshot()
        precondition(snapshot.completionMissesAfterEviction == 1)
        precondition(!Lane3TransportAppliedTarget.seek(positionSeconds: -.infinity).isFiniteAndValid)
        precondition(!Lane3TransportAppliedTarget.loop(startSeconds: 4, endSeconds: 4).isFiniteAndValid)
        precondition(Lane3TransportAppliedTarget.loopDisabled.isFiniteAndValid)

        print("L3-AW38 token timing self-test PASS retained=\(snapshot.retainedCount) drops=\(snapshot.capacityDrops) completionMisses=\(snapshot.completionMissesAfterEviction)")
    }
}
