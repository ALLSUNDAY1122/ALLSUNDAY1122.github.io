import Foundation

extension PracticeDSPTempoTransitionPolicy {
    /// Selected AW32 policy for the AW31 two-phase tempo boundary only.
    /// Playback has already faded to silence and stopped before the DSP transaction starts, so an
    /// audible in-flight rate ramp has no benefit and only lengthens the muted restart interval.
    /// Keeping this as a distinct policy prevents the live/in-place AW28 ramp from being weakened.
    public static let boundaryMutedImmediate = PracticeDSPTempoTransitionPolicy(
        immediateLogRatioThreshold: Double.greatestFiniteMagnitude,
        minimumRampSeconds: 0.008,
        secondsPerNaturalLogRatio: 0,
        maximumRampSeconds: 0.008,
        settleSeconds: 0,
        maximumRampFrames: 4_096
    )
}
