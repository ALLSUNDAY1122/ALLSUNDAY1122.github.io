#if canImport(AVFAudio)
import AVFAudio
import AudioToolbox
import Foundation

/// Apple-specific pitch transition adapter for the selected `AVAudioUnitTimePitch` baseline.
/// The generic transactional gate owns commit/rollback semantics. This adapter only schedules a
/// sample-frame ramp when the live Audio Unit exposes a rampable pitch parameter; otherwise it
/// falls back to the existing immediate backend write and records why.
extension AppleTimePitchBackend: PracticeDSPPitchTransitionBackendApplying {
    public func beginPitchTransition(
        tempoRatio: Double,
        fromPitchSemitones: Double,
        toPitchSemitones: Double,
        policy: PracticeDSPPitchTransitionPolicy
    ) throws -> PracticeDSPPitchTransitionBackendReceipt {
        guard tempoRatio.isFinite, capabilities.tempoRatioRange.contains(tempoRatio) else {
            throw ApplePracticeDSPBackendError.invalidTempoRatio(tempoRatio)
        }
        guard fromPitchSemitones.isFinite,
              toPitchSemitones.isFinite,
              capabilities.pitchSemitoneRange.contains(fromPitchSemitones),
              capabilities.pitchSemitoneRange.contains(toPitchSemitones) else {
            throw ApplePracticeDSPBackendError.invalidPitchSemitones(toPitchSemitones)
        }

        let sampleRate = node.outputFormat(forBus: 0).sampleRate
        guard sampleRate.isFinite, sampleRate > 0 else {
            try apply(tempoRatio: tempoRatio, pitchSemitones: toPitchSemitones)
            return .immediateFallback(
                reason: .sampleRateUnavailable,
                fromSemitones: fromPitchSemitones,
                toSemitones: toPitchSemitones,
                sampleRate: max(0, sampleRate.isFinite ? sampleRate : 0)
            )
        }

        let plan = try PracticeDSPPitchTransitionPlanner.makePlan(
            fromSemitones: fromPitchSemitones,
            toSemitones: toPitchSemitones,
            sampleRate: sampleRate,
            policy: policy
        )
        guard plan.mode == .scheduledRamp else {
            try apply(tempoRatio: tempoRatio, pitchSemitones: toPitchSemitones)
            return PracticeDSPPitchTransitionBackendReceipt(plan: plan)
        }

        let audioUnit = node.auAudioUnit
        guard audioUnit.renderResourcesAllocated else {
            try apply(tempoRatio: tempoRatio, pitchSemitones: toPitchSemitones)
            return .immediateFallback(
                reason: .renderResourcesUnavailable,
                fromSemitones: fromPitchSemitones,
                toSemitones: toPitchSemitones,
                sampleRate: sampleRate
            )
        }
        guard let parameter = pitchParameter() else {
            try apply(tempoRatio: tempoRatio, pitchSemitones: toPitchSemitones)
            return .immediateFallback(
                reason: .pitchParameterUnavailable,
                fromSemitones: fromPitchSemitones,
                toSemitones: toPitchSemitones,
                sampleRate: sampleRate
            )
        }
        guard parameter.flags.contains(.flag_CanRamp) else {
            try apply(tempoRatio: tempoRatio, pitchSemitones: toPitchSemitones)
            return .immediateFallback(
                reason: .pitchParameterNotRampable,
                fromSemitones: fromPitchSemitones,
                toSemitones: toPitchSemitones,
                sampleRate: sampleRate
            )
        }

        node.rate = Float(tempoRatio)
        let schedule = audioUnit.scheduleParameterBlock
        schedule(
            AUEventSampleTimeImmediate,
            plan.rampDurationFrames,
            parameter.address,
            AUValue(PracticeDSPMath.cents(forSemitones: toPitchSemitones))
        )
        return PracticeDSPPitchTransitionBackendReceipt(plan: plan)
    }

    public func finalizePitchTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws {
        try applyExactPitch(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    public func cancelPitchTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws {
        try applyExactPitch(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    private func applyExactPitch(tempoRatio: Double, pitchSemitones: Double) throws {
        guard tempoRatio.isFinite, capabilities.tempoRatioRange.contains(tempoRatio) else {
            throw ApplePracticeDSPBackendError.invalidTempoRatio(tempoRatio)
        }
        guard pitchSemitones.isFinite, capabilities.pitchSemitoneRange.contains(pitchSemitones) else {
            throw ApplePracticeDSPBackendError.invalidPitchSemitones(pitchSemitones)
        }
        node.rate = Float(tempoRatio)
        let cents = AUValue(PracticeDSPMath.cents(forSemitones: pitchSemitones))
        if node.auAudioUnit.renderResourcesAllocated, let parameter = pitchParameter() {
            node.auAudioUnit.scheduleParameterBlock(
                AUEventSampleTimeImmediate,
                0,
                parameter.address,
                cents
            )
        }
        node.pitch = Float(cents)
    }

    private func pitchParameter() -> AUParameter? {
        node.auAudioUnit.parameterTree?.parameter(
            withID: kNewTimePitchParam_Pitch,
            scope: kAudioUnitScope_Global,
            element: 0
        )
    }
}
#endif
