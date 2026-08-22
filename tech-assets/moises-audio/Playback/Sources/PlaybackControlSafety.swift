import Foundation

public enum PlaybackGainRampError: Error, Equatable, Sendable {
    case invalidSampleRate(Double)
    case invalidRampDuration(Double)
    case invalidGain(Double)
    case duplicateStemID(StemID)
}

public struct PlaybackGainRampPolicy: Equatable, Sendable {
    /// Engineering guardrail only; final audible acceptance is a device/listening gate.
    public let rampDurationSeconds: Double

    public init(rampDurationSeconds: Double = 0.012) {
        self.rampDurationSeconds = rampDurationSeconds
    }
}

public struct PlaybackGainRampSegment: Equatable, Sendable {
    public let stemID: StemID
    public let startGain: Double
    public let endGain: Double
    public let frameCount: Int64

    public init(stemID: StemID, startGain: Double, endGain: Double, frameCount: Int64) {
        self.stemID = stemID
        self.startGain = startGain
        self.endGain = endGain
        self.frameCount = frameCount
    }

    public func gain(atFrame frame: Int64) -> Double {
        guard frameCount > 0 else { return endGain }
        if frame <= 0 { return startGain }
        if frame >= frameCount { return endGain }
        let progress = Double(frame) / Double(frameCount)
        return startGain + (endGain - startGain) * progress
    }
}

public struct PlaybackMixerTransitionPlan: Equatable, Sendable {
    public let segments: [PlaybackGainRampSegment]
    public let targetEffectiveGains: [StemID: Double]
}

public enum PlaybackControlSafety {
    public static func planGainTransition(
        from previousMixes: [PlaybackTrackMix],
        to nextMixes: [PlaybackTrackMix],
        sampleRate: Double,
        policy: PlaybackGainRampPolicy = PlaybackGainRampPolicy()
    ) throws -> PlaybackMixerTransitionPlan {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw PlaybackGainRampError.invalidSampleRate(sampleRate)
        }
        guard policy.rampDurationSeconds.isFinite,
              policy.rampDurationSeconds > 0,
              policy.rampDurationSeconds <= 0.250 else {
            throw PlaybackGainRampError.invalidRampDuration(policy.rampDurationSeconds)
        }
        try validateMixes(previousMixes)
        try validateMixes(nextMixes)

        let previous = PlaybackTimelinePlanner.effectiveGains(for: previousMixes)
        let target = PlaybackTimelinePlanner.effectiveGains(for: nextMixes)
        let allIDs = Set(previous.keys).union(target.keys)

        let frameDouble = (policy.rampDurationSeconds * sampleRate).rounded(.toNearestOrAwayFromZero)
        guard frameDouble.isFinite,
              frameDouble >= 1,
              frameDouble <= Double(Int64.max) else {
            throw PlaybackGainRampError.invalidRampDuration(policy.rampDurationSeconds)
        }
        let rampFrames = Int64(frameDouble)

        let segments = allIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }.map { id in
            PlaybackGainRampSegment(
                stemID: id,
                startGain: previous[id] ?? 0,
                endGain: target[id] ?? 0,
                frameCount: rampFrames
            )
        }
        return PlaybackMixerTransitionPlan(segments: segments, targetEffectiveGains: target)
    }

    private static func validateMixes(_ mixes: [PlaybackTrackMix]) throws {
        var seen = Set<StemID>()
        for mix in mixes {
            guard seen.insert(mix.stemID).inserted else {
                throw PlaybackGainRampError.duplicateStemID(mix.stemID)
            }
            guard mix.volume.isFinite, (0...1).contains(mix.volume) else {
                throw PlaybackGainRampError.invalidGain(mix.volume)
            }
        }
    }
}
