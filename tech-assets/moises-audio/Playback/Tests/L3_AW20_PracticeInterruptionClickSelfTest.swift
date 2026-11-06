import Foundation

private final class AW20PlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW20DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW20ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        precondition(generation >= self.generation)
        self.generation = generation
    }
}

private func aw20Executed(_ outcome: Lane3InterruptionGuardedOutcome) -> Bool {
    guard case let .transport(transport) = outcome else { return false }
    if case .executed = transport { return true }
    return false
}

private func aw20ExpectThrow<T>(
    _ operation: () async throws -> T
) async {
    do {
        _ = try await operation()
        preconditionFailure("expected operation to throw")
    } catch {
        return
    }
}

@main
struct L3AW20PracticeInterruptionClickSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW20PlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let controller = try PracticeDSPProductionController(projectID: project, backend: AW20DSPBackend())
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: AW20ClickInvalidator()
        )
        let authority = Lane3UnifiedProductionTransportAuthority(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: .milliseconds(2),
                loopQuietPeriod: .milliseconds(2),
                tempoQuietPeriod: .milliseconds(2)
            )
        )
        let lifecycle = Lane3InterruptionLifecycleGate(authority: authority)
        let telemetry = Lane3ProductionTelemetryCollector()
        let instrumented = Lane3InstrumentedInterruptionGate(gate: lifecycle, telemetry: telemetry)
        let gate = Lane3PracticeInterruptionClickGate(transport: instrumented, coordinator: coordinator)

        let initialPlay = await instrumented.submitPlay()
        precondition(aw20Executed(initialPlay))

        _ = try await gate.setMetronomeEnabled(true)
        let countIn = try await gate.scheduleCountIn(clicks: 4)
        _ = try await gate.makeCountInPlan(
            authorization: countIn,
            sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 48_000,
            renderOriginSampleTime: 0,
            sampleRate: 48_000
        )

        let begin = await gate.submitInterruptionBegan()
        precondition(begin.countInAuthorizationRevoked)
        precondition(begin.underlyingPendingCountInClicksAfterBoundary == 4)
        await aw20ExpectThrow {
            try await gate.makeCountInPlan(
                authorization: countIn,
                sourceBeatIntervalSeconds: 0.5,
                musicStartSampleTime: 48_000,
                renderOriginSampleTime: 0,
                sampleRate: 48_000
            )
        }
        await aw20ExpectThrow { try await gate.scheduleCountIn(clicks: 2) }

        let end = await gate.submitInterruptionEnded(shouldResume: true)
        precondition(!end.countInAutoRestoreAllowed)
        guard let restore = end.metronomeRestoreAuthorization else {
            preconditionFailure("metronome restore authorization missing")
        }
        precondition(restore.requiresFreshRenderOrigin)
        precondition(restore.requiresFreshCommonHostAnchor)
        let restoredPlan = try await gate.makeMetronomeRestorePlan(
            authorization: restore,
            beatTimesSeconds: [0, 0.5, 1.0, 1.5],
            sourceStartSeconds: 0,
            sourceEndSeconds: 2,
            renderOriginSampleTime: 96_000,
            sampleRate: 48_000
        )
        precondition(restoredPlan.executionBatch.generation == restore.clickGeneration)

        _ = await gate.submitInterruptionBegan()
        await aw20ExpectThrow {
            try await gate.makeMetronomeRestorePlan(
                authorization: restore,
                beatTimesSeconds: [0, 0.5],
                sourceStartSeconds: 0,
                sourceEndSeconds: 1,
                renderOriginSampleTime: 0,
                sampleRate: 48_000
            )
        }
        let noResume = await gate.submitInterruptionEnded(shouldResume: false)
        precondition(noResume.metronomeRestoreAuthorization == nil)
        precondition(!noResume.countInAutoRestoreAllowed)

        let countIn2 = try await gate.scheduleCountIn(clicks: 2)
        _ = try await gate.makeCountInPlan(
            authorization: countIn2,
            sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 48_000,
            renderOriginSampleTime: 0,
            sampleRate: 48_000
        )
        try await gate.markCountInScheduleCommitted(authorization: countIn2)
        await aw20ExpectThrow {
            try await gate.makeCountInPlan(
                authorization: countIn2,
                sourceBeatIntervalSeconds: 0.5,
                musicStartSampleTime: 48_000,
                renderOriginSampleTime: 0,
                sampleRate: 48_000
            )
        }

        _ = await gate.submitInterruptionBegan()
        let end2 = await gate.submitInterruptionEnded(shouldResume: true)
        guard let restore2 = end2.metronomeRestoreAuthorization else {
            preconditionFailure("second metronome restore authorization missing")
        }
        _ = try await gate.setMetronomeEnabled(true)
        await aw20ExpectThrow {
            try await gate.makeMetronomeRestorePlan(
                authorization: restore2,
                beatTimesSeconds: [0, 0.5],
                sourceStartSeconds: 0,
                sourceEndSeconds: 1,
                renderOriginSampleTime: 0,
                sampleRate: 48_000
            )
        }

        let final = try await gate.snapshot()
        precondition(final.lifecycle.phase == .idle)
        precondition(final.countInAuthorization == nil)
        precondition(final.metronomeEnabled)

        print("L3-AW20 practice interruption click self-test PASS")
    }
}
