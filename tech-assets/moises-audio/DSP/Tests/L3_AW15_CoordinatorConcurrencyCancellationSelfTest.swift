import Foundation

private final class AW15BlockingBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let condition = NSCondition()
    private var tempoRatio = 1.0
    private var pitchSemitones = 0.0
    private var blockNextSnapshot = false
    private var blockedSnapshotCount = 0
    private var releasedSnapshotCount = 0

    func armSnapshotBlock() -> Int {
        condition.lock(); defer { condition.unlock() }
        precondition(!blockNextSnapshot, "only one deterministic snapshot block may be armed at a time")
        blockNextSnapshot = true
        return blockedSnapshotCount + 1
    }

    func waitUntilBlocked(_ target: Int, timeout: TimeInterval = 3) -> Bool {
        condition.lock(); defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while blockedSnapshotCount < target {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }

    func releaseBlockedSnapshot(_ target: Int) {
        condition.lock(); defer { condition.unlock() }
        releasedSnapshotCount = max(releasedSnapshotCount, target)
        condition.broadcast()
    }

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        condition.lock(); defer { condition.unlock() }
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        condition.lock(); defer { condition.unlock() }
        if blockNextSnapshot {
            blockNextSnapshot = false
            blockedSnapshotCount += 1
            let ticket = blockedSnapshotCount
            condition.broadcast()
            while releasedSnapshotCount < ticket {
                condition.wait()
            }
        }
        return PracticeDSPBackendSnapshot(
            tempoRatio: tempoRatio,
            pitchSemitones: pitchSemitones
        )
    }
}

private final class AW15RecordingClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generations: [UInt64] = []

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        generations.append(generation)
    }

    func snapshot() -> [UInt64] {
        lock.lock(); defer { lock.unlock() }
        return generations
    }
}

