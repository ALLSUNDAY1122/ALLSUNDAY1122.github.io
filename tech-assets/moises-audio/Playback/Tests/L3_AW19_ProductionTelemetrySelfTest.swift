import Foundation

private actor AW19PlaybackBackend: PlaybackBackendDriving {
    struct ForcedFailure: Error {}
    private var failPlayCount = 0

    func failNextPlay(_ count: Int = 1) { failPlayCount += count }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}

    func play(projectID: ProjectID) async throws {
        if failPlayCount > 0 {
            failPlayCount -= 1
            throw ForcedFailure()
        }
    }

    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW19DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var tempo = 1.0
    private var pitch = 0.0

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        tempo = tempoRatio
        pitch = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        lock.lock(); defer { lock.unlock() }
        return PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW19ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

@main
struct L3AW19ProductionTelemetrySelfTest {
    static func main() async throws {
        let project = ProjectID()
        let telemetry = Lane3ProductionTelemetryCollector(
            policy: Lane3TelemetryPolicy(
                seekQuietPeriodNanoseconds: 20_000_000,
                loopQuietPeriodNanoseconds: 20_000_000,
                tempoQuietPeriodNanoseconds: 20_000_000
            )
        )
        let correlations = Lane3TelemetryDispatchCorrelationBridge(maxPendingPerKind: 64)
        let rawPlayback = AW19PlaybackBackend()
        let measuredPlayback = Lane3TelemetryPlaybackBackend(
            backend: rawPlayback,
            telemetry: telemetry,
            correlations: correlations
        )
        let playback = RescheduleFencedPlaybackBackend(backend: measuredPlayback)
        let controller = try PracticeDSPProductionController(
            projectID: project,
            backend: AW19DSPBackend()
        )
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: AW19ClickInvalidator()
        )
        let authority = Lane3UnifiedProductionTransportAuthority(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: .milliseconds(20),
                loopQuietPeriod: .milliseconds(20),
                tempoQuietPeriod: .milliseconds(20)
            )
        )
        let lifecycle = Lane3InterruptionLifecycleGate(authority: authority)
        let instrumented = Lane3InstrumentedInterruptionGate(
            gate: lifecycle,
            telemetry: telemetry,
            correlations: correlations
        )

        var executedSeek = 0
        var supersededSeek = 0
        await withTaskGroup(of: Lane3InterruptionGuardedOutcome.self) { group in
            for index in 0..<500 {
                group.addTask {
                    await instrumented.submitSeek(
                        to: Double(index),
                        resume: false,
                        loop: nil
                    )
                }
            }
            for await outcome in group {
                switch outcome {
                case .transport(.executed): executedSeek += 1
                case .transport(.supersededBeforeToken): supersededSeek += 1
                default: preconditionFailure("rapid seek telemetry path returned unexpected outcome")
                }
            }
        }
        precondition(executedSeek == 1)
        precondition(supersededSeek == 499)

        guard case .transport(.executed) = await instrumented.submitPlay() else {
            preconditionFailure("play setup failed")
        }
        guard case let .began(begin) = await instrumented.submitInterruptionBegan() else {
            preconditionFailure("instrumented interruption begin failed")
        }
        precondition(begin.boundarySafe && begin.resumeArmed)

        guard case .rejectedBeforeTransport(.seek, .interruptionActive) = await instrumented.submitSeek(to: 5, resume: true, loop: nil),
              case .rejectedBeforeTransport(.tempo, .interruptionActive) = await instrumented.submitTempoRatio(1.1) else {
            preconditionFailure("active interruption commands were not rejected pre-token")
        }
        guard case .resumeSuppressedWithoutToken = await instrumented.submitPause() else {
            preconditionFailure("interruption pause did not suppress resume")
        }
        guard case let .ended(end) = await instrumented.submitInterruptionEnded(shouldResume: true) else {
            preconditionFailure("instrumented interruption end failed")
        }
        precondition(end.boundarySafe && !end.resumedPlayback)

        await rawPlayback.failNextPlay()
        guard case let .transport(.failedAfterDispatch(failure)) = await instrumented.submitPlay() else {
            preconditionFailure("forced play failure missing")
        }
        precondition(failure.playbackGeneration != nil)
        precondition(failure.automaticRecovery.attempted)
        precondition(failure.automaticRecovery.succeeded)
        precondition(failure.automaticRecovery.playbackGeneration != nil)

        let snapshot = await instrumented.telemetrySnapshot()
        precondition(snapshot.scope == "LANE3_PRIVACY_PRESERVING_PRODUCTION_TELEMETRY_NON_PARITY")
        precondition(snapshot.privacy.aggregationOnly)
        precondition(!snapshot.privacy.rawEventLogRetained)
        precondition(!snapshot.privacy.absoluteWallClockCaptured)
        precondition(!snapshot.privacy.projectIdentifierCaptured)
        precondition(!snapshot.privacy.mediaNameOrPathCaptured)
        precondition(!snapshot.privacy.pcmOrAudioContentCaptured)
        precondition(!snapshot.privacy.ticketOrGenerationValueExported)
        precondition(snapshot.totalProductSubmissions == 507)
        precondition(snapshot.totalInternalTransportOperations == 2)
        precondition(snapshot.totalControlPlaybackTokens == 5)
        precondition(snapshot.totalRecoveryPlaybackTokens == 1)
        precondition(snapshot.totalPlaybackTokensObserved == 6)
        precondition(snapshot.totalPreTokenSuperseded == 499)
        precondition(snapshot.totalCoalescedPredecessors == 499)
        precondition(snapshot.backendDispatchEntrySamplesUnmatched == 0)
        precondition(!snapshot.counterOverflowed)

        let seek = snapshot.perKind.first(where: { $0.kind == Lane3UnifiedTransportKind.seek.rawValue })!
        precondition(seek.productSubmissions == 501)
        precondition(seek.executed == 1)
        precondition(seek.supersededBeforeToken == 499)
        precondition(seek.rejectedBeforeToken == 1)
        precondition(seek.controlPlaybackTokens == 1)
        precondition(seek.submissionToBackendEntryLatency.samples == 1)
        precondition(seek.postConfiguredQuietResidualLatency.samples == 1)
        precondition(seek.backendExecutionLatency.samples == 1)

        let play = snapshot.perKind.first(where: { $0.kind == Lane3UnifiedTransportKind.play.rawValue })!
        precondition(play.productSubmissions == 2)
        precondition(play.executed == 1)
        precondition(play.failedAfterDispatch == 1)
        precondition(play.controlPlaybackTokens == 2)
        precondition(play.recoveryPlaybackTokens == 1)
        precondition(play.submissionToBackendEntryLatency.samples == 2)
        precondition(play.backendExecutionLatency.samples == 2)

        precondition(snapshot.interruption.beginCalls == 1)
        precondition(snapshot.interruption.endCalls == 1)
        precondition(snapshot.interruption.osShouldResumeTrue == 1)
        precondition(snapshot.interruption.resumeArmedAtEnd == 0)
        precondition(snapshot.interruption.resumeSuppressedWithoutToken == 1)
        precondition(snapshot.interruption.resumedPlayback == 0)

        guard let correlationHealth = await instrumented.telemetryCorrelationHealthSnapshot() else {
            preconditionFailure("bounded correlation health unavailable")
        }
        precondition(correlationHealth.pendingEntries == 0)
        precondition(correlationHealth.overflowDrops == 0)
        precondition(correlationHealth.unmatchedBackendOutcomes == 0)

        let data = try JSONEncoder().encode(snapshot)
        let json = String(decoding: data, as: UTF8.self)
        for forbidden in ["/private/", "song.wav", "ProjectID(", "pcmSamples", "absoluteTimestamp"] {
            precondition(!json.contains(forbidden))
        }

        print("L3-AW19 production telemetry self-test PASS")
    }
}
