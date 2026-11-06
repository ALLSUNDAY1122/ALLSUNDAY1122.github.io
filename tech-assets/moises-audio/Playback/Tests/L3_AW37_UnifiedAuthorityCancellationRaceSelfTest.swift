import Foundation

private actor AW37AuthorityPlaybackBackend: PlaybackBackendDriving {
    private var position = 0.0
    private var seekCount = 0

    func snapshotSeekCount() -> Int { seekCount }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}

    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        position = positionSeconds
    }

    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}

    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        // Keep the production authority in its executing state long enough for the Task cancellation
        // handler to race against dispatch/completion without sleeping on wall-clock time.
        for _ in 0..<4 { await Task.yield() }
        seekCount += 1
        position = positionSeconds
    }

    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        for _ in 0..<2 { await Task.yield() }
    }

    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }
}

private final class AW37AuthorityDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW37AuthorityClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generations: [UInt64] = []

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        generations.append(generation)
    }
}

@main
struct L3AW37UnifiedAuthorityCancellationRaceSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW37AuthorityPlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let controller = try PracticeDSPProductionController(
            projectID: project,
            backend: AW37AuthorityDSPBackend()
        )
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: AW37AuthorityClickInvalidator()
        )
        let authority = Lane3UnifiedProductionTransportAuthority(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: .zero,
                loopQuietPeriod: .zero,
                tempoQuietPeriod: .zero
            )
        )
        let adapter = try Lane3UnifiedTransportCancellationRaceAdapter(
            authority: authority,
            operation: .seek(
                basePositionSeconds: 0,
                stepSeconds: 0.001,
                resume: true,
                loop: nil
            )
        )

        let report = await Lane3CancellationRaceProbe.run(
            driver: adapter,
            policy: Lane3CancellationRaceProbePolicy(
                iterations: 5_000,
                batchSize: 64,
                postOperationSettlementYields: 32,
                quiescencePollLimit: 20_000
            )
        )

        precondition(report.iterations == 5_000)
        precondition(report.cancellationRequests == 3_750)
        precondition(report.accountingComplete)
        precondition(report.boundednessPass)
        precondition(report.finalSnapshot.isQuiescent)
        precondition(report.finalSnapshot.admittingTicketCount == 0)
        precondition(report.finalSnapshot.cancelledBeforeEnqueueTicketCount == 0)
        precondition(report.finalSnapshot.admissionInvariantHolds)
        precondition(!report.finalSnapshot.cancellationCounterOverflowed)
        precondition(!report.parityPromotionAllowed)

        let seekCount = await rawPlayback.snapshotSeekCount()
        precondition(seekCount == report.executed + report.failedAfterDispatch)

        let finalAuthority = await authority.snapshot()
        precondition(finalAuthority.pendingContinuousKinds.isEmpty)
        precondition(finalAuthority.pendingDiscreteKinds.isEmpty)
        precondition(!finalAuthority.executionInFlight)
        precondition(finalAuthority.cancellationAdmission.admittingTicketCount == 0)
        precondition(finalAuthority.cancellationAdmission.cancelledBeforeEnqueueTicketCount == 0)
        precondition(finalAuthority.cancellationAdmission.invariantHolds)

        print(
            "L3-AW37 actual authority cancellation race PASS iterations=\(report.iterations) "
            + "executed=\(report.executed) superseded=\(report.supersededBeforeToken) "
            + "cancelled=\(report.cancelledBeforeDispatch) late=\(report.lateRetiredCancellationDelta)"
        )
    }
}
