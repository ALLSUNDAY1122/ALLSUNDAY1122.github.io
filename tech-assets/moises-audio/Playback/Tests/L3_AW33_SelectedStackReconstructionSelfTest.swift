import Foundation

private actor AW33PlaybackBackend: PlaybackBackendDriving, PlaybackTempoBoundaryRescheduling, Lane3SelectedStackRecoveryReporting {
    struct ForcedFailure: Error {}

    struct Snapshot: Sendable {
        let prepares: Int
        let commits: Int
        let cancels: Int
        let seeks: Int
        let poisoned: Bool
    }

    private var position = 0.0
    private var currentTempo = 1.0
    private var boundarySerial: UInt64 = 0
    private var prepares = 0
    private var commits = 0
    private var cancels = 0
    private var seeks = 0
    private var failCommit = false
    private var failCancel = false
    private var poisonSeek = false
    private var poisoned = false

    func forceNextCommitFailure() { failCommit = true }
    func forceNextCancelFailure() { failCancel = true }
    func forceNextSeekPoison() { poisonSeek = true }
    func selectedStackRequiresReconstruction() async -> Bool { poisoned }

    func snapshot() -> Snapshot {
        Snapshot(prepares: prepares, commits: commits, cancels: cancels, seeks: seeks, poisoned: poisoned)
    }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {
        position = positionSeconds
    }
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {
        seeks += 1
        if poisonSeek {
            poisonSeek = false
            poisoned = true
            throw ForcedFailure()
        }
        position = positionSeconds
    }
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }

    func prepareTempoBoundary(projectID: ProjectID, toTempoRatio: Double) async throws -> PlaybackTempoBoundaryReceipt {
        boundarySerial += 1
        prepares += 1
        return PlaybackTempoBoundaryReceipt(
            serial: boundarySerial,
            fromTempoRatio: currentTempo,
            toTempoRatio: toTempoRatio,
            capturedProjectPositionSeconds: position,
            loop: nil,
            resumeWasPlaying: true,
            backendScheduleGeneration: UInt64(prepares)
        )
    }

    func commitTempoBoundary(projectID: ProjectID, receipt: PlaybackTempoBoundaryReceipt) async throws {
        if failCommit {
            failCommit = false
            poisoned = true
            throw ForcedFailure()
        }
        currentTempo = receipt.toTempoRatio
        commits += 1
    }

    func cancelTempoBoundary(projectID: ProjectID, receipt: PlaybackTempoBoundaryReceipt) async throws {
        if failCancel {
            failCancel = false
            poisoned = true
            throw ForcedFailure()
        }
        currentTempo = receipt.fromTempoRatio
        cancels += 1
    }
}

private final class AW33DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    struct ForcedFailure: Error {}
    private let lock = NSLock()
    private var tempo = 1.0
    private var pitch = 0.0
    private var failNext = false

    func forceNextApplyFailure() {
        lock.lock(); defer { lock.unlock() }
        failNext = true
    }

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        if failNext {
            failNext = false
            throw ForcedFailure()
        }
        tempo = tempoRatio
        pitch = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        lock.lock(); defer { lock.unlock() }
        return PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW33ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

private func makeAW33Facade(
    project: ProjectID,
    playbackBackend: AW33PlaybackBackend,
    dspBackend: AW33DSPBackend = AW33DSPBackend()
) throws -> Lane3TempoBoundarySelectedTransportFacade {
    let playback = RescheduleFencedPlaybackBackend(backend: playbackBackend)
    let controller = try PracticeDSPProductionController(projectID: project, backend: dspBackend)
    let coordinator = PracticeDSPGenerationCoordinator(
        projectID: project,
        controller: controller,
        clickInvalidator: AW33ClickInvalidator()
    )
    let authority = Lane3UnifiedProductionTransportAuthority(
        projectID: project,
        playback: playback,
        coordinator: coordinator,
        policy: Lane3UnifiedTransportPolicy(seekQuietPeriod: .zero, loopQuietPeriod: .zero, tempoQuietPeriod: .zero)
    )
    let lifecycle = Lane3InterruptionLifecycleGate(authority: authority)
    let instrumented = Lane3InstrumentedInterruptionGate(gate: lifecycle, telemetry: Lane3ProductionTelemetryCollector())
    let practice = Lane3PracticeInterruptionClickGate(transport: instrumented, coordinator: coordinator)
    let serializedClick = Lane3SerializedPracticeClickGate(practiceGate: practice, coordinator: coordinator)
    return Lane3TempoBoundarySelectedTransportFacade(
        projectID: project,
        transportGate: lifecycle,
        serializedClickGate: serializedClick,
        tempoBackend: playbackBackend,
        tempoQuietPeriod: .zero
    )
}

private func requireReconstruction(_ error: Error) -> Lane3SelectedTransportRecoveryTicket {
    guard case let Lane3TempoBoundarySelectedTransportError.stackReconstructionRequired(ticket) = error else {
        preconditionFailure("expected stackReconstructionRequired, got \(error)")
    }
    return ticket
}

