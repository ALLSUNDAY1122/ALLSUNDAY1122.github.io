import Foundation

public enum PracticeDSPPitchTransitionMode: String, Codable, Sendable {
    case immediate
    case scheduledRamp
    case immediateFallback
}

public enum PracticeDSPPitchTransitionFallbackReason: String, Codable, Sendable {
    case renderResourcesUnavailable
    case sampleRateUnavailable
    case pitchParameterUnavailable
    case pitchParameterNotRampable
    case backendTransitionUnsupported
}

public struct PracticeDSPPitchTransitionPolicy: Equatable, Codable, Sendable {
    public let immediateDeltaThresholdSemitones: Double
    public let minimumRampSeconds: Double
    public let secondsPerSemitone: Double
    public let maximumRampSeconds: Double
    public let settleSeconds: Double
    public let maximumRampFrames: UInt32

    public init(
        immediateDeltaThresholdSemitones: Double = 0.20,
        minimumRampSeconds: Double = 0.008,
        secondsPerSemitone: Double = 0.002,
        maximumRampSeconds: Double = 0.032,
        settleSeconds: Double = 0.004,
        maximumRampFrames: UInt32 = 4_096
    ) {
        self.immediateDeltaThresholdSemitones = immediateDeltaThresholdSemitones
        self.minimumRampSeconds = minimumRampSeconds
        self.secondsPerSemitone = secondsPerSemitone
        self.maximumRampSeconds = maximumRampSeconds
        self.settleSeconds = settleSeconds
        self.maximumRampFrames = maximumRampFrames
    }

    public static let provisionalAppleInteractive = PracticeDSPPitchTransitionPolicy()
}

public struct PracticeDSPPitchTransitionPlan: Equatable, Codable, Sendable {
    public let mode: PracticeDSPPitchTransitionMode
    public let fromSemitones: Double
    public let toSemitones: Double
    public let sampleRate: Double
    public let rampDurationFrames: UInt32
    public let recommendedBarrierNanoseconds: UInt64

    public init(
        mode: PracticeDSPPitchTransitionMode,
        fromSemitones: Double,
        toSemitones: Double,
        sampleRate: Double,
        rampDurationFrames: UInt32,
        recommendedBarrierNanoseconds: UInt64
    ) {
        self.mode = mode
        self.fromSemitones = fromSemitones
        self.toSemitones = toSemitones
        self.sampleRate = sampleRate
        self.rampDurationFrames = rampDurationFrames
        self.recommendedBarrierNanoseconds = recommendedBarrierNanoseconds
    }
}

public enum PracticeDSPPitchTransitionPlanningError: Error, Equatable, Sendable {
    case invalidPitch(Double)
    case invalidSampleRate(Double)
    case invalidPolicy
    case durationOverflow
}

public enum PracticeDSPPitchTransitionPlanner {
    public static func makePlan(
        fromSemitones: Double,
        toSemitones: Double,
        sampleRate: Double,
        policy: PracticeDSPPitchTransitionPolicy = .provisionalAppleInteractive
    ) throws -> PracticeDSPPitchTransitionPlan {
        guard fromSemitones.isFinite else {
            throw PracticeDSPPitchTransitionPlanningError.invalidPitch(fromSemitones)
        }
        guard toSemitones.isFinite else {
            throw PracticeDSPPitchTransitionPlanningError.invalidPitch(toSemitones)
        }
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 768_000 else {
            throw PracticeDSPPitchTransitionPlanningError.invalidSampleRate(sampleRate)
        }
        guard policy.immediateDeltaThresholdSemitones.isFinite,
              policy.immediateDeltaThresholdSemitones >= 0,
              policy.minimumRampSeconds.isFinite,
              policy.minimumRampSeconds > 0,
              policy.secondsPerSemitone.isFinite,
              policy.secondsPerSemitone >= 0,
              policy.maximumRampSeconds.isFinite,
              policy.maximumRampSeconds >= policy.minimumRampSeconds,
              policy.settleSeconds.isFinite,
              policy.settleSeconds >= 0,
              policy.maximumRampFrames > 0 else {
            throw PracticeDSPPitchTransitionPlanningError.invalidPolicy
        }

        let delta = abs(toSemitones - fromSemitones)
        if delta <= policy.immediateDeltaThresholdSemitones {
            return PracticeDSPPitchTransitionPlan(
                mode: .immediate,
                fromSemitones: fromSemitones,
                toSemitones: toSemitones,
                sampleRate: sampleRate,
                rampDurationFrames: 0,
                recommendedBarrierNanoseconds: 0
            )
        }

        let proposed = max(
            policy.minimumRampSeconds,
            min(policy.maximumRampSeconds, delta * policy.secondsPerSemitone)
        )
        let frameDouble = (proposed * sampleRate).rounded(.toNearestOrAwayFromZero)
        guard frameDouble.isFinite, frameDouble >= 1 else {
            throw PracticeDSPPitchTransitionPlanningError.durationOverflow
        }
        let boundedFrames = min(UInt64(policy.maximumRampFrames), UInt64(frameDouble))
        guard boundedFrames > 0, boundedFrames <= UInt64(UInt32.max) else {
            throw PracticeDSPPitchTransitionPlanningError.durationOverflow
        }
        let actualRampSeconds = Double(boundedFrames) / sampleRate
        let barrierSeconds = actualRampSeconds + policy.settleSeconds
        let nanosDouble = (barrierSeconds * 1_000_000_000).rounded(.up)
        guard nanosDouble.isFinite, nanosDouble >= 0, nanosDouble <= Double(UInt64.max) else {
            throw PracticeDSPPitchTransitionPlanningError.durationOverflow
        }
        return PracticeDSPPitchTransitionPlan(
            mode: .scheduledRamp,
            fromSemitones: fromSemitones,
            toSemitones: toSemitones,
            sampleRate: sampleRate,
            rampDurationFrames: UInt32(boundedFrames),
            recommendedBarrierNanoseconds: UInt64(nanosDouble)
        )
    }
}

public struct PracticeDSPPitchTransitionBackendReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let mode: PracticeDSPPitchTransitionMode
    public let fallbackReason: PracticeDSPPitchTransitionFallbackReason?
    public let fromSemitones: Double
    public let toSemitones: Double
    public let sampleRate: Double
    public let rampDurationFrames: UInt32
    public let recommendedBarrierNanoseconds: UInt64
    public let parityPromotionAllowed: Bool

    public init(
        mode: PracticeDSPPitchTransitionMode,
        fallbackReason: PracticeDSPPitchTransitionFallbackReason?,
        fromSemitones: Double,
        toSemitones: Double,
        sampleRate: Double,
        rampDurationFrames: UInt32,
        recommendedBarrierNanoseconds: UInt64
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW25_PITCH_TRANSITION_NON_PARITY"
        self.mode = mode
        self.fallbackReason = fallbackReason
        self.fromSemitones = fromSemitones
        self.toSemitones = toSemitones
        self.sampleRate = sampleRate
        self.rampDurationFrames = rampDurationFrames
        self.recommendedBarrierNanoseconds = recommendedBarrierNanoseconds
        self.parityPromotionAllowed = false
    }

    public init(plan: PracticeDSPPitchTransitionPlan) {
        self.init(
            mode: plan.mode,
            fallbackReason: nil,
            fromSemitones: plan.fromSemitones,
            toSemitones: plan.toSemitones,
            sampleRate: plan.sampleRate,
            rampDurationFrames: plan.rampDurationFrames,
            recommendedBarrierNanoseconds: plan.recommendedBarrierNanoseconds
        )
    }

    public static func immediateFallback(
        reason: PracticeDSPPitchTransitionFallbackReason,
        fromSemitones: Double,
        toSemitones: Double,
        sampleRate: Double
    ) -> PracticeDSPPitchTransitionBackendReceipt {
        PracticeDSPPitchTransitionBackendReceipt(
            mode: .immediateFallback,
            fallbackReason: reason,
            fromSemitones: fromSemitones,
            toSemitones: toSemitones,
            sampleRate: sampleRate,
            rampDurationFrames: 0,
            recommendedBarrierNanoseconds: 0
        )
    }
}

public protocol PracticeDSPPitchTransitionBackendApplying: PracticeDSPTransactionalBackendApplying {
    func beginPitchTransition(
        tempoRatio: Double,
        fromPitchSemitones: Double,
        toPitchSemitones: Double,
        policy: PracticeDSPPitchTransitionPolicy
    ) throws -> PracticeDSPPitchTransitionBackendReceipt

    func finalizePitchTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws

    func cancelPitchTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws
}

public protocol PracticeDSPPitchTransitionSleeping: Sendable {
    func sleepIgnoringCancellation(nanoseconds: UInt64) async
}

public struct PracticeDSPSystemPitchTransitionSleeper: PracticeDSPPitchTransitionSleeping {
    public init() {}

    public func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        guard nanoseconds > 0 else { return }
        await Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: nanoseconds)
        }.value
    }
}
