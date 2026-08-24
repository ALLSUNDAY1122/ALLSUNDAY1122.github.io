import Foundation

public enum PracticeDSPTempoTransitionMode: String, Codable, Sendable {
    case immediate
    case scheduledRamp
    case immediateFallback
}

public enum PracticeDSPTempoTransitionFallbackReason: String, Codable, Sendable {
    case renderResourcesUnavailable
    case sampleRateUnavailable
    case rateParameterUnavailable
    case rateParameterNotRampable
    case backendTransitionUnsupported
}

/// Provisional, device-tunable policy for smoothing interactive tempo/rate changes.
/// Thresholds are intentionally framed as transition mechanics, not audible-quality claims.
public struct PracticeDSPTempoTransitionPolicy: Equatable, Codable, Sendable {
    public let immediateLogRatioThreshold: Double
    public let minimumRampSeconds: Double
    public let secondsPerNaturalLogRatio: Double
    public let maximumRampSeconds: Double
    public let settleSeconds: Double
    public let maximumRampFrames: UInt32

    public init(
        immediateLogRatioThreshold: Double = 0.01,
        minimumRampSeconds: Double = 0.008,
        secondsPerNaturalLogRatio: Double = 0.040,
        maximumRampSeconds: Double = 0.040,
        settleSeconds: Double = 0.004,
        maximumRampFrames: UInt32 = 4_096
    ) {
        self.immediateLogRatioThreshold = immediateLogRatioThreshold
        self.minimumRampSeconds = minimumRampSeconds
        self.secondsPerNaturalLogRatio = secondsPerNaturalLogRatio
        self.maximumRampSeconds = maximumRampSeconds
        self.settleSeconds = settleSeconds
        self.maximumRampFrames = maximumRampFrames
    }

    public static let provisionalAppleInteractive = PracticeDSPTempoTransitionPolicy()
}

public struct PracticeDSPTempoTransitionPlan: Equatable, Codable, Sendable {
    public let mode: PracticeDSPTempoTransitionMode
    public let fromRatio: Double
    public let toRatio: Double
    public let sampleRate: Double
    public let rampDurationFrames: UInt32
    public let recommendedBarrierNanoseconds: UInt64

    public init(
        mode: PracticeDSPTempoTransitionMode,
        fromRatio: Double,
        toRatio: Double,
        sampleRate: Double,
        rampDurationFrames: UInt32,
        recommendedBarrierNanoseconds: UInt64
    ) {
        self.mode = mode
        self.fromRatio = fromRatio
        self.toRatio = toRatio
        self.sampleRate = sampleRate
        self.rampDurationFrames = rampDurationFrames
        self.recommendedBarrierNanoseconds = recommendedBarrierNanoseconds
    }
}

public enum PracticeDSPTempoTransitionPlanningError: Error, Equatable, Sendable {
    case invalidTempoRatio(Double)
    case invalidSampleRate(Double)
    case invalidPolicy
    case durationOverflow
}

public enum PracticeDSPTempoTransitionPlanner {
    public static func makePlan(
        fromRatio: Double,
        toRatio: Double,
        sampleRate: Double,
        policy: PracticeDSPTempoTransitionPolicy = .provisionalAppleInteractive
    ) throws -> PracticeDSPTempoTransitionPlan {
        guard fromRatio.isFinite, fromRatio > 0 else {
            throw PracticeDSPTempoTransitionPlanningError.invalidTempoRatio(fromRatio)
        }
        guard toRatio.isFinite, toRatio > 0 else {
            throw PracticeDSPTempoTransitionPlanningError.invalidTempoRatio(toRatio)
        }
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 768_000 else {
            throw PracticeDSPTempoTransitionPlanningError.invalidSampleRate(sampleRate)
        }
        guard policy.immediateLogRatioThreshold.isFinite,
              policy.immediateLogRatioThreshold >= 0,
              policy.minimumRampSeconds.isFinite,
              policy.minimumRampSeconds > 0,
              policy.secondsPerNaturalLogRatio.isFinite,
              policy.secondsPerNaturalLogRatio >= 0,
              policy.maximumRampSeconds.isFinite,
              policy.maximumRampSeconds >= policy.minimumRampSeconds,
              policy.settleSeconds.isFinite,
              policy.settleSeconds >= 0,
              policy.maximumRampFrames > 0 else {
            throw PracticeDSPTempoTransitionPlanningError.invalidPolicy
        }

        let logDelta = abs(log(toRatio / fromRatio))
        guard logDelta.isFinite else {
            throw PracticeDSPTempoTransitionPlanningError.durationOverflow
        }
        if logDelta <= policy.immediateLogRatioThreshold {
            return PracticeDSPTempoTransitionPlan(
                mode: .immediate,
                fromRatio: fromRatio,
                toRatio: toRatio,
                sampleRate: sampleRate,
                rampDurationFrames: 0,
                recommendedBarrierNanoseconds: 0
            )
        }

        let proposedSeconds = max(
            policy.minimumRampSeconds,
            min(policy.maximumRampSeconds, logDelta * policy.secondsPerNaturalLogRatio)
        )
        let frameDouble = (proposedSeconds * sampleRate).rounded(.toNearestOrAwayFromZero)
        guard frameDouble.isFinite, frameDouble >= 1, frameDouble <= Double(UInt64.max) else {
            throw PracticeDSPTempoTransitionPlanningError.durationOverflow
        }
        let boundedFrames = min(UInt64(policy.maximumRampFrames), UInt64(frameDouble))
        guard boundedFrames > 0, boundedFrames <= UInt64(UInt32.max) else {
            throw PracticeDSPTempoTransitionPlanningError.durationOverflow
        }
        let actualRampSeconds = Double(boundedFrames) / sampleRate
        let barrierSeconds = actualRampSeconds + policy.settleSeconds
        let nanosDouble = (barrierSeconds * 1_000_000_000).rounded(.up)
        guard nanosDouble.isFinite, nanosDouble >= 0, nanosDouble <= Double(UInt64.max) else {
            throw PracticeDSPTempoTransitionPlanningError.durationOverflow
        }
        return PracticeDSPTempoTransitionPlan(
            mode: .scheduledRamp,
            fromRatio: fromRatio,
            toRatio: toRatio,
            sampleRate: sampleRate,
            rampDurationFrames: UInt32(boundedFrames),
            recommendedBarrierNanoseconds: UInt64(nanosDouble)
        )
    }
}

public struct PracticeDSPTempoTransitionBackendReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let mode: PracticeDSPTempoTransitionMode
    public let fallbackReason: PracticeDSPTempoTransitionFallbackReason?
    public let fromRatio: Double
    public let toRatio: Double
    public let sampleRate: Double
    public let rampDurationFrames: UInt32
    public let recommendedBarrierNanoseconds: UInt64
    public let parityPromotionAllowed: Bool

    public init(
        mode: PracticeDSPTempoTransitionMode,
        fallbackReason: PracticeDSPTempoTransitionFallbackReason?,
        fromRatio: Double,
        toRatio: Double,
        sampleRate: Double,
        rampDurationFrames: UInt32,
        recommendedBarrierNanoseconds: UInt64
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW28_TEMPO_TRANSITION_NON_PARITY"
        self.mode = mode
        self.fallbackReason = fallbackReason
        self.fromRatio = fromRatio
        self.toRatio = toRatio
        self.sampleRate = sampleRate
        self.rampDurationFrames = rampDurationFrames
        self.recommendedBarrierNanoseconds = recommendedBarrierNanoseconds
        self.parityPromotionAllowed = false
    }

    public init(plan: PracticeDSPTempoTransitionPlan) {
        self.init(
            mode: plan.mode,
            fallbackReason: nil,
            fromRatio: plan.fromRatio,
            toRatio: plan.toRatio,
            sampleRate: plan.sampleRate,
            rampDurationFrames: plan.rampDurationFrames,
            recommendedBarrierNanoseconds: plan.recommendedBarrierNanoseconds
        )
    }

    public static func immediateFallback(
        reason: PracticeDSPTempoTransitionFallbackReason,
        fromRatio: Double,
        toRatio: Double,
        sampleRate: Double
    ) -> PracticeDSPTempoTransitionBackendReceipt {
        PracticeDSPTempoTransitionBackendReceipt(
            mode: .immediateFallback,
            fallbackReason: reason,
            fromRatio: fromRatio,
            toRatio: toRatio,
            sampleRate: sampleRate,
            rampDurationFrames: 0,
            recommendedBarrierNanoseconds: 0
        )
    }
}

public protocol PracticeDSPTempoTransitionBackendApplying: PracticeDSPTransactionalBackendApplying {
    func beginTempoTransition(
        fromTempoRatio: Double,
        toTempoRatio: Double,
        pitchSemitones: Double,
        policy: PracticeDSPTempoTransitionPolicy
    ) throws -> PracticeDSPTempoTransitionBackendReceipt

    func finalizeTempoTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws

    func cancelTempoTransition(
        tempoRatio: Double,
        pitchSemitones: Double
    ) throws
}

public protocol PracticeDSPTempoTransitionSleeping: Sendable {
    func sleepIgnoringCancellation(nanoseconds: UInt64) async
}

public struct PracticeDSPSystemTempoTransitionSleeper: PracticeDSPTempoTransitionSleeping {
    public init() {}

    public func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        guard nanoseconds > 0 else { return }
        await Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: nanoseconds)
        }.value
    }
}
