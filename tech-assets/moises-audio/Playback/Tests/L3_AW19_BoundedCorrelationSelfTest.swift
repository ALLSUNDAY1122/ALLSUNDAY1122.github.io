import Foundation

private func aw19CorrelationReceipt(
    serial: UInt64,
    generation: UInt64
) -> PracticeDSPGenerationCoordinatorReceipt {
    PracticeDSPGenerationCoordinatorReceipt(
        schemaVersion: 1,
        evidenceScope: "AW19_CORRELATION_TEST_NON_PARITY",
        operationSerial: serial,
        mutationKind: .transportDiscontinuity,
        playbackGeneration: generation,
        clickGeneration: generation,
        reason: PlaybackTransportDiscontinuityReason.play.rawValue,
        replacementBindingActive: true,
        parityPromotionAllowed: false
    )
}

@main
struct L3AW19BoundedCorrelationSelfTest {
    static func main() async {
        let collector = Lane3ProductionTelemetryCollector()
        let bridge = Lane3TelemetryDispatchCorrelationBridge(maxPendingPerKind: 2)

        for index in 0..<5 {
            await bridge.recordBackendEntry(
                kind: .play,
                atNanoseconds: UInt64(10_000_000 + index * 1_000_000)
            )
        }
        var health = await bridge.snapshot()
        precondition(health.pendingEntries == 2)
        precondition(health.overflowDrops == 3)
        precondition(health.unmatchedBackendOutcomes == 0)

        for ticket in 0..<2 {
            let receipt = Lane3UnifiedTransportExecutionReceipt(
                ticket: UInt64(ticket + 1),
                kind: .play,
                coalescedPredecessorCount: 0,
                playbackGeneration: UInt64(ticket + 1),
                coordinatorReceipt: aw19CorrelationReceipt(
                    serial: UInt64(ticket + 1),
                    generation: UInt64(ticket + 1)
                ),
                callerCancellationObservedAfterDispatch: false
            )
            let guarded = Lane3InterruptionGuardedOutcome.transport(.executed(receipt))
            await bridge.forwardCorrelation(
                for: guarded,
                expectedProductKind: .play,
                to: collector
            )
            await collector.recordGuardedSubmission(
                kind: .play,
                startedAtNanoseconds: UInt64(8_000_000 + ticket * 1_000_000),
                completedAtNanoseconds: UInt64(20_000_000 + ticket * 1_000_000),
                outcome: guarded
            )
        }

        health = await bridge.snapshot()
        precondition(health.pendingEntries == 0)
        precondition(health.overflowDrops == 3)
        precondition(health.unmatchedBackendOutcomes == 0)

        let snapshot = await collector.snapshot()
        let play = snapshot.perKind.first(where: {
            $0.kind == Lane3UnifiedTransportKind.play.rawValue
        })!
        precondition(play.submissionToBackendEntryLatency.samples == 2)
        precondition(snapshot.backendDispatchEntrySamplesUnmatched == 0)

        let missing = Lane3InterruptionGuardedOutcome.transport(.executed(
            Lane3UnifiedTransportExecutionReceipt(
                ticket: 3,
                kind: .play,
                coalescedPredecessorCount: 0,
                playbackGeneration: 3,
                coordinatorReceipt: aw19CorrelationReceipt(serial: 3, generation: 3),
                callerCancellationObservedAfterDispatch: false
            )
        ))
        await bridge.forwardCorrelation(
            for: missing,
            expectedProductKind: .play,
            to: collector
        )
        health = await bridge.snapshot()
        precondition(health.unmatchedBackendOutcomes == 1)

        print("L3-AW19 bounded correlation self-test PASS")
    }
}
