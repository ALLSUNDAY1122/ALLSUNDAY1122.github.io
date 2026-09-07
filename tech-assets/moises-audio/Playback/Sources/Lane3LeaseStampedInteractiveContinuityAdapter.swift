import Foundation

public enum Lane3LeaseStampedContinuityCorrelation: Equatable, Sendable {
    case instrumented(Lane3InteractiveContinuityInstrumentationResult)
    case nonExecuted(
        slotGeneration: UInt64,
        outcome: Lane3InterruptionGuardedOutcome
    )
}

/// AW39 bridge from the selected reconstruction slot to AW38 instrumentation. The slot generation
/// comes from the exact shared lease that carried the operation, not snapshots taken before/after
/// submission. A reconstruction that starts immediately after lease release therefore cannot create
/// a false `executedAcrossSlotGeneration` observation for already-completed work.
public extension Lane3SelectedInteractiveContinuityInstrumentationAdapter {
    func correlateLeaseStamped(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3LeaseStampedContinuityCorrelation {
        guard case .transport(.executed(let receipt)) = stamped.outcome else {
            return .nonExecuted(
                slotGeneration: stamped.slotGeneration,
                outcome: stamped.outcome
            )
        }

        let result = await correlateExecuted(
            sampleID: sampleID,
            receipt: receipt,
            slotGenerationAtIntent: stamped.slotGeneration,
            slotGenerationAtCompletion: stamped.slotGeneration,
            firstIntentUptimeNanoseconds: firstIntentUptimeNanoseconds,
            requestedTarget: requestedTarget,
            audibleResultUptimeNanoseconds: audibleResultUptimeNanoseconds,
            audibleTimestampSource: audibleTimestampSource
        )
        return .instrumented(result)
    }
}
