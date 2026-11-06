import Dispatch
import Foundation

private actor AW39PlaybackBackend: PlaybackBackendDriving, PlaybackTempoBoundaryRescheduling, Lane3SelectedStackRecoveryReporting {
    struct ForcedFailure: Error {}

    private var position = 0.0
    private var currentTempo = 1.0
    private var loop: PlaybackLoopRange?
    private var boundarySerial: UInt64 = 0
    private var failCommit = false
    private var poisoned = false

    func forceNextCommitFailure() { failCommit = true }
    func selectedStackRequiresReconstruction() async -> Bool { poisoned }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {
        position = positionSeconds
        self.loop = loop
    }
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {
        position = positionSeconds
        self.loop = loop
    }
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        self.loop = loop
    }
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }

    func prepareTempoBoundary(projectID: ProjectID, toTempoRatio: Double) async throws -> PlaybackTempoBoundaryReceipt {
        boundarySerial += 1
        return PlaybackTempoBoundaryReceipt(
            serial: boundarySerial,
            fromTempoRatio: currentTempo,
            toTempoRatio: toTempoRatio,
            capturedProjectPositionSeconds: position,
            loop: loop,
            resumeWasPlaying: false,
            backendScheduleGeneration: boundarySerial
        )
    }

    func commitTempoBoundary(projectID: ProjectID, receipt: PlaybackTempoBoundaryReceipt) async throws {
        if failCommit {
            failCommit = false
            poisoned = true
            throw ForcedFailure()
        }
        currentTempo = receipt.toTempoRatio
    }

    func cancelTempoBoundary(projectID: ProjectID, receipt: PlaybackTempoBoundaryReceipt) async throws {
        currentTempo = receipt.fromTempoRatio
    }
}

private final class AW39DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW39ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

private struct AW39SelectedFixture {
    let backend: AW39PlaybackBackend
    let playback: RescheduleFencedPlaybackBackend
    let facade: Lane3TempoBoundarySelectedTransportFacade
}

