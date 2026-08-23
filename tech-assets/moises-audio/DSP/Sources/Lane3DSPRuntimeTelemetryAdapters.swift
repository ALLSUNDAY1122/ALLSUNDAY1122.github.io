import Foundation

/// Measures actual synchronous time/pitch backend entry and execution under the TaskLocal trace
/// established by `Lane3DSPRuntimeTelemetryProbe`. Snapshot reads are intentionally not timed as DSP
/// mutations because transaction gates can perform several of them around one apply.
public final class Lane3DSPTelemetryTransactionalBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let backend: any PracticeDSPTransactionalBackendApplying
    private let collector: Lane3DSPRuntimeTelemetryCollector
    private let timeSource: any Lane3DSPRuntimeTelemetryTimeSource

    public init(
        backend: any PracticeDSPTransactionalBackendApplying,
        collector: Lane3DSPRuntimeTelemetryCollector,
        timeSource: any Lane3DSPRuntimeTelemetryTimeSource = Lane3DSPSystemTelemetryTimeSource()
    ) {
        self.backend = backend
        self.collector = collector
        self.timeSource = timeSource
    }

    public func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        let entry = timeSource.nowNanoseconds()
        let trace = Lane3DSPRuntimeTelemetryTaskContext.trace
        collector.recordBackendEntry(trace: trace, at: entry)
        defer {
            collector.recordBackendCompletion(
                trace: trace,
                durationNanoseconds: Self.elapsed(from: entry, to: timeSource.nowNanoseconds())
            )
        }
        try backend.apply(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    public func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        try backend.snapshotAppliedDSP()
    }

    private static func elapsed(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }
}

/// Measures the real click-queue invalidation point used by transport/tempo/metronome/count-in
/// authority. Multiple invalidations inside one measured operation remain visible as additional
/// calls, while submission-to-entry latency is recorded only for the first invalidation.
public final class Lane3DSPTelemetryClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let invalidator: any PracticeDSPClickScheduleInvalidating
    private let collector: Lane3DSPRuntimeTelemetryCollector
    private let timeSource: any Lane3DSPRuntimeTelemetryTimeSource

    public init(
        invalidator: any PracticeDSPClickScheduleInvalidating,
        collector: Lane3DSPRuntimeTelemetryCollector,
        timeSource: any Lane3DSPRuntimeTelemetryTimeSource = Lane3DSPSystemTelemetryTimeSource()
    ) {
        self.invalidator = invalidator
        self.collector = collector
        self.timeSource = timeSource
    }

    public func invalidateSchedule(to generation: UInt64) throws {
        let entry = timeSource.nowNanoseconds()
        let trace = Lane3DSPRuntimeTelemetryTaskContext.trace
        collector.recordClickInvalidationEntry(trace: trace, at: entry)
        defer {
            collector.recordClickInvalidationCompletion(
                trace: trace,
                durationNanoseconds: Self.elapsed(from: entry, to: timeSource.nowNanoseconds())
            )
        }
        try invalidator.invalidateSchedule(to: generation)
    }

    private static func elapsed(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }
}

#if canImport(AVFAudio)
import AVFAudio

/// Selected-device wrapper for timing the actual Apple click-node replacement/append call. The
/// probe exports aggregate latency only; click samples, buffers, host time, generations and anchors
/// are not copied into telemetry.
public final class Lane3DSPTelemetryAppleClickExecutor: @unchecked Sendable {
    private let executor: AppleSampleAccurateClickExecutor
    private let probe: Lane3DSPRuntimeTelemetryProbe

    public init(
        executor: AppleSampleAccurateClickExecutor,
        probe: Lane3DSPRuntimeTelemetryProbe
    ) {
        self.executor = executor
        self.probe = probe
    }

    public func replaceSchedule(
        events: [DSPClickEvent],
        kind: DSPClickBatchKind,
        generation: UInt64,
        renderOriginSampleTime: Int64,
        commonHostTime: UInt64,
        sampleRate: Double,
        normalClick: AVAudioPCMBuffer,
        accentClick: AVAudioPCMBuffer
    ) throws {
        let telemetryKind: Lane3DSPRuntimeOperationKind
        switch kind {
        case .metronome:
            telemetryKind = .metronomeReplaceSchedule
        case .countIn:
            telemetryKind = .countInReplaceSchedule
        }
        try probe.measureSync(kind: telemetryKind) {
            try executor.replaceSchedule(
                events: events,
                kind: kind,
                generation: generation,
                renderOriginSampleTime: renderOriginSampleTime,
                commonHostTime: commonHostTime,
                sampleRate: sampleRate,
                normalClick: normalClick,
                accentClick: accentClick
            )
        }
    }

    public func appendMetronomeSchedule(
        events: [DSPClickEvent],
        generation: UInt64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        normalClick: AVAudioPCMBuffer,
        accentClick: AVAudioPCMBuffer
    ) throws {
        try probe.measureSync(kind: .metronomeAppendSchedule) {
            try executor.appendSchedule(
                events: events,
                kind: .metronome,
                generation: generation,
                renderOriginSampleTime: renderOriginSampleTime,
                sampleRate: sampleRate,
                normalClick: normalClick,
                accentClick: accentClick
            )
        }
    }

    public func invalidateSchedule(to generation: UInt64) throws {
        try executor.invalidateSchedule(to: generation)
    }

    public func stateSnapshot() -> DSPClickExecutionState {
        executor.stateSnapshot()
    }
}
#endif
