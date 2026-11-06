import Foundation

@main
struct L3AW38TransportTokenTimingStress {
    static func main() {
        let iterations = 1_000_000
        var ledger = Lane3TransportTokenTimingLedger(capacity: 4_096)
        for index in 1...iterations {
            let generation = UInt64(index)
            let reason: PlaybackTransportDiscontinuityReason = index.isMultiple(of: 2) ? .seek : .loopChange
            ledger.recordIssued(
                token: PlaybackTransportRescheduleToken(generation: generation, reason: reason),
                uptimeNanoseconds: generation &* 10
            )
            let target: Lane3TransportAppliedTarget = index.isMultiple(of: 2)
                ? .seek(positionSeconds: Double(index % 600))
                : .loop(startSeconds: 1, endSeconds: 5)
            precondition(ledger.markBackendCompleted(
                generation: generation,
                uptimeNanoseconds: generation &* 10 &+ 5,
                appliedTarget: target
            ))
        }

        var snapshot = ledger.snapshot()
        precondition(snapshot.retainedCount == 4_096)
        precondition(snapshot.capacityDrops == UInt64(iterations - 4_096))
        precondition(snapshot.completionMissesAfterEviction == 0)
        precondition(!snapshot.counterOverflowed)
        precondition(ledger.sample(generation: UInt64(iterations - 4_095)) != nil)
        precondition(ledger.sample(generation: UInt64(iterations - 4_096)) == nil)

        precondition(!ledger.markBackendCompleted(
            generation: 1,
            uptimeNanoseconds: UInt64(iterations) * 10 + 10,
            appliedTarget: .loopDisabled
        ))
        snapshot = ledger.snapshot()
        precondition(snapshot.completionMissesAfterEviction == 1)

        print("L3-AW38 token timing stress PASS iterations=\(iterations) retained=\(snapshot.retainedCount) drops=\(snapshot.capacityDrops)")
    }
}