@main
struct L3AW15CoordinatorConcurrencyCancellationSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let backend = AW15BlockingBackend()
        let controller = try PracticeDSPProductionController(
            projectID: project,
            backend: backend
        )
        let invalidator = AW15RecordingClickInvalidator()
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: invalidator
        )

        // 1) A newer Playback token arriving while generation 1 is suspended must supersede the
        // in-flight operation, not merely receive operationInFlight while generation 1 later commits.
        let block1 = backend.armSnapshotBlock()
        let firstTransport = Task {
            try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 1, reason: .seek)
            )
        }
        precondition(backend.waitUntilBlocked(block1), "transport did not reach deterministic await")
        var authority = await coordinator.authoritySnapshot()
        precondition(authority.operationInFlight)
        precondition(authority.pendingPlaybackGeneration == 1)
        precondition(authority.pendingReason == PlaybackTransportDiscontinuityReason.seek.rawValue)
        precondition(authority.activeBinding == nil)

        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 2, reason: .loopChange)
            )
            preconditionFailure("newer overlapping Playback token must be rejected at entry")
        } catch PracticeDSPGenerationCoordinatorError.operationInFlight { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.operationInFlight)
        precondition(authority.isPoisoned)
        precondition(authority.pendingPlaybackGeneration == nil)
        precondition(authority.lastPlaybackGeneration == 2)
        backend.releaseBlockedSnapshot(block1)
        do {
            _ = try await firstTransport.value
            preconditionFailure("superseded transport must not commit")
        } catch PracticeDSPGenerationCoordinatorError.operationSuperseded { }
        authority = await coordinator.authoritySnapshot()
        precondition(!authority.operationInFlight)
        precondition(authority.isPoisoned)
        precondition(authority.lastPlaybackGeneration == 2)
        precondition(authority.lastClickGeneration == 1)
        precondition(authority.activeBinding == nil)

        // The overlapping token itself is a recovery floor. It cannot be reused for recovery.
        do {
            _ = try await coordinator.recover(
                playbackToken: PlaybackTransportRescheduleToken(generation: 2, reason: .recovery)
            )
            preconditionFailure("superseding Playback generation must not be reusable for recovery")
        } catch PracticeDSPGenerationCoordinatorError.recoveryFailed { }
        var recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 3, reason: .recovery)
        )
        precondition(recovery.playbackGeneration == 3 && recovery.clickGeneration == 3)

        // 2) Cancellation while a transport invalidation is suspended records both the already-
        // external Playback generation and the controller-advanced click generation as floors.
        let block2 = backend.armSnapshotBlock()
        let cancelledTransport = Task {
            try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 4, reason: .seek)
            )
        }
        precondition(backend.waitUntilBlocked(block2))
        authority = await coordinator.authoritySnapshot()
        precondition(authority.operationInFlight && authority.pendingPlaybackGeneration == 4)
        do {
            _ = try await coordinator.setMetronomeEnabled(false)
            preconditionFailure("click-only overlap must not enter a second mutation")
        } catch PracticeDSPGenerationCoordinatorError.operationInFlight { }
        cancelledTransport.cancel()
        backend.releaseBlockedSnapshot(block2)
        do {
            _ = try await cancelledTransport.value
            preconditionFailure("cancelled transport must not commit")
        } catch PracticeDSPGenerationCoordinatorError.operationCancelled { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.isPoisoned)
        precondition(authority.lastPlaybackGeneration == 4)
        precondition(authority.lastClickGeneration == 4)
        precondition(authority.activeBinding == nil)
        recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 5, reason: .recovery)
        )
        precondition(recovery.playbackGeneration == 5 && recovery.clickGeneration == 5)

        // 3) A Playback token can supersede click-only work while that work is suspended in the
        // production controller. The click mutation may finish logically, but no stale binding may
        // survive and the advanced click generation must become a recovery floor.
        let block3 = backend.armSnapshotBlock()
        let supersededMetronome = Task {
            try await coordinator.setMetronomeEnabled(true)
        }
        precondition(backend.waitUntilBlocked(block3))
        authority = await coordinator.authoritySnapshot()
        precondition(authority.operationInFlight)
        precondition(authority.pendingPlaybackGeneration == nil)
        precondition(authority.activeBinding?.playbackGeneration == 5)
        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 6, reason: .seek)
            )
            preconditionFailure("overlapping Playback token must be rejected but still supersede")
        } catch PracticeDSPGenerationCoordinatorError.operationInFlight { }
        backend.releaseBlockedSnapshot(block3)
        do {
            _ = try await supersededMetronome.value
            preconditionFailure("click-only mutation superseded by Playback must not authorize output")
        } catch PracticeDSPGenerationCoordinatorError.operationSuperseded { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.isPoisoned)
        precondition(authority.lastPlaybackGeneration == 6)
        precondition(authority.lastClickGeneration == 6)
        precondition(authority.activeBinding == nil)
        do {
            _ = try await coordinator.recover(
                playbackToken: PlaybackTransportRescheduleToken(generation: 6, reason: .recovery)
            )
            preconditionFailure("superseding generation must remain a recovery floor")
        } catch PracticeDSPGenerationCoordinatorError.recoveryFailed { }
        recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 7, reason: .recovery)
        )
        precondition(recovery.clickGeneration == 8)

        // 4) Cancellation after a click-only controller mutation but before click-node invalidation
        // poisons the new click generation and revokes the prior replacement binding.
        let block4 = backend.armSnapshotBlock()
        let cancelledCountIn = Task {
            try await coordinator.scheduleCountIn(clicks: 4)
        }
        precondition(backend.waitUntilBlocked(block4))
        cancelledCountIn.cancel()
        backend.releaseBlockedSnapshot(block4)
        do {
            _ = try await cancelledCountIn.value
            preconditionFailure("cancelled count-in must not return a committed receipt")
        } catch PracticeDSPGenerationCoordinatorError.operationCancelled { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.isPoisoned)
        precondition(authority.lastPlaybackGeneration == 7)
        precondition(authority.lastClickGeneration == 9)
        precondition(authority.activeBinding == nil)
        recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 8, reason: .recovery)
        )
        precondition(recovery.clickGeneration == 10)

        // 5) Tempo cancellation can occur after the transactional controller has applied the
        // control. The control value may therefore be present, but generation authority stays
        // poisoned until a newer recovery token succeeds.
        let block5 = backend.armSnapshotBlock()
        let cancelledTempo = Task {
            try await coordinator.applyTempoRatio(
                1.25,
                playbackToken: PlaybackTransportRescheduleToken(generation: 9, reason: .tempoChange)
            )
        }
        precondition(backend.waitUntilBlocked(block5))
        cancelledTempo.cancel()
        backend.releaseBlockedSnapshot(block5)
        do {
            _ = try await cancelledTempo.value
            preconditionFailure("cancelled tempo must not publish replacement authority")
        } catch PracticeDSPGenerationCoordinatorError.operationCancelled { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.isPoisoned)
        precondition(authority.lastPlaybackGeneration == 9)
        precondition(authority.lastClickGeneration == 11)
        recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 10, reason: .recovery)
        )
        precondition(recovery.clickGeneration == 12)
        let postTempo = try await coordinator.snapshot()
        precondition(abs(postTempo.dspState.tempoRatio - 1.25) < 0.000_001)

        // 6) Recovery itself is supersedable. A newer Playback token arriving while backend
        // recovery is suspended becomes the new floor and prevents the older recovery from binding.
        do {
            _ = try await coordinator.applyTempoRatio(
                1.1,
                playbackToken: PlaybackTransportRescheduleToken(generation: 11, reason: .seek)
            )
            preconditionFailure("wrong route must poison generation 11")
        } catch PracticeDSPGenerationCoordinatorError.expectedTempoChangeToken { }
        let block6 = backend.armSnapshotBlock()
        let supersededRecovery = Task {
            try await coordinator.recover(
                playbackToken: PlaybackTransportRescheduleToken(generation: 12, reason: .recovery)
            )
        }
        precondition(backend.waitUntilBlocked(block6))
        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 13, reason: .seek)
            )
            preconditionFailure("newer transport during recovery must be rejected at entry")
        } catch PracticeDSPGenerationCoordinatorError.operationInFlight { }
        backend.releaseBlockedSnapshot(block6)
        do {
            _ = try await supersededRecovery.value
            preconditionFailure("older recovery must not bind after a newer Playback token")
        } catch PracticeDSPGenerationCoordinatorError.operationSuperseded { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.isPoisoned && authority.lastPlaybackGeneration == 13)
        recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 14, reason: .recovery)
        )
        precondition(recovery.playbackGeneration == 14 && recovery.clickGeneration == 13)

        // 7) Cancellation of a suspended recovery also preserves the recovery token as a floor.
        do {
            _ = try await coordinator.bindTransportDiscontinuity(
                playbackToken: PlaybackTransportRescheduleToken(generation: 15, reason: .recovery)
            )
            preconditionFailure("wrong recovery route must poison generation 15")
        } catch PracticeDSPGenerationCoordinatorError.recoveryRequiresRecoveryPath { }
        let block7 = backend.armSnapshotBlock()
        let cancelledRecovery = Task {
            try await coordinator.recover(
                playbackToken: PlaybackTransportRescheduleToken(generation: 16, reason: .recovery)
            )
        }
        precondition(backend.waitUntilBlocked(block7))
        cancelledRecovery.cancel()
        backend.releaseBlockedSnapshot(block7)
        do {
            _ = try await cancelledRecovery.value
            preconditionFailure("cancelled recovery must not bind")
        } catch PracticeDSPGenerationCoordinatorError.operationCancelled { }
        authority = await coordinator.authoritySnapshot()
        precondition(authority.isPoisoned && authority.lastPlaybackGeneration == 16)
        recovery = try await coordinator.recover(
            playbackToken: PlaybackTransportRescheduleToken(generation: 17, reason: .recovery)
        )
        precondition(recovery.playbackGeneration == 17 && recovery.clickGeneration == 14)
        let finalBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: 17,
            clickGeneration: 14,
            reason: .recovery
        )
        try await coordinator.validateReplacement(binding: finalBinding)
        authority = await coordinator.authoritySnapshot()
        precondition(!authority.isPoisoned)
        precondition(!authority.operationInFlight)
        precondition(authority.pendingPlaybackGeneration == nil)
        precondition(authority.activeBinding == finalBinding)

        print("L3-AW15 coordinator concurrency/cancellation self-test PASS; click invalidations=\(invalidator.snapshot().count)")
    }
}
