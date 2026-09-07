import Foundation

@main
struct L3AW38InstrumentationValidationSelfTest {
    static func main() {
        let valid = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: 1,
            operation: .seek,
            slotGenerationAtIntent: 4,
            slotGenerationAtCompletion: 4,
            transportTicket: 8,
            playbackGeneration: 9,
            firstIntentUptimeNanoseconds: 1_000,
            tokenIssuedUptimeNanoseconds: 2_000,
            backendCompletedUptimeNanoseconds: 3_000,
            audibleResultUptimeNanoseconds: 4_000,
            requestedTarget: .seek(positionSeconds: 12.5),
            appliedTarget: .seek(positionSeconds: 12.5),
            callerCancellationObservedAfterDispatch: false,
            audibleTimestampSource: "physical-loopback-marker"
        )
        let validReport = Lane3InteractiveContinuityInstrumentationValidator.validate(valid)
        precondition(validReport.issues.isEmpty)
        precondition(validReport.generationStable)
        precondition(validReport.timingOrderValid)
        precondition(validReport.targetMatched)
        precondition(validReport.externalAudibleMarkerValid)
        precondition(validReport.physicalMeasurementFieldsComplete)
        precondition(!validReport.parityPromotionAllowed)

        let loopDisabled = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: 2,
            operation: .loop,
            slotGenerationAtIntent: 5,
            slotGenerationAtCompletion: 5,
            transportTicket: 10,
            playbackGeneration: 11,
            firstIntentUptimeNanoseconds: 10_000,
            tokenIssuedUptimeNanoseconds: 11_000,
            backendCompletedUptimeNanoseconds: 12_000,
            audibleResultUptimeNanoseconds: 13_000,
            requestedTarget: .loopDisabled,
            appliedTarget: .loopDisabled,
            callerCancellationObservedAfterDispatch: false,
            audibleTimestampSource: "physical-loopback-marker"
        )
        let loopDisabledReport = Lane3InteractiveContinuityInstrumentationValidator.validate(loopDisabled)
        precondition(loopDisabledReport.physicalMeasurementFieldsComplete)
        precondition(loopDisabled.legacyAW35Observation() == nil)

        let invalid = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: 3,
            operation: .loop,
            slotGenerationAtIntent: 8,
            slotGenerationAtCompletion: 9,
            transportTicket: 12,
            playbackGeneration: 13,
            firstIntentUptimeNanoseconds: 5_000,
            tokenIssuedUptimeNanoseconds: 4_000,
            backendCompletedUptimeNanoseconds: 3_000,
            audibleResultUptimeNanoseconds: 2_000,
            requestedTarget: .loop(startSeconds: 2, endSeconds: 6),
            appliedTarget: .loop(startSeconds: 2, endSeconds: 7),
            callerCancellationObservedAfterDispatch: false,
            audibleTimestampSource: "physical-loopback-marker"
        )
        let invalidReport = Lane3InteractiveContinuityInstrumentationValidator.validate(invalid)
        let kinds = Set(invalidReport.issues.map(\.kind))
        precondition(kinds.contains(.executedAcrossSlotGeneration))
        precondition(kinds.contains(.tokenBeforeIntent))
        precondition(kinds.contains(.backendCompletionBeforeToken))
        precondition(kinds.contains(.audibleBeforeToken))
        precondition(kinds.contains(.targetMismatch))
        precondition(!invalidReport.physicalMeasurementFieldsComplete)

        let missingAudible = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: 4,
            operation: .seek,
            slotGenerationAtIntent: 1,
            slotGenerationAtCompletion: 1,
            transportTicket: 14,
            playbackGeneration: 15,
            firstIntentUptimeNanoseconds: 1_000,
            tokenIssuedUptimeNanoseconds: 2_000,
            backendCompletedUptimeNanoseconds: 3_000,
            audibleResultUptimeNanoseconds: nil,
            requestedTarget: .seek(positionSeconds: 3),
            appliedTarget: .seek(positionSeconds: 3),
            callerCancellationObservedAfterDispatch: false,
            audibleTimestampSource: nil
        )
        let missingReport = Lane3InteractiveContinuityInstrumentationValidator.validate(missingAudible)
        precondition(missingReport.issues.contains { $0.kind == .missingExternalAudibleMarker })
        precondition(!missingReport.physicalMeasurementFieldsComplete)

        print("L3-AW38 instrumentation validation self-test PASS")
    }
}