private func makeAW39Fixture(project: ProjectID) throws -> AW39SelectedFixture {
    let backend = AW39PlaybackBackend()
    let playback = RescheduleFencedPlaybackBackend(backend: backend)
    let controller = try PracticeDSPProductionController(projectID: project, backend: AW39DSPBackend())
    let coordinator = PracticeDSPGenerationCoordinator(
        projectID: project,
        controller: controller,
        clickInvalidator: AW39ClickInvalidator()
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
    let lifecycle = Lane3InterruptionLifecycleGate(authority: authority)
    let instrumented = Lane3InstrumentedInterruptionGate(
        gate: lifecycle,
        telemetry: Lane3ProductionTelemetryCollector()
    )
    let practice = Lane3PracticeInterruptionClickGate(
        transport: instrumented,
        coordinator: coordinator
    )
    let serializedClick = Lane3SerializedPracticeClickGate(
        practiceGate: practice,
        coordinator: coordinator
    )
    let facade = Lane3TempoBoundarySelectedTransportFacade(
        projectID: project,
        transportGate: lifecycle,
        serializedClickGate: serializedClick,
        tempoBackend: backend,
        tempoQuietPeriod: .zero
    )
    return AW39SelectedFixture(backend: backend, playback: playback, facade: facade)
}

@main
struct L3AW39SelectedLeaseGenerationSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let initial = try makeAW39Fixture(project: project)
        let slot = Lane3SelectedTransportReconstructionSlot(initialFacade: initial.facade)
        let adapter = Lane3SelectedInteractiveContinuityInstrumentationAdapter(
            projectID: project,
            playback: initial.playback
        )

        let firstIntent = DispatchTime.now().uptimeNanoseconds
        let stampedSeek = try await slot.submitSeekStamped(
            to: 9,
            resume: false,
            loop: nil
        )
        precondition(stampedSeek.slotGeneration == 1)
        precondition(!stampedSeek.parityPromotionAllowed)
        guard case .transport(.executed(let seekReceipt)) = stampedSeek.outcome else {
            preconditionFailure("stamped seek did not execute")
        }
        precondition(seekReceipt.kind == .seek)

        // Force a later, unrelated failure and reconstruct before correlating the already-completed
        // seek. An external completion snapshot would now see generation 2 and could falsely make the
        // generation-1 seek look cross-generation; the stamped receipt must remain generation 1.
        await initial.backend.forceNextCommitFailure()
        do {
            _ = try await slot.submitTempoRatio(1.25)
            preconditionFailure("forced tempo commit failure unexpectedly succeeded")
        } catch Lane3TempoBoundarySelectedTransportError.tempoBoundaryCommitFailed {
        }
        let poisoned = await slot.snapshot()
        guard let ticket = poisoned.pendingRecoveryTicket else {
            preconditionFailure("recovery ticket missing")
        }

        let replacement = try makeAW39Fixture(project: project)
        let replacementReceipt = try await slot.installReconstructedFacade(
            replacement.facade,
            expectedTicket: ticket
        )
        precondition(replacementReceipt.oldSlotGeneration == 1)
        precondition(replacementReceipt.newSlotGeneration == 2)
        let afterReplacement = await slot.snapshot()
        precondition(afterReplacement.slotGeneration == 2)
        precondition(stampedSeek.slotGeneration == 1)

        let correlated = await adapter.correlateLeaseStamped(
            sampleID: 1,
            stamped: stampedSeek,
            firstIntentUptimeNanoseconds: firstIntent,
            requestedTarget: .seek(positionSeconds: 9),
            audibleResultUptimeNanoseconds: nil,
            audibleTimestampSource: nil
        )
        guard case .instrumented(let seekInstrumentation) = correlated,
              let seekObservation = seekInstrumentation.observation else {
            preconditionFailure("stamped seek failed AW38 correlation")
        }
        precondition(seekInstrumentation.issues.isEmpty)
        precondition(seekObservation.slotGenerationAtIntent == 1)
        precondition(seekObservation.slotGenerationAtCompletion == 1)
        precondition(seekObservation.playbackGeneration == seekReceipt.playbackGeneration)
        precondition(seekObservation.requestedTarget == .seek(positionSeconds: 9))
        precondition(seekObservation.appliedTarget == .seek(positionSeconds: 9))

        let replacementAdapter = Lane3SelectedInteractiveContinuityInstrumentationAdapter(
            projectID: project,
            playback: replacement.playback
        )
        let loopIntent = DispatchTime.now().uptimeNanoseconds
        let stampedLoopDisable = try await slot.submitLoopStamped(nil)
        precondition(stampedLoopDisable.slotGeneration == 2)
        let loopCorrelation = await replacementAdapter.correlateLeaseStamped(
            sampleID: 2,
            stamped: stampedLoopDisable,
            firstIntentUptimeNanoseconds: loopIntent,
            requestedTarget: .loopDisabled,
            audibleResultUptimeNanoseconds: nil,
            audibleTimestampSource: nil
        )
        guard case .instrumented(let loopInstrumentation) = loopCorrelation,
              let loopObservation = loopInstrumentation.observation else {
            preconditionFailure("loop disable failed stamped correlation")
        }
        precondition(loopObservation.slotGenerationAtIntent == 2)
        precondition(loopObservation.slotGenerationAtCompletion == 2)
        precondition(loopObservation.requestedTarget == .loopDisabled)
        precondition(loopObservation.appliedTarget == .loopDisabled)
        precondition(loopInstrumentation.issues.contains { $0.kind == .legacyAW35CannotRepresentLoopDisabled })
        precondition(!loopInstrumentation.legacyAW35ObservationAvailable)

        let rejected = Lane3SelectedTransportGenerationStampedOutcome(
            slotGeneration: 7,
            outcome: .rejectedBeforeTransport(kind: .seek, reason: .interruptionActive)
        )
        let rejectedCorrelation = await replacementAdapter.correlateLeaseStamped(
            sampleID: 3,
            stamped: rejected,
            firstIntentUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            requestedTarget: .seek(positionSeconds: 1),
            audibleResultUptimeNanoseconds: nil,
            audibleTimestampSource: nil
        )
        guard case .nonExecuted(let generation, let outcome) = rejectedCorrelation else {
            preconditionFailure("non-executed selected outcome was fabricated into executed evidence")
        }
        precondition(generation == 7)
        precondition(outcome == rejected.outcome)

        print(
            "L3-AW39 selected lease generation PASS old=\(stampedSeek.slotGeneration) "
                + "current=\(afterReplacement.slotGeneration) loop=\(stampedLoopDisable.slotGeneration) "
                + "nonExecutedPreserved=1"
        )
    }
}
