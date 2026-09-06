import Foundation

public enum PlaybackGainRampExecutionError: Error, Equatable, Sendable {
    case invalidRampDuration(Double)
    case unknownStem(StemID)
    case invalidGain(StemID, Double)
    case invalidSampleRate(StemID, Double)
    case frameCountOverflow(StemID)
}

public struct PlaybackGainRampExecutionStep: Equatable, Sendable {
    public let stemID: StemID
    public let expectedStartGain: Double
    public let targetGain: Double
    public let sampleRate: Double
    public let frameCount: Int64

    public init(
        stemID: StemID,
        expectedStartGain: Double,
        targetGain: Double,
        sampleRate: Double,
        frameCount: Int64
    ) {
        self.stemID = stemID
        self.expectedStartGain = expectedStartGain
        self.targetGain = targetGain
        self.sampleRate = sampleRate
        self.frameCount = frameCount
    }
}

public struct PlaybackGainRampExecutionPlan: Equatable, Sendable {
    public let steps: [PlaybackGainRampExecutionStep]
    public let committedTargetGains: [StemID: Double]

    public init(
        steps: [PlaybackGainRampExecutionStep],
        committedTargetGains: [StemID: Double]
    ) {
        self.steps = steps
        self.committedTargetGains = committedTargetGains
    }
}

/// Creates a complete, fail-closed batch before any Apple AudioUnit ramp is scheduled.
///
/// `expectedStartGain` is evidence/debug metadata. A render-side AudioUnit ramp must start from
/// the parameter's actual current render value so rapid retargeting during an in-flight ramp does
/// not introduce a discontinuity by forcing the old target value immediately.
public enum PlaybackGainRampExecutionPlanner {
    public static func plan(
        currentGains: [StemID: Double],
        targetGains: [StemID: Double],
        renderSampleRates: [StemID: Double],
        policy: PlaybackGainRampPolicy = PlaybackGainRampPolicy()
    ) throws -> PlaybackGainRampExecutionPlan {
        guard policy.rampDurationSeconds.isFinite,
              policy.rampDurationSeconds > 0,
              policy.rampDurationSeconds <= 0.250 else {
            throw PlaybackGainRampExecutionError.invalidRampDuration(
                policy.rampDurationSeconds
            )
        }

        let knownIDs = Set(renderSampleRates.keys)
        for id in currentGains.keys where !knownIDs.contains(id) {
            throw PlaybackGainRampExecutionError.unknownStem(id)
        }
        for id in targetGains.keys where !knownIDs.contains(id) {
            throw PlaybackGainRampExecutionError.unknownStem(id)
        }

        var committed: [StemID: Double] = [:]
        committed.reserveCapacity(knownIDs.count)
        var steps: [PlaybackGainRampExecutionStep] = []
        steps.reserveCapacity(knownIDs.count)

        for id in knownIDs.sorted(by: { $0.rawValue.uuidString < $1.rawValue.uuidString }) {
            let start = currentGains[id] ?? 1
            let target = targetGains[id] ?? start
            try validateGain(start, stemID: id)
            try validateGain(target, stemID: id)

            guard let sampleRate = renderSampleRates[id],
                  sampleRate.isFinite,
                  sampleRate > 0 else {
                throw PlaybackGainRampExecutionError.invalidSampleRate(
                    id,
                    renderSampleRates[id] ?? .nan
                )
            }

            let frameDouble = (
                policy.rampDurationSeconds * sampleRate
            ).rounded(.toNearestOrAwayFromZero)
            guard frameDouble.isFinite,
                  frameDouble >= 1,
                  frameDouble <= Double(Int64.max) else {
                throw PlaybackGainRampExecutionError.frameCountOverflow(id)
            }
            let frameCount = Int64(frameDouble)
            committed[id] = target

            if abs(start - target) > 1e-12 {
                steps.append(
                    PlaybackGainRampExecutionStep(
                        stemID: id,
                        expectedStartGain: start,
                        targetGain: target,
                        sampleRate: sampleRate,
                        frameCount: frameCount
                    )
                )
            }
        }

        return PlaybackGainRampExecutionPlan(
            steps: steps,
            committedTargetGains: committed
        )
    }

    private static func validateGain(
        _ gain: Double,
        stemID: StemID
    ) throws {
        guard gain.isFinite, (0...1).contains(gain) else {
            throw PlaybackGainRampExecutionError.invalidGain(stemID, gain)
        }
    }
}
