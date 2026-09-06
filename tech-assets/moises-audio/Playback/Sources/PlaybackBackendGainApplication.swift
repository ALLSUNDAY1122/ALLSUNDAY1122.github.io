import Foundation

public enum PlaybackBackendGainApplicationError: Error, Equatable, Sendable {
    case duplicateLoadedStem(StemID)
    case unknownRequestedStem(StemID)
    case missingRenderSampleRate(StemID)
}

public enum PlaybackBackendGainApplicationMode: String, Equatable, Sendable {
    case immediate
    case ramped
}

public struct PlaybackBackendGainApplicationPlan: Equatable, Sendable {
    public let mode: PlaybackBackendGainApplicationMode
    public let execution: PlaybackGainRampExecutionPlan
    public let normalizedTargetGains: [StemID: Double]

    public init(
        mode: PlaybackBackendGainApplicationMode,
        execution: PlaybackGainRampExecutionPlan,
        normalizedTargetGains: [StemID: Double]
    ) {
        self.mode = mode
        self.execution = execution
        self.normalizedTargetGains = normalizedTargetGains
    }
}

/// Normalizes the backend's complete loaded-stem gain map before touching the Apple graph.
/// Missing requested values preserve the historical backend behavior of unity gain, while stale
/// committed values from a previous stem set are ignored instead of contaminating the new graph.
public enum PlaybackBackendGainApplicationPlanner {
    public static func plan(
        loadedStemIDs: [StemID],
        committedGains: [StemID: Double],
        requestedGains: [StemID: Double],
        renderSampleRates: [StemID: Double],
        isPlaying: Bool,
        policy: PlaybackGainRampPolicy = PlaybackGainRampPolicy()
    ) throws -> PlaybackBackendGainApplicationPlan {
        var loaded = Set<StemID>()
        for id in loadedStemIDs {
            guard loaded.insert(id).inserted else {
                throw PlaybackBackendGainApplicationError.duplicateLoadedStem(id)
            }
        }
        for id in requestedGains.keys where !loaded.contains(id) {
            throw PlaybackBackendGainApplicationError.unknownRequestedStem(id)
        }

        var current: [StemID: Double] = [:]
        var target: [StemID: Double] = [:]
        var rates: [StemID: Double] = [:]
        current.reserveCapacity(loaded.count)
        target.reserveCapacity(loaded.count)
        rates.reserveCapacity(loaded.count)

        for id in loaded {
            guard let rate = renderSampleRates[id] else {
                throw PlaybackBackendGainApplicationError.missingRenderSampleRate(id)
            }
            current[id] = committedGains[id] ?? 1
            target[id] = requestedGains[id] ?? 1
            rates[id] = rate
        }

        let execution = try PlaybackGainRampExecutionPlanner.plan(
            currentGains: current,
            targetGains: target,
            renderSampleRates: rates,
            policy: policy
        )
        return PlaybackBackendGainApplicationPlan(
            mode: isPlaying ? .ramped : .immediate,
            execution: execution,
            normalizedTargetGains: target
        )
    }
}
