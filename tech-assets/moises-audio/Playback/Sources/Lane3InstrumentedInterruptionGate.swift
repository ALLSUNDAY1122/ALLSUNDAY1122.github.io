import Foundation

/// Product entry facade for AW18 + AW19.
/// This type intentionally contains no mutable product state so concurrent submissions still reach
/// the underlying AW18/AW17 actors concurrently and retain pre-token coalescing semantics.
public final class Lane3InstrumentedInterruptionGate: @unchecked Sendable {
    private let gate: Lane3InterruptionLifecycleGate
    private let telemetry: Lane3ProductionTelemetryCollector
    private let correlations: Lane3TelemetryDispatchCorrelationBridge?
    private let timeSource: any Lane3TelemetryTimeSource

    public init(
        gate: Lane3InterruptionLifecycleGate,
        telemetry: Lane3ProductionTelemetryCollector,
        correlations: Lane3TelemetryDispatchCorrelationBridge? = nil,
        timeSource: any Lane3TelemetryTimeSource = Lane3SystemTelemetryTimeSource()
    ) {
        self.gate = gate
        self.telemetry = telemetry
        self.correlations = correlations
        self.timeSource = timeSource
    }

    public func submitSeek(
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .seek) {
            await gate.submitSeek(to: positionSeconds, resume: resume, loop: loop)
        }
    }

    public func submitLoop(_ loop: PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .loop) { await gate.submitLoop(loop) }
    }

    public func submitTempoRatio(_ ratio: Double) async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .tempo) { await gate.submitTempoRatio(ratio) }
    }

    public func submitMediaLoad(_ asset: LocalAudioAsset) async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .mediaLoad) { await gate.submitMediaLoad(asset) }
    }

    public func submitMediaReplacement(
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .mediaReplacement) {
            await gate.submitMediaReplacement(
                stems: stems,
                positionSeconds: positionSeconds,
                resume: resume,
                loop: loop
            )
        }
    }

    public func submitPlay() async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .play) { await gate.submitPlay() }
    }

    public func submitPause() async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .pause) { await gate.submitPause() }
    }

    public func submitRecovery() async -> Lane3InterruptionGuardedOutcome {
        await measureGuarded(kind: .recovery) { await gate.submitRecovery() }
    }

    public func submitInterruptionBegan() async -> Lane3InterruptionBeginResult {
        let start = timeSource.nowNanoseconds()
        let result = await gate.submitInterruptionBegan()
        let end = timeSource.nowNanoseconds()
        if let correlations {
            await correlations.forwardCorrelations(for: result, to: telemetry)
        }
        await telemetry.recordInterruptionBegin(
            startedAtNanoseconds: start,
            completedAtNanoseconds: end,
            result: result
        )
        return result
    }

    public func submitInterruptionEnded(shouldResume: Bool) async -> Lane3InterruptionEndResult {
        let start = timeSource.nowNanoseconds()
        let result = await gate.submitInterruptionEnded(shouldResume: shouldResume)
        let end = timeSource.nowNanoseconds()
        if let correlations {
            await correlations.forwardCorrelations(for: result, to: telemetry)
        }
        await telemetry.recordInterruptionEnd(
            startedAtNanoseconds: start,
            completedAtNanoseconds: end,
            result: result
        )
        return result
    }

    public func retryEndedInterruptionRecovery() async -> Lane3InterruptionEndResult {
        let start = timeSource.nowNanoseconds()
        let result = await gate.retryEndedInterruptionRecovery()
        let end = timeSource.nowNanoseconds()
        if let correlations {
            await correlations.forwardCorrelations(for: result, to: telemetry)
        }
        await telemetry.recordInterruptionEnd(
            startedAtNanoseconds: start,
            completedAtNanoseconds: end,
            result: result
        )
        return result
    }

    public func snapshot() async -> Lane3InterruptionLifecycleSnapshot {
        await gate.snapshot()
    }

    public func telemetrySnapshot() async -> Lane3ProductionTelemetrySnapshot {
        await telemetry.snapshot()
    }

    public func telemetryCorrelationHealthSnapshot() async -> Lane3TelemetryCorrelationHealthSnapshot? {
        guard let correlations else { return nil }
        return await correlations.snapshot()
    }

    private func measureGuarded(
        kind: Lane3UnifiedTransportKind,
        operation: () async -> Lane3InterruptionGuardedOutcome
    ) async -> Lane3InterruptionGuardedOutcome {
        let start = timeSource.nowNanoseconds()
        let outcome = await operation()
        let end = timeSource.nowNanoseconds()
        if let correlations {
            await correlations.forwardCorrelation(
                for: outcome,
                expectedProductKind: kind,
                to: telemetry
            )
        }
        await telemetry.recordGuardedSubmission(
            kind: kind,
            startedAtNanoseconds: start,
            completedAtNanoseconds: end,
            outcome: outcome
        )
        return outcome
    }
}
