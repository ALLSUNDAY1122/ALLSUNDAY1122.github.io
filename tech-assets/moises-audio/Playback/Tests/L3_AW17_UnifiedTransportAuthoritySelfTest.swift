import Foundation

private actor AW17PlaybackBackend: PlaybackBackendDriving {
    struct ForcedFailure: Error {}
    private var failSeekCount = 0
    private var failPlayCount = 0
    private var seekCount = 0
    private var reasons: [PlaybackTransportDiscontinuityReason] = []
    private var position = 0.0

    func failNextSeek(_ count: Int = 1) { failSeekCount += count }
    func failNextPlay(_ count: Int = 1) { failPlayCount += count }
    func snapshot() -> (seekCount: Int, reasons: [PlaybackTransportDiscontinuityReason]) {
        (seekCount, reasons)
    }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {
        reasons.append(.mediaLoad)
    }

    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        reasons.append(.mediaReplacement)
        position = positionSeconds
    }

    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}

    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        seekCount += 1
        reasons.append(.seek)
        if failSeekCount > 0 {
            failSeekCount -= 1
            throw ForcedFailure()
        }
        position = positionSeconds
    }

    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        reasons.append(.loopChange)
    }

    func play(projectID: ProjectID) async throws {
        reasons.append(.play)
        if failPlayCount > 0 {
            failPlayCount -= 1
            throw ForcedFailure()
        }
    }

    func pause(projectID: ProjectID) async {
        reasons.append(.pause)
    }

    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }
}

private final class AW17DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW17ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
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
}

private func aw17WaitPending(
    _ authority: Lane3UnifiedProductionTransportAuthority,
    kind: Lane3UnifiedTransportKind
) async {
    for _ in 0..<2_000 {
        let snapshot = await authority.snapshot()
        if snapshot.pendingContinuousKinds.contains(kind) { return }
        await Task.yield()
    }
    preconditionFailure("pending intent not observed")
}

