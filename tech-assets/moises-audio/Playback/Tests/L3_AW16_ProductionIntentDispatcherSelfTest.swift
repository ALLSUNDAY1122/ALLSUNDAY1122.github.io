import Foundation

private final class AW16PlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    private struct ForcedFailure: Error {}
    private let lock = NSLock()
    private var failSeekCount = 0
    private var failLoopCount = 0
    private var seekCount = 0
    private var loopCount = 0
    private var position = 0.0

    func failNextSeek(_ count: Int = 1) {
        lock.lock(); defer { lock.unlock() }
        failSeekCount += count
    }

    func counts() -> (seek: Int, loop: Int) {
        lock.lock(); defer { lock.unlock() }
        return (seekCount, loopCount)
    }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}

    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {
        lock.lock()
        seekCount += 1
        if failSeekCount > 0 {
            failSeekCount -= 1
            lock.unlock()
            throw ForcedFailure()
        }
        position = positionSeconds
        lock.unlock()
    }

    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        lock.lock()
        loopCount += 1
        if failLoopCount > 0 {
            failLoopCount -= 1
            lock.unlock()
            throw ForcedFailure()
        }
        lock.unlock()
    }

    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}

    func currentPositionSeconds(projectID: ProjectID) async -> Double? {
        lock.lock(); defer { lock.unlock() }
        return position
    }
}

private final class AW16DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW16ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private struct ForcedFailure: Error {}
    private let lock = NSLock()
    private var failCount = 0
    private var generations: [UInt64] = []

    func failNext(_ count: Int = 1) {
        lock.lock(); defer { lock.unlock() }
        failCount += count
    }

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        if failCount > 0 {
            failCount -= 1
            throw ForcedFailure()
        }
        generations.append(generation)
    }

    func snapshot() -> [UInt64] {
        lock.lock(); defer { lock.unlock() }
        return generations
    }
}

