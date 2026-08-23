import Foundation

private final class StableAW12DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class RecordingAW12ClickInvalidator: @unchecked Sendable, PracticeDSPClickScheduleInvalidating {
    private struct ForcedFailure: Error {}
    private let lock = NSLock()
    private var generations: [UInt64] = []
    private var failures: Set<UInt64> = []

    func fail(on generation: UInt64) {
        lock.lock(); defer { lock.unlock() }
        failures.insert(generation)
    }

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        if failures.remove(generation) != nil { throw ForcedFailure() }
        generations.append(generation)
    }

    func snapshot() -> [UInt64] {
        lock.lock(); defer { lock.unlock() }
        return generations
    }
}

@main
struct L3AW12ProductionGenerationCoordinatorSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let backend = StableAW12DSPBackend()
        let controller = try PracticeDSPProductionController(projectID: project, backend: backend)
        let invalidator = RecordingAW12ClickInvalidator()
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: invalidator
        )

        let seek = try await coordinator.bindTransportDiscontinuity(
            playbackToken: PlaybackTransportRescheduleToken(generation: 1, reason: .seek)
        )
        precondition(seek.playbackGeneration == 1 && seek.clickGeneration == 1)
        let seekBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: 1,
            clickGeneration: 1,
            reason: .seek
        )
        try await coordinator.validateReplacement(binding: seekBinding)

        let metronome = try await coordinator.setMetronomeEnabled(true)
        precondition(metronome.clickGeneration == 2)
        precondition(!metronome.replacementBindingActive)
        do {
            try await coordinator.validateReplacement(binding: seekBinding)
            preconditionFailure("click-only mutation must revoke the older combined binding")
        } catch PracticeDSPTransportRescheduleError.staleBinding { }

        let countIn = try await coordinator.scheduleCountIn(clicks: 4)
        precondition(countIn.clickGeneration == 3)

        let tempo = try await coordinator.applyTempoRatio(
            1.25,
            playbackToken: PlaybackTransportRescheduleToken(generation: 2, reason: .tempoChange)
        )
        precondition(tempo.playbackGeneration == 2 && tempo.clickGeneration == 4)
        let tempoBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: 2,
            clickGeneration: 4,
            reason: .tempoChange
        )
        try await coordinator.validateReplacement(binding: tempoBinding)

        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 2, reason: .seek)
            )
            preconditionFailure("reused Playback generation must fail")
        } catch PracticeDSPTransportRescheduleError.playbackGenerationNotAdvanced { }
        try await coordinator.validateReplacement(binding: tempoBinding)

        invalidator.fail(on: 5)
        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 3, reason: .seek)
            )
            preconditionFailure("click invalidation failure must poison")
        } catch PracticeDSPGenerationCoordinatorError.clickInvalidationFailed { }
        var snapshot = try await coordinator.snapshot()
        precondition(snapshot.isPoisoned)
        precondition(snapshot.activeBinding == nil)
        precondition(snapshot.dspState.scheduleGeneration == 5)

        do {
            _ = try await coordinator.recover(
                playbackToken: PlaybackTransportRescheduleToken(generation: 3, reason: .recovery)
            )
            preconditionFailure("the failed Playback generation must not be reusable for recovery")
        } catch PracticeDSPGenerationCoordinatorError.recoveryFailed { }
        snapshot = try await coordinator.snapshot()
        precondition(snapshot.isPoisoned)
        precondition(snapshot.dspState.scheduleGeneration == 6)

        let recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 4, reason: .recovery)
        )
        precondition(recovery.playbackGeneration == 4 && recovery.clickGeneration == 7)
        let recoveryBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: 4,
            clickGeneration: 7,
            reason: .recovery
        )
        try await coordinator.validateReplacement(binding: recoveryBinding)

        invalidator.fail(on: 8)
        do {
            _ = try await coordinator.setMetronomeEnabled(false)
            preconditionFailure("click-only queue failure must poison after binding revocation")
        } catch PracticeDSPGenerationCoordinatorError.clickInvalidationFailed { }
        snapshot = try await coordinator.snapshot()
        precondition(snapshot.isPoisoned && snapshot.activeBinding == nil)
        precondition(snapshot.dspState.scheduleGeneration == 8)

        let recovery2 = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 5, reason: .recovery)
        )
        precondition(recovery2.clickGeneration == 9)
        let recoveryBinding2 = PracticeDSPTransportGenerationBinding(
            playbackGeneration: 5,
            clickGeneration: 9,
            reason: .recovery
        )
        try await coordinator.validateReplacement(binding: recoveryBinding2)

        do {
            _ = try await coordinator.scheduleCountIn(clicks: 0)
            preconditionFailure("invalid count-in must fail atomically")
        } catch PracticeDSPGenerationCoordinatorError.dspMutationFailed { }
        try await coordinator.validateReplacement(binding: recoveryBinding2)
        snapshot = try await coordinator.snapshot()
        precondition(!snapshot.isPoisoned && snapshot.dspState.scheduleGeneration == 9)

        do {
            _ = try await coordinator.applyTempoRatio(
                1.1,
                playbackToken: PlaybackTransportRescheduleToken(generation: 6, reason: .seek)
            )
            preconditionFailure("tempo mutation requires tempoChange Playback token")
        } catch PracticeDSPGenerationCoordinatorError.expectedTempoChangeToken { }
        try await coordinator.validateReplacement(binding: recoveryBinding2)

        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 6, reason: .tempoChange)
            )
            preconditionFailure("generic bind must not bypass transactional tempo mutation")
        } catch PracticeDSPGenerationCoordinatorError.tempoChangeRequiresTempoMutation { }

        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 6, reason: .recovery)
            )
            preconditionFailure("generic bind must not bypass explicit recovery path")
        } catch PracticeDSPGenerationCoordinatorError.recoveryRequiresRecoveryPath { }

        let overflowController = try PracticeDSPProductionController(
            projectID: project,
            backend: StableAW12DSPBackend()
        )
        let overflowCoordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: overflowController,
            clickInvalidator: invalidator,
            initialOperationSerial: UInt64.max
        )
        do {
            _ = try await overflowCoordinator.setMetronomeEnabled(true)
            preconditionFailure("operation serial overflow must fail closed")
        } catch PracticeDSPGenerationCoordinatorError.operationSerialOverflow { }
        let overflowSnapshot = try await overflowCoordinator.snapshot()
        precondition(overflowSnapshot.isPoisoned)

        precondition(invalidator.snapshot() == [1, 2, 3, 4, 6, 7, 9])
        print("L3-AW12 production combined-generation coordinator self-test PASS")
    }
}
