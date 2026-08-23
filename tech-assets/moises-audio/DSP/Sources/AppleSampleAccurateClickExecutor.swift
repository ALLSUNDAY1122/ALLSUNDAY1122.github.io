#if canImport(AVFAudio)
import AVFAudio
import Foundation

public enum AppleSampleAccurateClickExecutorError: Error, Equatable, Sendable {
    case emptyNormalClickBuffer
    case emptyAccentClickBuffer
    case bufferFormatMismatch
}

/// Dedicated click-node executor. Playback supplies a common host anchor for the generation.
/// Project sample times are converted to node-relative sample times before scheduling. Replacing or
/// invalidating a generation stops the dedicated player node first, flushing every queued stale click.
/// The engine/graph remain Playback-owned.
public final class AppleSampleAccurateClickExecutor: @unchecked Sendable {
    public let playerNode: AVAudioPlayerNode

    private let lock = NSLock()
    private var executionState: DSPClickExecutionState

    public init(
        playerNode: AVAudioPlayerNode,
        initialGeneration: UInt64 = 0
    ) {
        self.playerNode = playerNode
        self.executionState = DSPClickExecutionState(
            activeGeneration: initialGeneration
        )
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
        lock.lock()
        defer { lock.unlock() }

        let batch = try DSPClickExecutionPlanner.preflight(
            events: events,
            activeGeneration: generation,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            kind: kind
        )
        try validateBuffers(
            normalClick: normalClick,
            accentClick: accentClick,
            sampleRate: sampleRate
        )

        // Mutate a copy first. Generation regression or invalid replacement cannot destroy the
        // currently audible queue.
        var nextState = executionState
        try nextState.invalidate(to: generation)
        try nextState.acceptReplacement(batch)

        playerNode.stop()
        schedule(
            batch.relativeEvents,
            sampleRate: sampleRate,
            normalClick: normalClick,
            accentClick: accentClick
        )
        executionState = nextState

        if !batch.relativeEvents.isEmpty {
            playerNode.play(at: AVAudioTime(hostTime: commonHostTime))
        }
    }

    /// Appends a rolling metronome window. The portable state rejects changed generation, render
    /// anchor, sample rate, schedule kind or an overlapping time range before any buffer is queued.
    public func appendSchedule(
        events: [DSPClickEvent],
        kind: DSPClickBatchKind,
        generation: UInt64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        normalClick: AVAudioPCMBuffer,
        accentClick: AVAudioPCMBuffer
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let batch = try DSPClickExecutionPlanner.preflight(
            events: events,
            activeGeneration: generation,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            kind: kind
        )
        try validateBuffers(
            normalClick: normalClick,
            accentClick: accentClick,
            sampleRate: sampleRate
        )

        var nextState = executionState
        try nextState.acceptAppend(batch)
        schedule(
            batch.relativeEvents,
            sampleRate: sampleRate,
            normalClick: normalClick,
            accentClick: accentClick
        )
        executionState = nextState
    }

    /// Seek/loop/tempo/interruption code calls this immediately after obtaining a newer
    /// `scheduleGeneration`. Stopping this dedicated node purges old queued click buffers without
    /// touching the music/stem player nodes.
    public func invalidateSchedule(to generation: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }

        var nextState = executionState
        try nextState.invalidate(to: generation)
        playerNode.stop()
        executionState = nextState
    }

    public func stateSnapshot() -> DSPClickExecutionState {
        lock.lock()
        defer { lock.unlock() }
        return executionState
    }

    private func schedule(
        _ relativeEvents: [DSPClickEvent],
        sampleRate: Double,
        normalClick: AVAudioPCMBuffer,
        accentClick: AVAudioPCMBuffer
    ) {
        for event in relativeEvents {
            let buffer = event.accent ? accentClick : normalClick
            playerNode.scheduleBuffer(
                buffer,
                at: AVAudioTime(
                    sampleTime: AVAudioFramePosition(event.sampleTime),
                    atRate: sampleRate
                ),
                options: [],
                completionHandler: nil
            )
        }
    }

    private func validateBuffers(
        normalClick: AVAudioPCMBuffer,
        accentClick: AVAudioPCMBuffer,
        sampleRate: Double
    ) throws {
        guard normalClick.frameLength > 0 else {
            throw AppleSampleAccurateClickExecutorError.emptyNormalClickBuffer
        }
        guard accentClick.frameLength > 0 else {
            throw AppleSampleAccurateClickExecutorError.emptyAccentClickBuffer
        }

        let normalFormat = normalClick.format
        let accentFormat = accentClick.format
        guard normalFormat.sampleRate.isFinite,
              accentFormat.sampleRate.isFinite,
              abs(normalFormat.sampleRate - sampleRate) <= 0.5,
              abs(accentFormat.sampleRate - sampleRate) <= 0.5,
              normalFormat.channelCount > 0,
              normalFormat.channelCount == accentFormat.channelCount,
              normalFormat.commonFormat == accentFormat.commonFormat,
              normalFormat.isInterleaved == accentFormat.isInterleaved else {
            throw AppleSampleAccurateClickExecutorError.bufferFormatMismatch
        }
    }
}
#endif
