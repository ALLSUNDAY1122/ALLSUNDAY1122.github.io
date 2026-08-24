import Foundation

public enum PlaybackBoundaryEnvelopeError: Error, Equatable, Sendable {
    case invalidFadeOutDuration(Double)
    case invalidFadeInDuration(Double)
    case invalidSampleRate(Double)
    case invalidStartLead(Double)
    case invalidBoundaryDelay(Double)
    case frameCountOverflow
    case durationOverflow
}

public struct PlaybackBoundaryEnvelopePolicy: Equatable, Sendable {
    public let fadeOutSeconds: Double
    public let fadeInSeconds: Double
    public let maximumPendingLoopEnvelopes: Int

    public init(
        fadeOutSeconds: Double = 0.008,
        fadeInSeconds: Double = 0.008,
        maximumPendingLoopEnvelopes: Int = 8
    ) {
        self.fadeOutSeconds = fadeOutSeconds
        self.fadeInSeconds = fadeInSeconds
        self.maximumPendingLoopEnvelopes = maximumPendingLoopEnvelopes
    }

    public static let provisionalAppleInteractive = PlaybackBoundaryEnvelopePolicy()
}

public struct PlaybackBoundaryEnvelopePlan: Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sampleRate: Double
    public let fadeOutSeconds: Double
    public let fadeInSeconds: Double
    public let fadeOutFrames: Int64
    public let fadeInFrames: Int64
    public let startLeadSeconds: Double
    public let minimumRestartMutedLeadSeconds: Double
    public let parityPromotionAllowed: Bool

    public init(
        sampleRate: Double,
        fadeOutSeconds: Double,
        fadeInSeconds: Double,
        fadeOutFrames: Int64,
        fadeInFrames: Int64,
        startLeadSeconds: Double
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW32_BOUNDARY_ENVELOPE_NON_PARITY"
        self.sampleRate = sampleRate
        self.fadeOutSeconds = fadeOutSeconds
        self.fadeInSeconds = fadeInSeconds
        self.fadeOutFrames = fadeOutFrames
        self.fadeInFrames = fadeInFrames
        self.startLeadSeconds = startLeadSeconds
        self.minimumRestartMutedLeadSeconds = startLeadSeconds
        self.parityPromotionAllowed = false
    }
}

public struct PlaybackLoopBoundaryEnvelopePlan: Equatable, Sendable {
    public let boundaryDelaySeconds: Double
    public let delayBeforeFadeOutSeconds: Double
    public let fadeOutFrames: Int64
    public let fadeInFrames: Int64
    public let lateArming: Bool
    public let overlapRisk: Bool

    public init(
        boundaryDelaySeconds: Double,
        delayBeforeFadeOutSeconds: Double,
        fadeOutFrames: Int64,
        fadeInFrames: Int64,
        lateArming: Bool,
        overlapRisk: Bool
    ) {
        self.boundaryDelaySeconds = boundaryDelaySeconds
        self.delayBeforeFadeOutSeconds = delayBeforeFadeOutSeconds
        self.fadeOutFrames = fadeOutFrames
        self.fadeInFrames = fadeInFrames
        self.lateArming = lateArming
        self.overlapRisk = overlapRisk
    }
}

