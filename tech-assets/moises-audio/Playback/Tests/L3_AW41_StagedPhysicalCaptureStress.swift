import Foundation

private struct L3AW41StressCorrelator: Lane3LeaseStampedContinuityCorrelating {
    func correlateLeaseStamped(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3LeaseStampedContinuityCorrelation {
        .nonExecuted(slotGeneration: stamped.slotGeneration, outcome: stamped.outcome)
    }
}

private func l3aw41StressNonExecuted(
    ticket: UInt64
) -> Lane3SelectedTransportGenerationStampedOutcome {
    .init(
        slotGeneration: 1,
        outcome: .transport(.cancelledBeforeDispatch(ticket: ticket, kind: .loop))
    )
}

@main
struct L3AW41StagedPhysicalCaptureStress {
    static func main() async {
        let total = 100_000
        let coordinator = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
            correlator: L3AW41StressCorrelator(),
            sessionCapacity: 4_096,
            pendingCapacity: 4_096,
            issueDetailCapacity: 16,
            retiredIdentityCapacity: 4_096
        )

        let start = DispatchTime.now().uptimeNanoseconds
        for index in 0..<total {
            let id = UInt64(index)
            let began = await coordinator.beginSample(
                sampleID: id,
                firstIntentUptimeNanoseconds: id,
                requestedTarget: .loopDisabled
            )
            precondition(began == .accepted)
            let finalized = await coordinator.recordStampedOutcome(
                sampleID: id,
                stamped: l3aw41StressNonExecuted(ticket: id)
            )
            precondition(finalized == .finalizedNonExecuted)
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let snapshot = await coordinator.snapshot()

        precondition(snapshot.pendingCount == 0)
        precondition(snapshot.finalizingCount == 0)
        precondition(snapshot.retiredIdentityCount == 4_096)
        precondition(snapshot.retiredIdentityDrops == 95_904)
        precondition(snapshot.finalizedNonExecutedCount == 100_000)
        precondition(snapshot.issueCount == 1)
        precondition(snapshot.issueDetailDrops == 0)

        print(
            "L3-AW41 stress PASS total=\(total) retainedRetired=\(snapshot.retiredIdentityCount) "
                + "retiredDrops=\(snapshot.retiredIdentityDrops) finalizedNonExecuted="
                + "\(snapshot.finalizedNonExecutedCount) issues=\(snapshot.issueCount) elapsedNs=\(elapsed)"
        )
    }
}
