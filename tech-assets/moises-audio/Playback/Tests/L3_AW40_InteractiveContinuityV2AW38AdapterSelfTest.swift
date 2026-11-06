import Foundation

@main
struct L3AW40InteractiveContinuityV2AW38AdapterSelfTest {
    static func main() {
        let loopDisabledObservation = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: 1,
            operation: .loop,
            slotGenerationAtIntent: 7,
            slotGenerationAtCompletion: 7,
            transportTicket: 11,
            playbackGeneration: 13,
            firstIntentUptimeNanoseconds: 100,
            tokenIssuedUptimeNanoseconds: 110,
            backendCompletedUptimeNanoseconds: 120,
            audibleResultUptimeNanoseconds: 140,
            requestedTarget: .loopDisabled,
            appliedTarget: .loopDisabled,
            callerCancellationObservedAfterDispatch: false,
            audibleTimestampSource: "external-audio-observer"
        )
        let loopDisabledResult = Lane3InteractiveContinuityInstrumentationResult(
            observation: loopDisabledObservation,
            issues: [.init(
                kind: .legacyAW35CannotRepresentLoopDisabled,
                detail: "expected AW35-only representation warning"
            )]
        )

        var buffer = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 16)
        precondition(buffer.append(instrumentationResult: loopDisabledResult))
        let retained = buffer.orderedSamples()
        precondition(retained.count == 1)
        precondition(retained[0].shape == .loopDisabled)
        precondition(retained[0].instrumentationValidForV2)
        precondition(retained[0].generationStable)
        precondition(retained[0].timingOrderValid)
        precondition(retained[0].targetMatched)
        precondition(retained[0].externalAudibleMarkerValid)

        let unusable = Lane3InteractiveContinuityInstrumentationResult(
            observation: nil,
            issues: [.init(kind: .missingTokenTiming, detail: "forced missing timing")]
        )
        precondition(!buffer.append(instrumentationResult: unusable))
        precondition(buffer.unusableInstrumentationResultCount == 1)
        precondition(buffer.retainedCount == 1)

        print(
            "L3-AW40 AW38 bridge PASS loopDisabledV2=1 unusable="
                + "\(buffer.unusableInstrumentationResultCount)"
        )
    }
}
