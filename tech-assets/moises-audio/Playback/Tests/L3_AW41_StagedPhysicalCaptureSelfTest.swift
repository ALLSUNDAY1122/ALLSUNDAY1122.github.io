import Foundation

private struct L3AW41FakeCorrelator: Lane3LeaseStampedContinuityCorrelating {
    func correlateLeaseStamped(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3LeaseStampedContinuityCorrelation {
        guard case .transport(.executed(let receipt)) = stamped.outcome else {
            return .nonExecuted(slotGeneration: stamped.slotGeneration, outcome: stamped.outcome)
        }
        let operation: Lane3InteractiveContinuityOperationKind = receipt.kind == .seek ? .seek : .loop
        let issues: [Lane3InteractiveContinuityInstrumentationIssue]
        if case .loopDisabled = requestedTarget {
            issues = [.init(
                kind: .legacyAW35CannotRepresentLoopDisabled,
                detail: "expected v2-only loop-disable warning"
            )]
        } else {
            issues = []
        }
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
        return .instrumented(.init(observation: observation, issues: issues))
    }
}

private func l3aw41CoordinatorReceipt(playbackGeneration: UInt64) throws -> PracticeDSPGenerationCoordinatorReceipt {
    let json = """
    {
      "schemaVersion": 1,
      "evidenceScope": "L3-AW41-TEST",
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

private func l3aw41ExecutedStamped(
    ticket: UInt64,
    kind: Lane3UnifiedTransportKind,
    generation: UInt64,
    slotGeneration: UInt64
) throws -> Lane3SelectedTransportGenerationStampedOutcome {
    let receipt = Lane3UnifiedTransportExecutionReceipt(
        ticket: ticket,
        kind: kind,
        coalescedPredecessorCount: 0,
        playbackGeneration: generation,
        coordinatorReceipt: try l3aw41CoordinatorReceipt(playbackGeneration: generation),
        callerCancellationObservedAfterDispatch: false
    )
    return .init(
        slotGeneration: slotGeneration,
        outcome: .transport(.executed(receipt))
    )
}

private func l3aw41NonExecutedStamped(
    ticket: UInt64,
    slotGeneration: UInt64
) -> Lane3SelectedTransportGenerationStampedOutcome {
    .init(
        slotGeneration: slotGeneration,
        outcome: .transport(.cancelledBeforeDispatch(ticket: ticket, kind: .loop))
    )
}

private func l3aw41Context() -> Lane3InteractiveContinuityV2PhysicalSessionContext {
    .init(
        sessionIdentifier: "aw41-device-session",
        physicalIPhone: true,
        hardwareIdentifier: "iPhone-test-hardware",
        osVersion: "iOS-test",
        appBuildIdentifier: "build-test",
        sampleRate: 48_000,
        uptimeClockDomain: "system-uptime-nanoseconds",
        audioFixtureIdentifier: "rights-cleared-fixture-hash",
        rightsClearedRealAudio: true,
        currentMoisesDifferentialObserved: true,
        humanListeningObserved: true
    )
}

private func l3aw41Expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    precondition(actual == expected, label)
}

@main
struct L3AW41StagedPhysicalCaptureSelfTest {
    static func main() async throws {
        let coordinator = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
            correlator: L3AW41FakeCorrelator(),
            sessionCapacity: 64,
            pendingCapacity: 16,
            issueDetailCapacity: 16,
            retiredIdentityCapacity: 16
        )

        let marker1 = Lane3InteractiveContinuityV2AudibleMarker(
            uptimeNanoseconds: 140,
            source: "external-audio-observer"
        )
        var disposition = await coordinator.beginSample(
            sampleID: 1,
            firstIntentUptimeNanoseconds: 100,
            requestedTarget: .seek(positionSeconds: 12.5)
        )
        l3aw41Expect(disposition, .accepted, "seek begin")
        disposition = await coordinator.recordAudibleMarker(sampleID: 1, marker: marker1)
        l3aw41Expect(disposition, .accepted, "seek marker-first")
        disposition = await coordinator.recordAudibleMarker(sampleID: 1, marker: marker1)
        l3aw41Expect(disposition, .idempotentDuplicateIgnored, "pending duplicate marker")
        let seekStamped = try l3aw41ExecutedStamped(
            ticket: 11,
            kind: .seek,
            generation: 101,
            slotGeneration: 7
        )
        disposition = await coordinator.recordStampedOutcome(sampleID: 1, stamped: seekStamped)
        l3aw41Expect(disposition, .finalizedExecuted, "seek finalize")
        disposition = await coordinator.recordAudibleMarker(sampleID: 1, marker: marker1)
        l3aw41Expect(disposition, .idempotentDuplicateIgnored, "retired duplicate marker")
        disposition = await coordinator.recordStampedOutcome(sampleID: 1, stamped: seekStamped)
        l3aw41Expect(disposition, .idempotentDuplicateIgnored, "retired duplicate stamp")

        disposition = await coordinator.beginSample(
            sampleID: 2,
            firstIntentUptimeNanoseconds: 200,
            requestedTarget: .loop(startSeconds: 5, endSeconds: 9)
        )
        l3aw41Expect(disposition, .accepted, "enabled loop begin")
        disposition = await coordinator.recordStampedOutcome(
            sampleID: 2,
            stamped: try l3aw41ExecutedStamped(
                ticket: 12,
                kind: .loop,
                generation: 102,
                slotGeneration: 7
            )
        )
        l3aw41Expect(disposition, .accepted, "enabled loop stamp-first")
        disposition = await coordinator.recordAudibleMarker(
            sampleID: 2,
            marker: .init(uptimeNanoseconds: 245, source: "external-audio-observer")
        )
        l3aw41Expect(disposition, .finalizedExecuted, "enabled loop finalize")

        disposition = await coordinator.beginSample(
            sampleID: 3,
            firstIntentUptimeNanoseconds: 300,
            requestedTarget: .loopDisabled
        )
        l3aw41Expect(disposition, .accepted, "loop disable begin")
        disposition = await coordinator.recordStampedOutcome(
            sampleID: 3,
            stamped: try l3aw41ExecutedStamped(
                ticket: 13,
                kind: .loop,
                generation: 103,
                slotGeneration: 8
            )
        )
        l3aw41Expect(disposition, .accepted, "loop disable stamp")
        disposition = await coordinator.recordAudibleMarker(
            sampleID: 3,
            marker: .init(uptimeNanoseconds: 350, source: "external-audio-observer")
        )
        l3aw41Expect(disposition, .finalizedExecuted, "loop disable finalize")

        disposition = await coordinator.beginSample(
            sampleID: 4,
            firstIntentUptimeNanoseconds: 400,
            requestedTarget: .loopDisabled
        )
        l3aw41Expect(disposition, .accepted, "nonexecuted begin")
        disposition = await coordinator.recordStampedOutcome(
            sampleID: 4,
            stamped: l3aw41NonExecutedStamped(ticket: 14, slotGeneration: 8)
        )
        l3aw41Expect(disposition, .finalizedNonExecuted, "nonexecuted finalize")

        let positive = await coordinator.report(context: l3aw41Context())
        precondition(positive.capture.pendingCount == 0)
        precondition(positive.capture.finalizingCount == 0)
        precondition(positive.capture.finalizedExecutedCount == 3)
        precondition(positive.capture.finalizedNonExecutedCount == 1)
        precondition(positive.capture.idempotentDuplicateCallbackCount == 3)
        precondition(positive.capture.issueCount == 0)
        precondition(positive.physicalSession.seekSampleCount == 1)
        precondition(positive.physicalSession.enabledLoopSampleCount == 1)
        precondition(positive.physicalSession.loopDisabledSampleCount == 1)
        precondition(positive.captureCoordinatorComplete)
        precondition(positive.physicalSessionComplete)
        precondition(positive.differentialListeningBundleComplete)
        precondition(!positive.parityPromotionAllowed)

        let contradictory = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
            correlator: L3AW41FakeCorrelator(),
            sessionCapacity: 16,
            pendingCapacity: 16,
            issueDetailCapacity: 16,
            retiredIdentityCapacity: 16
        )
        _ = await contradictory.beginSample(
            sampleID: 20,
            firstIntentUptimeNanoseconds: 1_000,
            requestedTarget: .seek(positionSeconds: 1)
        )
        _ = await contradictory.recordAudibleMarker(
            sampleID: 20,
            marker: .init(uptimeNanoseconds: 1_040, source: "external-audio-observer")
        )
        _ = await contradictory.recordStampedOutcome(
            sampleID: 20,
            stamped: l3aw41NonExecutedStamped(ticket: 20, slotGeneration: 9)
        )
        let contradictoryReport = await contradictory.report(context: l3aw41Context())
        precondition(contradictoryReport.capture.issueCount == 1)
        precondition(!contradictoryReport.captureCoordinatorComplete)
        precondition(!contradictoryReport.physicalSessionComplete)

        let expiry = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
            correlator: L3AW41FakeCorrelator(),
            sessionCapacity: 16,
            pendingCapacity: 16,
            issueDetailCapacity: 16,
            retiredIdentityCapacity: 16
        )
        _ = await expiry.beginSample(
            sampleID: 30,
            firstIntentUptimeNanoseconds: 2_000,
            requestedTarget: .seek(positionSeconds: 2)
        )
        _ = await expiry.beginSample(
            sampleID: 31,
            firstIntentUptimeNanoseconds: 2_100,
            requestedTarget: .loopDisabled
        )
        _ = await expiry.recordStampedOutcome(
            sampleID: 31,
            stamped: try l3aw41ExecutedStamped(
                ticket: 31,
                kind: .loop,
                generation: 131,
                slotGeneration: 10
            )
        )
        let expired = await expiry.expirePending(firstIntentBeforeUptimeNanoseconds: 3_000)
        precondition(expired == 2)
        let expirySnapshot = await expiry.snapshot()
        precondition(expirySnapshot.expiredCount == 2)
        precondition(expirySnapshot.issueCount == 2)
        precondition(expirySnapshot.pendingCount == 0)

        let bounded = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
            correlator: L3AW41FakeCorrelator(),
            sessionCapacity: 64,
            pendingCapacity: 16,
            issueDetailCapacity: 16,
            retiredIdentityCapacity: 16
        )
        for index in 0..<17 {
            _ = await bounded.beginSample(
                sampleID: UInt64(index),
                firstIntentUptimeNanoseconds: UInt64(index),
                requestedTarget: .loopDisabled
            )
            _ = await bounded.recordStampedOutcome(
                sampleID: UInt64(index),
                stamped: l3aw41NonExecutedStamped(
                    ticket: UInt64(index),
                    slotGeneration: 1
                )
            )
        }
        let boundedSnapshot = await bounded.snapshot()
        precondition(boundedSnapshot.retiredIdentityCount == 16)
        precondition(boundedSnapshot.retiredIdentityDrops == 1)
        precondition(boundedSnapshot.issueCount == 1)

        print(
            "L3-AW41 staged capture PASS executed=\(positive.capture.finalizedExecutedCount) "
                + "nonExecuted=\(positive.capture.finalizedNonExecutedCount) "
                + "duplicates=\(positive.capture.idempotentDuplicateCallbackCount) "
                + "expiry=\(expirySnapshot.expiredCount) retiredDrops=\(boundedSnapshot.retiredIdentityDrops)"
        )
    }
}