@main
struct L3AW17UnifiedTransportAuthoritySelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW17PlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let controller = try PracticeDSPProductionController(
            projectID: project,
            backend: AW17DSPBackend()
        )
        let invalidator = AW17ClickInvalidator()
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: invalidator
        )
        let authority = Lane3UnifiedProductionTransportAuthority(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: .milliseconds(8),
                loopQuietPeriod: .milliseconds(8),
                tempoQuietPeriod: .milliseconds(8)
            )
        )

        var executed = 0
        var superseded = 0
        await withTaskGroup(of: Lane3UnifiedTransportOutcome.self) { group in
            for index in 0..<500 {
                group.addTask {
                    await authority.submitSeek(to: Double(index), resume: true, loop: nil)
                }
            }
            for await result in group {
                switch result {
                case .executed: executed += 1
                case .supersededBeforeToken: superseded += 1
                default: preconditionFailure("rapid seek must execute latest or supersede")
                }
            }
        }
        precondition(executed == 1)
        precondition(superseded == 499)
        let firstBackendSnapshot = await rawPlayback.snapshot()
        precondition(firstBackendSnapshot.seekCount == 1)

        let orderedSeek = Task {
            await authority.submitSeek(to: 42, resume: true, loop: nil)
        }
        await aw17WaitPending(authority, kind: .seek)
        async let orderedPlay = authority.submitPlay()
        guard case let .executed(seekReceipt) = await orderedSeek.value,
              case let .executed(playReceipt) = await orderedPlay else {
            preconditionFailure("play barrier failed")
        }
        precondition(seekReceipt.playbackGeneration + 1 == playReceipt.playbackGeneration)

        let staleSeek = Task {
            await authority.submitSeek(to: 99, resume: true, loop: nil)
        }
        await aw17WaitPending(authority, kind: .seek)
        let beforeReplacement = await playback.rescheduleTokenSnapshot(projectID: project)
        let stem = StemArtifact(
            id: StemID(),
            projectID: project,
            role: .vocals,
            relativePath: "aw17/vocals.wav",
            sampleRate: 48_000,
            channels: 2,
            frameCount: 48_000
        )
        async let replacement = authority.submitMediaReplacement(
            stems: [stem],
            positionSeconds: 0,
            resume: false,
            loop: nil
        )
        guard case .supersededBeforeToken = await staleSeek.value,
              case let .executed(replacementReceipt) = await replacement else {
            preconditionFailure("media replacement barrier failed")
        }
        if let beforeReplacement {
            precondition(replacementReceipt.playbackGeneration == beforeReplacement.generation + 1)
        }

        let pendingTempo = Task { await authority.submitTempoRatio(1.25) }
        await aw17WaitPending(authority, kind: .tempo)
        let beforeInterruption = await playback.rescheduleTokenSnapshot(projectID: project)
        async let interruption = authority.submitInterruptionBegan()
        guard case .supersededBeforeToken = await pendingTempo.value,
              case let .executed(interruptionReceipt) = await interruption else {
            preconditionFailure("interruption barrier failed")
        }
        if let beforeInterruption {
            precondition(interruptionReceipt.playbackGeneration == beforeInterruption.generation + 1)
        }

        await rawPlayback.failNextPlay()
        let beforeFailure = await playback.rescheduleTokenSnapshot(projectID: project)!
        let failedPlay = await authority.submitPlay()
        guard case let .failedAfterDispatch(failure) = failedPlay else {
            preconditionFailure("forced play failure missing")
        }
        precondition(failure.playbackGeneration == beforeFailure.generation + 1)
        precondition(failure.automaticRecovery.succeeded)
        precondition(failure.automaticRecovery.playbackGeneration == beforeFailure.generation + 2)
        let postFailureSnapshot = await authority.snapshot()
        precondition(!postFailureSnapshot.recoveryBlocked)

        await rawPlayback.failNextSeek()
        invalidator.failNext(1)
        let blockedCause = await authority.submitSeek(to: 123, resume: true, loop: nil)
        guard case let .failedAfterDispatch(blockedFailure) = blockedCause else {
            preconditionFailure("blocked cause missing")
        }
        precondition(blockedFailure.automaticRecovery.attempted)
        precondition(!blockedFailure.automaticRecovery.succeeded)
        let blockedAuthoritySnapshot = await authority.snapshot()
        precondition(blockedAuthoritySnapshot.recoveryBlocked)
        let blockedToken = await playback.rescheduleTokenSnapshot(projectID: project)
        guard case .rejectedBeforeToken = await authority.submitPlay(),
              case .rejectedBeforeToken = await authority.submitTempoRatio(1.1) else {
            preconditionFailure("normal path bypassed recovery block")
        }
        let tokenAfterBlockedAttempts = await playback.rescheduleTokenSnapshot(projectID: project)
        precondition(tokenAfterBlockedAttempts == blockedToken)

        guard case let .executed(recoveryReceipt) = await authority.submitRecovery() else {
            preconditionFailure("explicit recovery failed")
        }
        precondition(recoveryReceipt.kind == .recovery)
        let recoveredAuthoritySnapshot = await authority.snapshot()
        precondition(!recoveredAuthoritySnapshot.recoveryBlocked)

        let tokenBeforeCancellation = await playback.rescheduleTokenSnapshot(projectID: project)
        let cancelled = Task {
            await authority.submitLoop(PlaybackLoopRange(startSeconds: 0, endSeconds: 4))
        }
        cancelled.cancel()
        guard case .cancelledBeforeDispatch = await cancelled.value else {
            preconditionFailure("pending cancellation must not dispatch")
        }
        let tokenAfterCancellation = await playback.rescheduleTokenSnapshot(projectID: project)
        precondition(tokenAfterCancellation == tokenBeforeCancellation)

        print("L3-AW17 unified transport authority self-test PASS")
    }
}
