import Foundation

private actor AW18PlaybackBackend: PlaybackBackendDriving {
    private var blockPlayCount = 0
    private var playEntries = 0
    private var playWaiters: [CheckedContinuation<Void, Never>] = []

    func blockNextPlay() { blockPlayCount += 1 }
    func playEntryCount() -> Int { playEntries }
    func releaseOnePlay() {
        guard !playWaiters.isEmpty else { return }
        playWaiters.removeFirst().resume()
    }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}

    func play(projectID: ProjectID) async throws {
        if blockPlayCount > 0 {
            blockPlayCount -= 1
            playEntries += 1
            await withCheckedContinuation { playWaiters.append($0) }
        }
    }

    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW18DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW18ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private struct ForcedFailure: Error {}
    private let lock = NSLock()
    private var failures = 0

    func failNext(_ count: Int) {
        lock.lock(); defer { lock.unlock() }
        failures += count
    }

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        if failures > 0 {
            failures -= 1
            throw ForcedFailure()
        }
    }
}

private func aw18TransportExecuted(_ outcome: Lane3InterruptionGuardedOutcome) -> Bool {
    guard case let .transport(transport) = outcome else { return false }
    if case .executed = transport { return true }
    return false
}

private func aw18WaitForPlayEntry(_ backend: AW18PlaybackBackend, atLeast: Int) async {
    for _ in 0..<10_000 {
        if await backend.playEntryCount() >= atLeast { return }
        await Task.yield()
    }
    preconditionFailure("blocked play was not observed")
}

