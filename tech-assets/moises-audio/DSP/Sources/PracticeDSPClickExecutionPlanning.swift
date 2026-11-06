import Foundation

public enum PracticeDSPClickExecutionPlanningError: Error, Equatable, Sendable {
    case metronomeDisabled
    case noPendingCountIn
}

public struct PracticeDSPMetronomeExecutionPlan: Equatable, Sendable {
    public let events: [DSPClickEvent]
    public let executionBatch: DSPClickExecutionBatch

    public init(
        events: [DSPClickEvent],
        executionBatch: DSPClickExecutionBatch
    ) {
        self.events = events
        self.executionBatch = executionBatch
    }
}

/// Bridges the production PracticeDSP state to sample-time click plans without owning Playback.
/// Tempo and every transport discontinuity that changes `scheduleGeneration` therefore produce a
/// distinct generation that the Apple click executor can use to flush queued stale clicks.
public enum PracticeDSPClickExecutionPlanner {
    public static func metronome(
        state: PracticeDSPState,
        beatTimesSeconds: [Double],
        sourceStartSeconds: Double,
        sourceEndSeconds: Double?,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        downbeatStride: Int = 4
    ) throws -> PracticeDSPMetronomeExecutionPlan {
        guard state.metronomeEnabled else {
            throw PracticeDSPClickExecutionPlanningError.metronomeDisabled
        }
        let events = try SampleTimelinePlanner.planClicks(
            beatTimesSeconds: beatTimesSeconds,
            sourceStartSeconds: sourceStartSeconds,
            renderStartSampleTime: renderOriginSampleTime,
            tempoRatio: state.tempoRatio,
            sampleRate: sampleRate,
            generation: state.scheduleGeneration,
            downbeatStride: downbeatStride,
            sourceEndSeconds: sourceEndSeconds
        )
        let executionBatch = try DSPClickExecutionPlanner.preflight(
            events: events,
            activeGeneration: state.scheduleGeneration,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            kind: .metronome
        )
        return PracticeDSPMetronomeExecutionPlan(
            events: events,
            executionBatch: executionBatch
        )
    }

    public static func countIn(
        state: PracticeDSPState,
        sourceBeatIntervalSeconds: Double,
        musicStartSampleTime: Int64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        downbeatStride: Int = 4
    ) throws -> DSPCountInPlan {
        guard let clicks = state.pendingCountInClicks else {
            throw PracticeDSPClickExecutionPlanningError.noPendingCountIn
        }
        let plan = try SampleTimelinePlanner.planCountIn(
            clicks: clicks,
            sourceBeatIntervalSeconds: sourceBeatIntervalSeconds,
            musicStartSampleTime: musicStartSampleTime,
            tempoRatio: state.tempoRatio,
            sampleRate: sampleRate,
            generation: state.scheduleGeneration,
            downbeatStride: downbeatStride
        )
        _ = try DSPClickExecutionPlanner.preflight(
            events: plan.clicks,
            activeGeneration: state.scheduleGeneration,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            kind: .countIn(musicStartSampleTime: musicStartSampleTime)
        )
        return plan
    }
}
