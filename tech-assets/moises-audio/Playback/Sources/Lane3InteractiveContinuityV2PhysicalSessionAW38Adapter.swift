import Foundation

public extension Lane3InteractiveContinuityV2PhysicalSessionBuffer {
    /// Appends only a usable AW38 v2 executed observation. The AW35 legacy-conversion warning for
    /// loop-disable is intentionally non-blocking here because AW40 remains entirely on the v2 path.
    /// Every other AW38 instrumentation issue remains fail-closed for physical-session completeness.
    @discardableResult
    mutating func append(
        instrumentationResult: Lane3InteractiveContinuityInstrumentationResult
    ) -> Bool {
        guard let observation = instrumentationResult.observation else {
            noteUnusableInstrumentationResult()
            return false
        }

        let shape: Lane3InteractiveContinuityV2OperationShape
        switch observation.requestedTarget {
        case .seek:
            shape = .seek
        case .loop:
            shape = .loopEnabled
        case .loopDisabled:
            shape = .loopDisabled
        }

        let blockingInstrumentationIssues = instrumentationResult.issues.filter { issue in
            issue.kind != .legacyAW35CannotRepresentLoopDisabled
        }
        let validation = Lane3InteractiveContinuityInstrumentationValidator.validate(observation)
        append(.init(
            sampleID: observation.sampleID,
            shape: shape,
            firstIntentUptimeNanoseconds: observation.firstIntentUptimeNanoseconds,
            tokenIssuedUptimeNanoseconds: observation.tokenIssuedUptimeNanoseconds,
            backendCompletedUptimeNanoseconds: observation.backendCompletedUptimeNanoseconds,
            audibleResultUptimeNanoseconds: observation.audibleResultUptimeNanoseconds,
            audibleTimestampSource: observation.audibleTimestampSource,
            callerCancellationObservedAfterDispatch: observation.callerCancellationObservedAfterDispatch,
            instrumentationValidForV2: blockingInstrumentationIssues.isEmpty,
            generationStable: validation.generationStable,
            timingOrderValid: validation.timingOrderValid,
            targetMatched: validation.targetMatched,
            externalAudibleMarkerValid: validation.externalAudibleMarkerValid
        ))
        return true
    }

    /// AW39 keeps non-executed guarded outcomes out of executed evidence. AW40 preserves that rule by
    /// counting them separately; they never enter latency percentiles or physical executed coverage.
    @discardableResult
    mutating func append(
        leaseStampedCorrelation: Lane3LeaseStampedContinuityCorrelation
    ) -> Bool {
        switch leaseStampedCorrelation {
        case .instrumented(let result):
            return append(instrumentationResult: result)
        case .nonExecuted:
            noteNonExecutedObservation()
            return false
        }
    }
}