@main
struct L3AW18InterruptionLifecycleSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW18PlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let controller = try PracticeDSPProductionController(projectID: project, backend: AW18DSPBackend())
        let invalidator = AW18ClickInvalidator()
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
                seekQuietPeriod: .milliseconds(2),
                loopQuietPeriod: .milliseconds(2),
                tempoQuietPeriod: .milliseconds(2)
            )
        )
        let gate = Lane3InterruptionLifecycleGate(authority: authority)

        let initialPlay = await gate.submitPlay()
        precondition(aw18TransportExecuted(initialPlay))
        guard case let .began(begin1) = await gate.submitInterruptionBegan() else {
            preconditionFailure("interruption begin failed")
        }
        precondition(begin1.resumeArmed && begin1.boundarySafe)

        let activeToken = await playback.rescheduleTokenSnapshot(projectID: project)
        guard case .rejectedBeforeTransport(_, .interruptionActive) = await gate.submitSeek(to: 3, resume: true, loop: nil),
              case .rejectedBeforeTransport(_, .interruptionActive) = await gate.submitTempoRatio(1.2) else {
            preconditionFailure("ordinary controls escaped active interruption")
        }
        let afterBlocked = await playback.rescheduleTokenSnapshot(projectID: project)
        precondition(afterBlocked == activeToken)

        guard case .resumeSuppressedWithoutToken = await gate.submitPause() else {
            preconditionFailure("pause did not suppress resume without token")
        }
        let afterPauseIntent = await playback.rescheduleTokenSnapshot(projectID: project)
        precondition(afterPauseIntent == activeToken)
        guard case let .ended(end1) = await gate.submitInterruptionEnded(shouldResume: true) else {
            preconditionFailure("interruption end failed")
        }
        precondition(end1.boundarySafe && !end1.resumedPlayback && end1.resumeOutcome == nil)

        let play2 = await gate.submitPlay()
        precondition(aw18TransportExecuted(play2))
        _ = await gate.submitInterruptionBegan()
        guard case let .ended(noOSResume) = await gate.submitInterruptionEnded(shouldResume: false) else {
            preconditionFailure("shouldResume=false end failed")
        }
        precondition(!noOSResume.resumedPlayback && noOSResume.resumeOutcome == nil)

        let play3 = await gate.submitPlay()
        precondition(aw18TransportExecuted(play3))
        _ = await gate.submitInterruptionBegan()
        guard case let .ended(autoResume) = await gate.submitInterruptionEnded(shouldResume: true) else {
            preconditionFailure("auto resume end failed")
        }
        precondition(autoResume.resumedPlayback && autoResume.resumeOutcome != nil)

        // Interruption begin must wait for an older in-flight play before capturing resume intent.
        _ = await gate.submitPause()
        await rawPlayback.blockNextPlay()
        let entry0 = await rawPlayback.playEntryCount()
        let oldPlay = Task { await gate.submitPlay() }
        await aw18WaitForPlayEntry(rawPlayback, atLeast: entry0 + 1)
        let beginTask = Task { await gate.submitInterruptionBegan() }
        for _ in 0..<100 { await Task.yield() }
        let beginningSnapshot = await gate.snapshot()
        precondition(beginningSnapshot.phase == .beginning)
        await rawPlayback.releaseOnePlay()
        let oldPlayResult = await oldPlay.value
        precondition(aw18TransportExecuted(oldPlayResult))
        guard case let .began(orderedBegin) = await beginTask.value else {
            preconditionFailure("ordered begin failed")
        }
        precondition(orderedBegin.resumeArmed)
        _ = await gate.submitInterruptionEnded(shouldResume: false)

        // Pause while resume token is in flight must issue a compensating pause through AW17.
        let play4 = await gate.submitPlay()
        precondition(aw18TransportExecuted(play4))
        _ = await gate.submitInterruptionBegan()
        await rawPlayback.blockNextPlay()
        let entry1 = await rawPlayback.playEntryCount()
        let endTask = Task { await gate.submitInterruptionEnded(shouldResume: true) }
        await aw18WaitForPlayEntry(rawPlayback, atLeast: entry1 + 1)
        guard case .resumeSuppressedWithoutToken = await gate.submitPause() else {
            preconditionFailure("resume suppression during resuming failed")
        }
        await rawPlayback.releaseOnePlay()
        guard case let .ended(suppressedResume) = await endTask.value else {
            preconditionFailure("suppressed resume end failed")
        }
        precondition(!suppressedResume.resumedPlayback)
        precondition(suppressedResume.compensatingPauseOutcome != nil)

        // A newer interruption during resume stale-marks the older end continuation.
        let play5 = await gate.submitPlay()
        precondition(aw18TransportExecuted(play5))
        _ = await gate.submitInterruptionBegan()
        await rawPlayback.blockNextPlay()
        let entry2 = await rawPlayback.playEntryCount()
        let oldEnd = Task { await gate.submitInterruptionEnded(shouldResume: true) }
        await aw18WaitForPlayEntry(rawPlayback, atLeast: entry2 + 1)
        let newBegin = Task { await gate.submitInterruptionBegan() }
        await rawPlayback.releaseOnePlay()
        guard case let .ended(staleEnd) = await oldEnd.value,
              case let .began(newerBegin) = await newBegin.value else {
            preconditionFailure("nested interruption race failed")
        }
        precondition(staleEnd.supersededByNewerLifecycleEvent)
        precondition(newerBegin.boundarySafe)
        let nestedSnapshot = await gate.snapshot()
        precondition(nestedSnapshot.phase == .active)
        _ = await gate.submitInterruptionEnded(shouldResume: false)

        // Force end binding and its automatic recovery to fail. Gate must retain a recovery-only state.
        let play6 = await gate.submitPlay()
        precondition(aw18TransportExecuted(play6))
        _ = await gate.submitInterruptionBegan()
        invalidator.failNext(2)
        guard case let .ended(recoveryRequired) = await gate.submitInterruptionEnded(shouldResume: true) else {
            preconditionFailure("forced end failure missing")
        }
        precondition(recoveryRequired.recoveryRequired)
        let blockedSnapshot = await gate.snapshot()
        precondition(blockedSnapshot.phase == .endedRecoveryRequired)
        let blockedToken = await playback.rescheduleTokenSnapshot(projectID: project)
        guard case .rejectedBeforeTransport(_, .recoveryRequiredAfterInterruptionEnd) = await gate.submitPlay() else {
            preconditionFailure("normal command bypassed endedRecoveryRequired")
        }
        let tokenWhileBlocked = await playback.rescheduleTokenSnapshot(projectID: project)
        precondition(tokenWhileBlocked == blockedToken)
        guard case let .ended(recoveredEnd) = await gate.retryEndedInterruptionRecovery() else {
            preconditionFailure("ended interruption recovery retry failed")
        }
        precondition(!recoveredEnd.recoveryRequired && recoveredEnd.resumedPlayback)
        let finalSnapshot = await gate.snapshot()
        precondition(finalSnapshot.phase == .idle)

        print("L3-AW18 interruption lifecycle self-test PASS")
    }
}
