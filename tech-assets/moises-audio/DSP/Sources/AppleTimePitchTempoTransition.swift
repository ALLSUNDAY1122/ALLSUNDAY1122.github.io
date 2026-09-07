#if canImport(AVFAudio)
import AVFAudio
import AudioToolbox
import Foundation

/// Apple-specific tempo transition adapter for `AVAudioUnitTimePitch`.
/// The generic transactional gate owns serialization/commit/rollback. This adapter schedules one
/// sample-frame rate ramp when the live Audio Unit exposes a rampable rate parameter. Unsupported
/// runtime states fall back to the existing immediate write with an explicit NON_PARITY receipt.
extension AppleTimePitchBackend: PracticeDSPTempoTransitionBackendApplying {
    public func beginTempoTransition(
        fromTempoRatio: Double,
        toTempoRatio: Double,
        pitchSemitones: Double,
        policy: PracticeDSPTempoTransitionPolicy
    ) throws -> PracticeDSPTempoTransitionBackendReceipt {
        guard fromTempoRatio.isFinite,
              capabilities.tempoRatioRange.contains(fromTempoRatio),
              toTempoRatio.isFinite,
              capabilities.tempoRatioRange.contains(toTempoRatio) else {
            throw ApplePracticeDSPBackendError.invalidTempoRatio(toTempoRatio)
        }
        guard pitchSemitones.isFinite,
              capabilities.pitchSemitoneRange.contains(pitchSemitones) else {
            throw ApplePracticeDSPBackendError.invalidPitchSemitones(pitchSemitones)
        }

        let sampleRate = node.outputFormat(forBus: 0).sampleRate
        guard sampleRate.isFinite, sampleRate > 0 else {
            try apply(tempoRatio: toTempoRatio, pitchSemitones: pitchSemitones)
            return .immediateFallback(
                reason: .sampleRateUnavailable,
                fromRatio: fromTempoRatio,
                toRatio: toTempoRatio,
                sampleRate: max(0, sampleRate.isFinite ? sampleRate : 0)
            )
        }

        let plan = try PracticeDSPTempoTransitionPlanner.makePlan(
            fromRatio: fromTempoRatio,
            toRatio: toTempoRatio,
            sampleRate: sampleRate,
            policy: policy
        )
        guard plan.mode == .scheduledRamp else {
            try apply(tempoRatio: toTempoRatio, pitchSemitones: pitchSemitones)
            return PracticeDSPTempoTransitionBackendReceipt(plan: plan)
        }

        let audioUnit = node.auAudioUnit
        guard audioUnit.renderResourcesAllocated else {
            try apply(tempoRatio: toTempoRatio, pitchSemitones: pitchSemitones)
            return .immediateFallback(
                reason: .renderResourcesUnavailable,
                fromRatio: fromTempoRatio,
                toRatio: toTempoRatio,
                sampleRate: sampleRate
            )
        }
        guard let parameter = rateParameter() else {
            try apply(tempoRatio: toTempoRatio, pitchSemitones: pitchSemitones)
            return .immediateFallback(
                reason: .rateParameterUnavailable,
                fromRatio: fromTempoRatio,
                toRatio: toTempoRatio,
                sampleRate: sampleRate
            )
        }
        guard parameter.flags.contains(.flag_CanRamp) else {
            try apply(tempoRatio: toTempoRatio, pitchSemitones: pitchSemitones)
            return .immediateFallback(
                reason: .rateParameterNotRampable,
                fromRatio: fromTempoRatio,
                toRatio: toTempoRatio,
                sampleRate: sampleRate
            )
        }

        // Pitch is unchanged for this transition branch. Do not assign node.rate here because doing
        // so would defeat the scheduled ramp by causing an immediate rate jump first.
        node.pitch = Float(PracticeDSPMath.cents(forSemitones: pitchSemitones))
        audioUnit.scheduleParameterBlock(
            AUEventSampleTimeImmediate,
            plan.rampDurationFrames,
            parameter.address,
            AUValue(toTempoRatio)
        )
        return PracticeDSPTempoTransitionBackendReceipt(plan: plan)
    }

    public func finalizeTempoTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws {
        try applyExactTempo(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    public func cancelTempoTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws {
        try applyExactTempo(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    private func applyExactTempo(tempoRatio: Double, pitchSemitones: Double) throws {
        guard tempoRatio.isFinite, capabilities.tempoRatioRange.contains(tempoRatio) else {
            throw ApplePracticeDSPBackendError.invalidTempoRatio(tempoRatio)
        }
        guard pitchSemitones.isFinite, capabilities.pitchSemitoneRange.contains(pitchSemitones) else {
            throw ApplePracticeDSPBackendError.invalidPitchSemitones(pitchSemitones)
        }
        let value = AUValue(tempoRatio)
        if node.auAudioUnit.renderResourcesAllocated, let parameter = rateParameter() {
            node.auAudioUnit.scheduleParameterBlock(
                AUEventSampleTimeImmediate,
                0,
                parameter.address,
                value
            )
        }
        node.rate = Float(value)
        node.pitch = Float(PracticeDSPMath.cents(forSemitones: pitchSemitones))
    }

    private func rateParameter() -> AUParameter? {
        node.auAudioUnit.parameterTree?.parameter(
            withID: kNewTimePitchParam_Rate,
            scope: kAudioUnitScope_Global,
            element: 0
        )
    }
}
#endif