@main
struct L3AW16ProductionIntentDispatcherSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW16PlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let dspBackend = AW16DSPBackend()
        let controller = try PracticeDSPProductionController(projectID: project, backend: dspBackend)
        let invalidator = AW16ClickInvalidator()
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: invalidator
        )
        let dispatcher = Lane3ProductionIntentDispatcher(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3ContinuousDispatchPolicy(
                seekQuietPeriod: .milliseconds(8),
                loopQuietPeriod: .milliseconds(8),
                tempoQuietPeriod: .milliseconds(8)
            )
        )

        precondition(Lane3ProductionTokenRouting.route(for: .seek) == .transportBinding)
        precondition(Lane3ProductionTokenRouting.route(for: .loopChange) == .transportBinding)
        precondition(Lane3ProductionTokenRouting.route(for: .tempoChange) == .tempoMutation)
        precondition(Lane3ProductionTokenRouting.route(for: .recovery) == .recovery)

        var seekExecuted = 0
        var seekSuperseded = 0
        var finalSeekReceipt: Lane3IntentExecutionReceipt?
        await withTaskGroup(of: Lane3IntentDispatchOutcome.self) { group in
            for index in 0..<500 {
                group.addTask {
                    await dispatcher.submitSeek(
                        to: Double(index),
                        resume: true,
                        loop: nil
                    )
                }
            }
            for await result in group {
                switch result {
                case let .executed(receipt):
                    seekExecuted += 1
                    finalSeekReceipt = receipt
                case .superseded:
                    seekSuperseded += 1
                default:
                    preconditionFailure("rapid valid seek must execute once or be superseded")
                }
            }
        }
        precondition(seekExecuted == 1)
        precondition(seekSuperseded == 499)
        precondition(finalSeekReceipt?.coalescedPredecessorCount == 499)
        precondition(finalSeekReceipt?.playbackGeneration == 1)
        precondition(rawPlayback.counts().seek == 1)

        let beforeInvalid = await playback.rescheduleTokenSnapshot(projectID: project)
        let invalidTempo = await dispatcher.submitTempoRatio(.nan)
        guard case .rejectedBeforeToken(_, .tempo, "invalidTempoRatio") = invalidTempo else {
            preconditionFailure("invalid tempo must be rejected before token generation")
        }
        precondition(await playback.rescheduleTokenSnapshot(projectID: project) == beforeInvalid)

        rawPlayback.failNextSeek()
        let failedSeek = await dispatcher.submitSeek(to: 777, resume: true, loop: nil)
        guard case let .failedAfterDispatch(failure) = failedSeek else {
            preconditionFailure("forced seek failure must return a durable failure receipt")
        }
        precondition(failure.playbackGeneration == 2)
        precondition(failure.tokenReason == .seek)
        precondition(failure.automaticRecovery.attempted)
        precondition(failure.automaticRecovery.succeeded)
        precondition(failure.automaticRecovery.playbackGeneration == 3)
        precondition(!(await dispatcher.isRecoveryBlocked()))

        let tempo = await dispatcher.submitTempoRatio(1.25)
        guard case let .executed(tempoReceipt) = tempo else {
            preconditionFailure("valid tempo must execute after automatic recovery")
        }
        precondition(tempoReceipt.playbackGeneration == 4)
        precondition(tempoReceipt.coordinatorReceipt.mutationKind == .tempoChange)
        precondition(tempoReceipt.coordinatorReceipt.reason == PlaybackTransportDiscontinuityReason.tempoChange.rawValue)

        let tokenBeforeCancellation = await playback.rescheduleTokenSnapshot(projectID: project)
        let cancelledTask = Task {
            await dispatcher.submitLoop(PlaybackLoopRange(startSeconds: 0, endSeconds: 4))
        }
        cancelledTask.cancel()
        let cancelled = await cancelledTask.value
        guard case .cancelledBeforeDispatch(_, .loop) = cancelled else {
            preconditionFailure("pending caller cancellation must remain pre-token")
        }
        precondition(await playback.rescheduleTokenSnapshot(projectID: project) == tokenBeforeCancellation)

        // Force coordinator click invalidation and its immediate automatic recovery to both fail.
        // Dispatcher must block further token generation until explicit retryRecovery succeeds.
        invalidator.failNext(2)
        let blockedFailure = await dispatcher.submitSeek(to: 888, resume: true, loop: nil)
        guard case let .failedAfterDispatch(blockedReceipt) = blockedFailure else {
            preconditionFailure("forced double click failure must return failure receipt")
        }
        precondition(blockedReceipt.playbackGeneration == 5)
        precondition(blockedReceipt.automaticRecovery.attempted)
        precondition(!blockedReceipt.automaticRecovery.succeeded)
        precondition(await dispatcher.isRecoveryBlocked())

        let blockedSnapshot = await playback.rescheduleTokenSnapshot(projectID: project)
        let rejectedWhileBlocked = await dispatcher.submitTempoRatio(1.5)
        guard case .rejectedBeforeToken(_, .tempo, "dispatcherRecoveryBlocked") = rejectedWhileBlocked else {
            preconditionFailure("blocked dispatcher must reject without issuing another control token")
        }
        precondition(await playback.rescheduleTokenSnapshot(projectID: project) == blockedSnapshot)

        let retry = await dispatcher.retryRecovery()
        precondition(retry.attempted && retry.succeeded)
        precondition(!(await dispatcher.isRecoveryBlocked()))

        let finalLoop = await dispatcher.submitLoop(PlaybackLoopRange(startSeconds: 1, endSeconds: 3))
        guard case let .executed(loopReceipt) = finalLoop else {
            preconditionFailure("dispatcher must resume normal operation after recovery retry")
        }
        let binding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: loopReceipt.coordinatorReceipt.playbackGeneration!,
            clickGeneration: loopReceipt.coordinatorReceipt.clickGeneration,
            reason: .loopChange
        )
        try await coordinator.validateReplacement(binding: binding)

        print("L3-AW16 production intent dispatcher self-test PASS")
    }
}
