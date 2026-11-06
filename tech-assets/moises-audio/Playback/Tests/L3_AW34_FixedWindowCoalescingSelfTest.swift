import Foundation

private actor AW34PlaybackBackend: PlaybackBackendDriving {
    private var seekCount = 0
    private var loopCount = 0
    private var playCount = 0
    private var position = 0.0

    func snapshot() -> (seekCount: Int, loopCount: Int, playCount: Int, position: Double) {
        (seekCount, loopCount, playCount, position)
    }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws { position = positionSeconds }
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        seekCount += 1
        position = positionSeconds
    }
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws { loopCount += 1 }
    func play(projectID: ProjectID) async throws { playCount += 1 }
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }
}

private final class AW34DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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
        PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW34ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

private func aw34WaitPending(
    _ authority: Lane3UnifiedProductionTransportAuthority,
    kind: Lane3UnifiedTransportKind
) async {
    for _ in 0..<4_000 {
        let snapshot = await authority.snapshot()
        if snapshot.pendingContinuousKinds.contains(kind) { return }
        await Task.yield()
    }
    preconditionFailure("AW34 pending intent not observed")
}

@main
struct L3AW34FixedWindowCoalescingSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW34PlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let controller = try PracticeDSPProductionController(
            projectID: project,
            backend: AW34DSPBackend()
        )
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: AW34ClickInvalidator()
        )
        let authority = Lane3UnifiedProductionTransportAuthority(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: .milliseconds(8),
                loopQuietPeriod: .milliseconds(8),
                tempoQuietPeriod: .zero
            )
        )

        // A 2ms seek stream lasts roughly 96ms. The old resettable debounce could not execute until
        // the stream ended because every replacement restarted the 8ms timer. AW34 must dispatch
        // window winners while the producer is still active.
        let stream = Task { () -> [Lane3UnifiedTransportOutcome] in
            await withTaskGroup(
                of: Lane3UnifiedTransportOutcome.self,
                returning: [Lane3UnifiedTransportOutcome].self
            ) { group in
                for index in 0..<48 {
                    group.addTask {
                        await authority.submitSeek(
                            to: Double(index),
                            resume: true,
                            loop: nil
                        )
                    }
                    try? await Task.sleep(for: .milliseconds(2))
                }
                var results: [Lane3UnifiedTransportOutcome] = []
                results.reserveCapacity(48)
                for await result in group { results.append(result) }
                return results
            }
        }

        try? await Task.sleep(for: .milliseconds(30))
        let duringStream = await rawPlayback.snapshot()
        precondition(
            duringStream.seekCount >= 1,
            "fixed-window authority starved while continuous seek stream was active"
        )

        let streamResults = await stream.value
        var executedSeek = 0
        var supersededSeek = 0
        for result in streamResults {
            switch result {
            case .executed:
                executedSeek += 1
            case .supersededBeforeToken:
                supersededSeek += 1
            default:
                preconditionFailure("paced seek must execute a window winner or supersede")
            }
        }
        precondition(executedSeek >= 2)
        precondition(executedSeek + supersededSeek == 48)
        let afterStream = await rawPlayback.snapshot()
        precondition(afterStream.seekCount == executedSeek)

        // Play remains a flush barrier: it may shorten the current window, but seek still executes
        // before the later discrete token and the original timer cannot fire a duplicate afterward.
        let pendingSeek = Task {
            await authority.submitSeek(to: 77, resume: true, loop: nil)
        }
        await aw34WaitPending(authority, kind: .seek)
        async let play = authority.submitPlay()
        guard case let .executed(seekReceipt) = await pendingSeek.value,
              case let .executed(playReceipt) = await play else {
            preconditionFailure("AW34 play flush barrier failed")
        }
        precondition(seekReceipt.playbackGeneration + 1 == playReceipt.playbackGeneration)
        try? await Task.sleep(for: .milliseconds(12))
        let afterBarrier = await rawPlayback.snapshot()
        precondition(afterBarrier.seekCount == executedSeek + 1)
        precondition(afterBarrier.playCount == 1)

        // Cancelling the current pending winner must cancel its window. A new loop afterwards must
        // open a fresh window rather than inheriting a dead/cancelled wake task.
        let cancelledLoop = Task {
            await authority.submitLoop(PlaybackLoopRange(startSeconds: 0, endSeconds: 4))
        }
        await aw34WaitPending(authority, kind: .loop)
        cancelledLoop.cancel()
        guard case .cancelledBeforeDispatch = await cancelledLoop.value else {
            preconditionFailure("AW34 pending loop cancellation dispatched a token")
        }
        let loopBeforeRetry = await rawPlayback.snapshot().loopCount
        guard case .executed = await authority.submitLoop(
            PlaybackLoopRange(startSeconds: 1, endSeconds: 5)
        ) else {
            preconditionFailure("fresh loop window did not reopen after cancellation")
        }
        let loopAfterRetry = await rawPlayback.snapshot().loopCount
        precondition(loopAfterRetry == loopBeforeRetry + 1)

        let finalToken = await playback.rescheduleTokenSnapshot(projectID: project)
        precondition(finalToken != nil)
        print(
            "L3-AW34 fixed-window coalescing self-test PASS "
            + "executedSeek=\(executedSeek) supersededSeek=\(supersededSeek)"
        )
    }
}
