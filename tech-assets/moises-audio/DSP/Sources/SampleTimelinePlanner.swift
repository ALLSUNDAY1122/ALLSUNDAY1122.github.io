import Foundation

public struct DSPClickEvent: Equatable, Sendable {
    public let sampleTime: Int64
    public let beatIndex: Int
    public let accent: Bool
    public let generation: UInt64

    public init(sampleTime: Int64, beatIndex: Int, accent: Bool, generation: UInt64) {
        self.sampleTime = sampleTime
        self.beatIndex = beatIndex
        self.accent = accent
        self.generation = generation
    }
}

public struct DSPCountInPlan: Equatable, Sendable {
    public let clicks: [DSPClickEvent]
    public let musicStartSampleTime: Int64
    public let generation: UInt64
}

public enum DSPTimelinePlanningError: Error, Equatable, Sendable {
    case invalidSampleRate(Double)
    case invalidTempoRatio(Double)
    case invalidSourceOrigin(Double)
    case invalidBeatTime(Double)
    case invalidBeatInterval(Double)
    case invalidCountInClicks(Int)
    case insufficientPreroll
}

/// Pure sample-time planner. It never owns a transport and never uses wall-clock/UI timers.
/// Playback provides the authoritative render origin; Analysis provides source beat positions.
public enum SampleTimelinePlanner {
    public static func mapSourceTimeToRenderSample(
        sourceTimeSeconds: Double,
        sourceOriginSeconds: Double,
        renderOriginSampleTime: Int64,
        tempoRatio: Double,
        sampleRate: Double
    ) throws -> Int64 {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw DSPTimelinePlanningError.invalidSampleRate(sampleRate)
        }
        guard tempoRatio.isFinite, tempoRatio > 0 else {
            throw DSPTimelinePlanningError.invalidTempoRatio(tempoRatio)
        }
        guard sourceOriginSeconds.isFinite else {
            throw DSPTimelinePlanningError.invalidSourceOrigin(sourceOriginSeconds)
        }
        guard sourceTimeSeconds.isFinite else {
            throw DSPTimelinePlanningError.invalidBeatTime(sourceTimeSeconds)
        }

        let sourceDelta = sourceTimeSeconds - sourceOriginSeconds
        let renderDeltaSeconds = sourceDelta / tempoRatio
        let renderDeltaFrames = (renderDeltaSeconds * sampleRate).rounded()
        guard renderDeltaFrames <= Double(Int64.max), renderDeltaFrames >= Double(Int64.min) else {
            throw DSPTimelinePlanningError.invalidBeatTime(sourceTimeSeconds)
        }
        return renderOriginSampleTime + Int64(renderDeltaFrames)
    }

    public static func planClicks(
        beatTimesSeconds: [Double],
        sourceStartSeconds: Double,
        renderStartSampleTime: Int64,
        tempoRatio: Double,
        sampleRate: Double,
        generation: UInt64,
        downbeatStride: Int = 4,
        sourceEndSeconds: Double? = nil
    ) throws -> [DSPClickEvent] {
        guard downbeatStride > 0 else { return [] }
        var result: [DSPClickEvent] = []
        result.reserveCapacity(beatTimesSeconds.count)

        var previousSourceBeat = -Double.infinity
        for (index, beatTime) in beatTimesSeconds.enumerated() {
            guard beatTime.isFinite, beatTime >= previousSourceBeat else {
                throw DSPTimelinePlanningError.invalidBeatTime(beatTime)
            }
            previousSourceBeat = beatTime
            guard beatTime >= sourceStartSeconds else { continue }
            if let sourceEndSeconds, beatTime > sourceEndSeconds { break }
            let sample = try mapSourceTimeToRenderSample(
                sourceTimeSeconds: beatTime,
                sourceOriginSeconds: sourceStartSeconds,
                renderOriginSampleTime: renderStartSampleTime,
                tempoRatio: tempoRatio,
                sampleRate: sampleRate
            )
            result.append(DSPClickEvent(
                sampleTime: sample,
                beatIndex: index,
                accent: index % downbeatStride == 0,
                generation: generation
            ))
        }
        return result
    }

    /// Plans N pre-roll clicks immediately before a music start on the same sample timeline.
    /// `sourceBeatIntervalSeconds` is supplied from the verified Analysis beat grid/tempo map.
    public static func planCountIn(
        clicks: Int,
        sourceBeatIntervalSeconds: Double,
        musicStartSampleTime: Int64,
        tempoRatio: Double,
        sampleRate: Double,
        generation: UInt64,
        downbeatStride: Int = 4
    ) throws -> DSPCountInPlan {
        guard clicks > 0 else { throw DSPTimelinePlanningError.invalidCountInClicks(clicks) }
        guard sourceBeatIntervalSeconds.isFinite, sourceBeatIntervalSeconds > 0 else {
            throw DSPTimelinePlanningError.invalidBeatInterval(sourceBeatIntervalSeconds)
        }
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw DSPTimelinePlanningError.invalidSampleRate(sampleRate)
        }
        guard tempoRatio.isFinite, tempoRatio > 0 else {
            throw DSPTimelinePlanningError.invalidTempoRatio(tempoRatio)
        }

        let renderBeatFrames = (sourceBeatIntervalSeconds / tempoRatio * sampleRate).rounded()
        guard renderBeatFrames >= 1, renderBeatFrames <= Double(Int64.max) else {
            throw DSPTimelinePlanningError.invalidBeatInterval(sourceBeatIntervalSeconds)
        }
        let beatFrames = Int64(renderBeatFrames)
        let firstClick = musicStartSampleTime - beatFrames * Int64(clicks)
        guard firstClick >= 0 else { throw DSPTimelinePlanningError.insufficientPreroll }

        let events = (0..<clicks).map { index in
            DSPClickEvent(
                sampleTime: firstClick + Int64(index) * beatFrames,
                beatIndex: index,
                accent: downbeatStride > 0 && index % downbeatStride == 0,
                generation: generation
            )
        }
        return DSPCountInPlan(clicks: events, musicStartSampleTime: musicStartSampleTime, generation: generation)
    }
}