public enum PlaybackBoundaryEnvelopePlanner {
    public static func makePlan(
        sampleRate: Double,
        startLeadSeconds: Double,
        policy: PlaybackBoundaryEnvelopePolicy = .provisionalAppleInteractive
    ) throws -> PlaybackBoundaryEnvelopePlan {
        try validate(policy: policy)
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw PlaybackBoundaryEnvelopeError.invalidSampleRate(sampleRate)
        }
        guard startLeadSeconds.isFinite, startLeadSeconds >= 0, startLeadSeconds <= 1 else {
            throw PlaybackBoundaryEnvelopeError.invalidStartLead(startLeadSeconds)
        }
        return PlaybackBoundaryEnvelopePlan(
            sampleRate: sampleRate,
            fadeOutSeconds: policy.fadeOutSeconds,
            fadeInSeconds: policy.fadeInSeconds,
            fadeOutFrames: try frameCount(seconds: policy.fadeOutSeconds, sampleRate: sampleRate),
            fadeInFrames: try frameCount(seconds: policy.fadeInSeconds, sampleRate: sampleRate),
            startLeadSeconds: startLeadSeconds
        )
    }

    public static func makeLoopPlan(
        boundaryDelaySeconds: Double,
        sampleRate: Double,
        policy: PlaybackBoundaryEnvelopePolicy = .provisionalAppleInteractive
    ) throws -> PlaybackLoopBoundaryEnvelopePlan {
        try validate(policy: policy)
        guard boundaryDelaySeconds.isFinite, boundaryDelaySeconds >= 0 else {
            throw PlaybackBoundaryEnvelopeError.invalidBoundaryDelay(boundaryDelaySeconds)
        }
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw PlaybackBoundaryEnvelopeError.invalidSampleRate(sampleRate)
        }
        let delay = max(0, boundaryDelaySeconds - policy.fadeOutSeconds)
        return PlaybackLoopBoundaryEnvelopePlan(
            boundaryDelaySeconds: boundaryDelaySeconds,
            delayBeforeFadeOutSeconds: delay,
            fadeOutFrames: try frameCount(seconds: policy.fadeOutSeconds, sampleRate: sampleRate),
            fadeInFrames: try frameCount(seconds: policy.fadeInSeconds, sampleRate: sampleRate),
            lateArming: boundaryDelaySeconds < policy.fadeOutSeconds,
            overlapRisk: boundaryDelaySeconds <= policy.fadeOutSeconds + policy.fadeInSeconds
        )
    }

    public static func nanoseconds(for seconds: Double) throws -> UInt64 {
        guard seconds.isFinite, seconds >= 0 else {
            throw PlaybackBoundaryEnvelopeError.invalidBoundaryDelay(seconds)
        }
        let value = (seconds * 1_000_000_000).rounded(.toNearestOrAwayFromZero)
        guard value.isFinite, value >= 0, value <= Double(UInt64.max) else {
            throw PlaybackBoundaryEnvelopeError.durationOverflow
        }
        return UInt64(value)
    }

    private static func validate(policy: PlaybackBoundaryEnvelopePolicy) throws {
        guard policy.fadeOutSeconds.isFinite,
              policy.fadeOutSeconds > 0,
              policy.fadeOutSeconds <= 0.050 else {
            throw PlaybackBoundaryEnvelopeError.invalidFadeOutDuration(policy.fadeOutSeconds)
        }
        guard policy.fadeInSeconds.isFinite,
              policy.fadeInSeconds > 0,
              policy.fadeInSeconds <= 0.050 else {
            throw PlaybackBoundaryEnvelopeError.invalidFadeInDuration(policy.fadeInSeconds)
        }
        guard policy.maximumPendingLoopEnvelopes >= 1,
              policy.maximumPendingLoopEnvelopes <= 64 else {
            throw PlaybackBoundaryEnvelopeError.durationOverflow
        }
    }

    private static func frameCount(seconds: Double, sampleRate: Double) throws -> Int64 {
        let value = (seconds * sampleRate).rounded(.toNearestOrAwayFromZero)
        guard value.isFinite, value >= 1, value <= Double(UInt32.max) else {
            throw PlaybackBoundaryEnvelopeError.frameCountOverflow
        }
        return Int64(value)
    }
}

public protocol PlaybackBoundaryEnvelopeSleeping: Sendable {
    func sleep(seconds: Double) async
}

public struct PlaybackBoundaryEnvelopeSystemSleeper: PlaybackBoundaryEnvelopeSleeping {
    public init() {}

    public func sleep(seconds: Double) async {
        guard let nanoseconds = try? PlaybackBoundaryEnvelopePlanner.nanoseconds(for: seconds) else {
            return
        }
        let duration = Duration.nanoseconds(Int64(min(nanoseconds, UInt64(Int64.max))))
        await Task.detached(priority: .userInitiated) {
            try? await Task.sleep(for: duration)
        }.value
    }
}

public struct PlaybackBoundaryEnvelopeRuntimeSnapshot: Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let fadeOutScheduled: UInt64
    public let restartFadeInArmed: UInt64
    public let restartFadeInApplied: UInt64
    public let loopEnvelopeArmed: UInt64
    public let loopFadeOutApplied: UInt64
    public let loopFadeInApplied: UInt64
    public let staleOrCancelledEnvelopeTasksRejected: UInt64
    public let loopEnvelopeCapacityDrops: UInt64
    public let loopEnvelopeUnsafeDurationDrops: UInt64
    public let counterOverflowed: Bool
    public let pendingLoopEnvelopeTasks: Int
    public let restartFadeInPending: Bool
    public let parityPromotionAllowed: Bool

    public init(
        fadeOutScheduled: UInt64,
        restartFadeInArmed: UInt64,
        restartFadeInApplied: UInt64,
        loopEnvelopeArmed: UInt64,
        loopFadeOutApplied: UInt64,
        loopFadeInApplied: UInt64,
        staleOrCancelledEnvelopeTasksRejected: UInt64,
        loopEnvelopeCapacityDrops: UInt64,
        loopEnvelopeUnsafeDurationDrops: UInt64,
        counterOverflowed: Bool,
        pendingLoopEnvelopeTasks: Int,
        restartFadeInPending: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW32_BOUNDARY_ENVELOPE_RUNTIME_NON_PARITY"
        self.fadeOutScheduled = fadeOutScheduled
        self.restartFadeInArmed = restartFadeInArmed
        self.restartFadeInApplied = restartFadeInApplied
        self.loopEnvelopeArmed = loopEnvelopeArmed
        self.loopFadeOutApplied = loopFadeOutApplied
        self.loopFadeInApplied = loopFadeInApplied
        self.staleOrCancelledEnvelopeTasksRejected = staleOrCancelledEnvelopeTasksRejected
        self.loopEnvelopeCapacityDrops = loopEnvelopeCapacityDrops
        self.loopEnvelopeUnsafeDurationDrops = loopEnvelopeUnsafeDurationDrops
        self.counterOverflowed = counterOverflowed
        self.pendingLoopEnvelopeTasks = pendingLoopEnvelopeTasks
        self.restartFadeInPending = restartFadeInPending
        self.parityPromotionAllowed = false
    }
}