@main
struct L3AW33SelectedStackReconstructionSelfTest {
    static func main() async throws {
        let project = ProjectID()

        let failedBackend = AW33PlaybackBackend()
        let failedFacade = try makeAW33Facade(project: project, playbackBackend: failedBackend)
        let slot = Lane3SelectedTransportReconstructionSlot(initialFacade: failedFacade)
        await failedBackend.forceNextCommitFailure()
        do {
            _ = try await slot.submitTempoRatio(1.25)
            preconditionFailure("forced commit failure unexpectedly succeeded")
        } catch Lane3TempoBoundarySelectedTransportError.tempoBoundaryCommitFailed {
        }

        var slotSnapshot = await slot.snapshot()
        guard let commitTicket = slotSnapshot.pendingRecoveryTicket else {
            preconditionFailure("commit failure did not surface reconstruction ticket")
        }
        precondition(commitTicket.reason == .tempoBoundaryCommitFailure)
        let beforeRejectedSeek = await failedBackend.snapshot()
        do {
            _ = try await slot.submitSeek(to: 9, resume: true, loop: nil)
            preconditionFailure("poisoned slot reused old facade")
        } catch {
            _ = requireReconstruction(error)
        }
        let afterRejectedSeek = await failedBackend.snapshot()
        precondition(afterRejectedSeek.seeks == beforeRejectedSeek.seeks)

        let replacementBackend = AW33PlaybackBackend()
        let replacementFacade = try makeAW33Facade(project: project, playbackBackend: replacementBackend)
        let stale = Lane3SelectedTransportRecoveryTicket(
            reason: commitTicket.reason,
            failedTempoSerial: commitTicket.failedTempoSerial &+ 1,
            failedBoundarySerial: commitTicket.failedBoundarySerial
        )
        do {
            _ = try await slot.installReconstructedFacade(replacementFacade, expectedTicket: stale)
            preconditionFailure("stale recovery ticket replaced selected facade")
        } catch Lane3SelectedTransportReconstructionSlotError.staleRecoveryTicket {
        }
        slotSnapshot = await slot.snapshot()
        precondition(slotSnapshot.slotGeneration == 1)
        precondition(slotSnapshot.pendingRecoveryTicket == commitTicket)

        let receipt = try await slot.installReconstructedFacade(replacementFacade, expectedTicket: commitTicket)
        precondition(receipt.oldSlotGeneration == 1)
        precondition(receipt.newSlotGeneration == 2)
        precondition(!receipt.oldFacadeReused)
        precondition(!receipt.parityPromotionAllowed)
        slotSnapshot = await slot.snapshot()
        precondition(slotSnapshot.slotGeneration == 2)
        precondition(slotSnapshot.pendingRecoveryTicket == nil)
        _ = try await slot.submitSeek(to: 11, resume: true, loop: nil)
        let replacementSnapshot = await replacementBackend.snapshot()
        precondition(replacementSnapshot.seeks == 1)

        do {
            _ = try await failedFacade.submitPlay()
            preconditionFailure("old facade was reset in place")
        } catch {
            _ = requireReconstruction(error)
        }

        let seekPoisonBackend = AW33PlaybackBackend()
        let seekPoisonFacade = try makeAW33Facade(project: ProjectID(), playbackBackend: seekPoisonBackend)
        let seekPoisonSlot = Lane3SelectedTransportReconstructionSlot(initialFacade: seekPoisonFacade)
        await seekPoisonBackend.forceNextSeekPoison()
        do {
            _ = try await seekPoisonSlot.submitSeek(to: 3, resume: true, loop: nil)
            preconditionFailure("poisoning seek unexpectedly succeeded")
        } catch {
            let ticket = requireReconstruction(error)
            precondition(ticket.reason == .playbackBoundaryBackendPoisoned)
        }
        let seekPoisonSnapshot = await seekPoisonSlot.snapshot()
        precondition(seekPoisonSnapshot.pendingRecoveryTicket?.reason == .playbackBoundaryBackendPoisoned)

        let cancelBackend = AW33PlaybackBackend()
        let cancelDSP = AW33DSPBackend()
        let cancelFacade = try makeAW33Facade(project: ProjectID(), playbackBackend: cancelBackend, dspBackend: cancelDSP)
        let cancelSlot = Lane3SelectedTransportReconstructionSlot(initialFacade: cancelFacade)
        await cancelBackend.forceNextCancelFailure()
        cancelDSP.forceNextApplyFailure()
        do {
            _ = try await cancelSlot.submitTempoRatio(0.9)
            preconditionFailure("forced cancel failure unexpectedly succeeded")
        } catch Lane3TempoBoundarySelectedTransportError.tempoBoundaryCancelFailed {
        }
        let cancelSnapshot = await cancelSlot.snapshot()
        precondition(cancelSnapshot.pendingRecoveryTicket?.reason == .tempoBoundaryCancelFailure)

        print(
            "L3-AW33 recovery PASS generation=\(slotSnapshot.slotGeneration) "
                + "commitTicket=\(commitTicket.failedTempoSerial) staleRejected=1 "
                + "seekPoison=1 cancelFailure=1"
        )
    }
}
