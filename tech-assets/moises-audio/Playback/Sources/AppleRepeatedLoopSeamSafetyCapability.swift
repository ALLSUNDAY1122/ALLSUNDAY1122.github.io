import Foundation

/// Lane 3's current selected Apple gain path deliberately reports repeated-loop future automation as
/// unavailable. `AppleTransactionalStemGainRampStage` currently schedules only immediate ramps and
/// exposes no event token, cancellation operation, or generation-isolated future-event queue. This
/// descriptor must stay fail-closed until a different selected implementation proves those properties.
public enum Lane3SelectedAppleRepeatedLoopSeamSafety {
    public static let capability = PlaybackRepeatedLoopSeamCapabilityInput(
        exactFutureSampleTimeSchedulingImplemented: false,
        revocationMechanism: .none,
        staleEventRevocationOrIsolationProven: false,
        seekInvalidationConnected: false,
        tempoInvalidationConnected: false,
        lifecycleInvalidationConnected: false,
        revocationPathAudiblySafe: false,
        selectedIntegrationExecutionPresent: false,
        physicalDeviceAudibilityValidationPresent: false
    )

    public static var report: PlaybackRepeatedLoopSeamSafetyReport {
        PlaybackRepeatedLoopSeamSafetyEvaluator.evaluate(capability)
    }
}

#if canImport(AVFAudio)
public extension AppleBoundaryEnvelopedPlaybackBackend {
    /// Selected-stack query for HQ/iOS integration. This is capability evidence only; it never arms
    /// a gain event and cannot promote PARITY.
    func repeatedLoopSeamSafetyReport() -> PlaybackRepeatedLoopSeamSafetyReport {
        Lane3SelectedAppleRepeatedLoopSeamSafety.report
    }
}
#endif
