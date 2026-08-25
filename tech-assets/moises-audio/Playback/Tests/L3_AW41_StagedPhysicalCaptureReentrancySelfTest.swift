import Foundation

private actor L3AW41SlowCorrelator: Lane3LeaseStampedContinuityCorrelating {
    private var entered = false
    private var released = false

    func correlateLeaseStamped(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3LeaseStampedContinuityCorrelation {
        entered = true
        while !released { await Task.yield() }
        guard case .transport(.executed(let receipt)) = stamped.outcome else {
            return .nonExecuted(slotGeneration: stamped.slotGeneration, outcome: stamped.outcome)
        }
        let operation: Lane3InteractiveContinuityOperationKind = receipt.kind == .seek ? .seek : .loop
        let observation = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: sampleID,
            operation: operation,
            slotGenerationAtIntent: stamped.slotGeneration,
            slotGenerationAtCompletion: stamped.slotGeneration,
            transportTicket: receipt.ticket,
            playbackGeneration: receipt.playbackGeneration,
            firstIntentUptimeNanoseconds: firstIntentUptimeNanoseconds,
            tokenIssuedUptimeNanoseconds: firstIntentUptimeNanoseconds + 10,
            backendCompletedUptimeNanoseconds: firstIntentUptimeNanoseconds + 20,
            audibleResultUptimeNanoseconds: audibleResultUptimeNanoseconds,
            requestedTarget: requestedTarget,
            appliedTarget: requestedTarget,
            callerCancellationObservedAfterDispatch: receipt.callerCancellationObservedAfterDispatch,
            audibleTimestampSource: audibleTimestampSource
        )
        return .instrumented(.init(observation: observation, issues: []))
    }

    func waitUntilEntered() async {
        while !entered { await Task.yield() }
    }

    func release() {
        released = true
    }
}

private func l3aw41ReentrancyCoordinatorReceipt(
    playbackGeneration: UInt64
) throws -> PracticeDSPGenerationCoordinatorReceipt {
    let json = """
    {
      "schemaVersion": 1,
      "evidenceScope": "L3-AW41-REENTRANCY-TEST",
      "operationSerial": 1,
      "mutationKind": "transportDiscontinuity",
      "playbackGeneration": \(playbackGeneration),
      "clickGeneration": 1,
      "reason": "seek",
      "replacementBindingActive": true,
      "parityPromotionAllowed": false
    }
    """
    return try JSONDecoder().decode(
        PracticeDSPGenerationCoordinatorReceipt.self,
        from: Data(json.utf8)
    )
}

private func l3aw41ReentrancyStamped() throws -> Lane3SelectedTransportGenerationStampedOutcome {
    let receipt = Lane3UnifiedTransportExecutionReceipt(
        ticket: 77,
        kind: .seek,
        coalescedPredecessorCount: 0,
        playbackGeneration: 88,
        coordinatorReceipt: try l3aw41ReentrancyCoordinatorReceipt(playbackGeneration: 88),
        callerCancellationObservedAfterDispatch: false
    )
    return .init(slotGeneration: 9, outcome: .transport(.executed(receipt)))
}

@main
struct L3AW41StagedPhysicalCaptureReentrancySelfTest {
    static func main() async throws {
        let correlator = L3AW41SlowCorrelator()
        let coordinator = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
            correlator: correlator,
            sessionCapacity: 16,
            pendingCapacity: 16,
            issueDetailCapacity: 16,
            retiredIdentityCapacity: 16
        )
        let marker = Lane3InteractiveContinuityV2AudibleMarker(
            uptimeNanoseconds: 140,
            source: "external-audio-observer"
        )
        let stamped = try l3aw41ReentrancyStamped()

        let began = await coordinator.beginSample(
            sampleID: 1,
            firstIntentUptimeNanoseconds: 100,
            requestedTarget: .seek(positionSeconds: 4)
        )
        precondition(began == .accepted)
        let markerAccepted = await coordinator.recordAudibleMarker(sampleID: 1, marker: marker)
        precondition(markerAccepted == .accepted)

        let finalizationTask = Task {
            await coordinator.recordStampedOutcome(sampleID: 1, stamped: stamped)
        }
        await correlator.waitUntilEntered()

        let duplicateMarker = await coordinator.recordAudibleMarker(sampleID: 1, marker: marker)
        precondition(duplicateMarker == .idempotentDuplicateIgnored)
        let duplicateStamp = await coordinator.recordStampedOutcome(sampleID: 1, stamped: stamped)
        precondition(duplicateStamp == .idempotentDuplicateIgnored)
        let during = await coordinator.snapshot()
        precondition(during.pendingCount == 0)
        precondition(during.finalizingCount == 1)
        precondition(during.idempotentDuplicateCallbackCount == 2)
        precondition(during.issueCount == 0)

        await correlator.release()
        let finalized = await finalizationTask.value
        precondition(finalized == .finalizedExecuted)
        let after = await coordinator.snapshot()
        precondition(after.pendingCount == 0)
        precondition(after.finalizingCount == 0)
        precondition(after.finalizedExecutedCount == 1)
        precondition(after.idempotentDuplicateCallbackCount == 2)
        precondition(after.issueCount == 0)

        let conflicting = await coordinator.recordAudibleMarker(
            sampleID: 1,
            marker: .init(uptimeNanoseconds: 141, source: "different-observer")
        )
        precondition(conflicting == .rejected)
        let conflictSnapshot = await coordinator.snapshot()
        precondition(conflictSnapshot.issueCount == 1)

        print(
            "L3-AW41 reentrancy PASS finalizingDuring=\(during.finalizingCount) "
                + "duplicates=\(after.idempotentDuplicateCallbackCount) "
                + "conflicts=\(conflictSnapshot.issueCount)"
        )
    }
}
