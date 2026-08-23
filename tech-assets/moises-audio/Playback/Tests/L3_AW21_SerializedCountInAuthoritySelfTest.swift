import Foundation

private final class AW21PlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW21DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private enum AW21InvalidatorError: Error {
    case injected
}

private final class AW21ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var shouldFail = false
    private var calls = 0

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        calls += 1
        if shouldFail { throw AW21InvalidatorError.injected }
        precondition(generation >= self.generation)
        self.generation = generation
    }

    func setFailure(_ enabled: Bool) {
        lock.lock(); defer { lock.unlock() }
        shouldFail = enabled
    }

    func snapshot() -> (generation: UInt64, calls: Int) {
        lock.lock(); defer { lock.unlock() }
        return (generation, calls)
    }
}

private func aw21Executed(_ outcome: Lane3InterruptionGuardedOutcome) -> Bool {
    guard case let .transport(transport) = outcome else { return false }
    if case .executed = transport { return true }
    return false
}

private func aw21ExpectThrow<T>(_ operation: () async throws -> T) async {
    do {
        _ = try await operation()
        preconditionFailure("expected operation to throw")
    } catch {}
}

@main
struct L3AW21SerializedCountInAuthoritySelfTest {
    static func main() async throws {
        let project = ProjectID()
        let clickInvalidator = AW21ClickInvalidator()
        let playback = RescheduleFencedPlaybackBackend(backend: AW21PlaybackBackend())
        let controller = try PracticeDSPProductionController(projectID: project, backend: AW21DSPBackend())
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: clickInvalidator
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
        let instrumented = Lane3InstrumentedInterruptionGate(
            gate: lifecycle,
            telemetry: Lane3ProductionTelemetryCollector()
        )
        let aw20 = Lane3PracticeInterruptionClickGate(
            transport: instrumented,
            coordinator: coordinator
        )
        let gate = Lane3SerializedPracticeClickGate(
            practiceGate: aw20,
            coordinator: coordinator
        )

        let initialPlay = await instrumented.submitPlay()
        precondition(aw21Executed(initialPlay))

        // Executor-accepted consume: raw pending becomes nil but accepted generation is preserved.
        let first = try await gate.scheduleCountIn(clicks: 4)
        _ = try await gate.makeCountInPlan(
            authorization: first,
            sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 48_000,
            renderOriginSampleTime: 0,
            sampleRate: 48_000
        )
        let beforeCommitCalls = clickInvalidator.snapshot().calls
        let consume = try await gate.markCountInScheduleCommitted(authorization: first)
        precondition(consume.disposition == .consumedAcceptedSchedule)
        precondition(consume.acceptedSchedulePreserved)
        precondition(consume.previousClickGeneration == consume.committedClickGeneration)
        precondition(clickInvalidator.snapshot().calls == beforeCommitCalls)
        let consumedSnapshot = try await coordinator.snapshot()
        precondition(consumedSnapshot.dspState.pendingCountInClicks == nil)
        precondition(consumedSnapshot.dspState.scheduleGeneration == first.clickGenerationAtArm)
        await aw21ExpectThrow {
            try await coordinator.consumeScheduledCountIn(
                expectedClickGeneration: first.clickGenerationAtArm,
                expectedClicks: first.clicks
            )
        }

        // Any newer click-generation mutation makes the old count-in authorization stale.
        let stale = try await gate.scheduleCountIn(clicks: 2)
        _ = try await gate.setMetronomeEnabled(true)
        await aw21ExpectThrow {
            try await gate.makeCountInPlan(
                authorization: stale,
                sourceBeatIntervalSeconds: 0.5,
                musicStartSampleTime: 48_000,
                renderOriginSampleTime: 0,
                sampleRate: 48_000
            )
        }

        // Interruption discards the quarantined raw pending value before the transport boundary.
        let begin = await gate.submitInterruptionBegan()
        precondition(begin.rawPendingCountInDiscarded)
        precondition(!begin.discardRequiredRecovery)
        precondition(begin.discardReceipt?.disposition == .discardedAndInvalidated)
        precondition(begin.practiceResult.underlyingPendingCountInClicksAfterBoundary == nil)
        let during = try await coordinator.snapshot()
        precondition(during.dspState.pendingCountInClicks == nil)
        let end = await gate.submitInterruptionEnded(shouldResume: true)
        precondition(!end.countInAutoRestoreAllowed)

        // Exact-authority discard never erases a newer count-in arm.
        let old = try await coordinator.scheduleCountIn(clicks: 2)
        let newer = try await coordinator.scheduleCountIn(clicks: 3)
        await aw21ExpectThrow {
            try await coordinator.discardCountIn(
                expectedClickGeneration: old.clickGeneration,
                expectedClicks: 2
            )
        }
        let newerSnapshot = try await coordinator.snapshot()
        precondition(newerSnapshot.dspState.pendingCountInClicks == 3)
        precondition(newerSnapshot.dspState.scheduleGeneration == newer.clickGeneration)
        let exactDiscard = try await coordinator.discardCountIn(
            expectedClickGeneration: newer.clickGeneration,
            expectedClicks: 3
        )
        precondition(exactDiscard.disposition == .discardedAndInvalidated)
        precondition((try await coordinator.snapshot()).dspState.pendingCountInClicks == nil)

        // Click-node failure after raw clear is fail-closed: pending remains nil and coordinator poisons.
        let failureProject = ProjectID()
        let failureInvalidator = AW21ClickInvalidator()
        let failureController = try PracticeDSPProductionController(
            projectID: failureProject,
            backend: AW21DSPBackend()
        )
        let failureCoordinator = PracticeDSPGenerationCoordinator(
            projectID: failureProject,
            controller: failureController,
            clickInvalidator: failureInvalidator
        )
        let failureArm = try await failureCoordinator.scheduleCountIn(clicks: 4)
        failureInvalidator.setFailure(true)
        await aw21ExpectThrow {
            try await failureCoordinator.discardCountIn(
                expectedClickGeneration: failureArm.clickGeneration,
                expectedClicks: 4
            )
        }
        let failed = try await failureCoordinator.snapshot()
        precondition(failed.dspState.pendingCountInClicks == nil)
        precondition(failed.isPoisoned)

        let final = try await gate.snapshot()
        precondition(final.practice.lifecycle.phase == .idle)
        precondition(final.practice.underlyingPendingCountInClicks == nil)
        precondition(!final.interruptionBoundaryInFlight)

        print("L3-AW21 serialized count-in authority self-test PASS")
    }
}
