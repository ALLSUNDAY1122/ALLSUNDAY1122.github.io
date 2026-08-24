import Foundation

private actor AW31PlaybackBoundaryBackend: PlaybackBackendDriving, PlaybackTempoBoundaryRescheduling {
    struct Snapshot: Sendable {
        let prepares: Int
        let commits: Int
        let cancels: Int
        let currentTempo: Double
        let events: [String]
    }

    private var position = 0.0
    private var currentTempo = 1.0
    private var nextBoundarySerial: UInt64 = 0
    private var prepares = 0
    private var commits = 0
    private var cancels = 0
    private var events: [String] = []
    private var seekDelay: Duration = .zero

    func setSeekDelay(_ value: Duration) { seekDelay = value }

    func snapshot() -> Snapshot {
        Snapshot(
            prepares: prepares,
            commits: commits,
            cancels: cancels,
            currentTempo: currentTempo,
            events: events
        )
    }

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
        events.append("seek-start")
        try? await Task.sleep(for: seekDelay)
        position = positionSeconds
        events.append("seek-end")
    }

    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }

    func prepareTempoBoundary(
        projectID: ProjectID,
        toTempoRatio: Double
    ) async throws -> PlaybackTempoBoundaryReceipt {
        nextBoundarySerial += 1
        prepares += 1
        events.append("tempo-prepare")
        return PlaybackTempoBoundaryReceipt(
            serial: nextBoundarySerial,
            fromTempoRatio: currentTempo,
            toTempoRatio: toTempoRatio,
            capturedProjectPositionSeconds: position,
            loop: nil,
            resumeWasPlaying: true,
            backendScheduleGeneration: UInt64(prepares)
        )
    }

    func commitTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws {
        currentTempo = receipt.toTempoRatio
        commits += 1
        events.append("tempo-commit")
    }

    func cancelTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws {
        currentTempo = receipt.fromTempoRatio
        cancels += 1
        events.append("tempo-cancel")
    }
}

private final class AW31DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    struct ForcedFailure: Error {}
    private let lock = NSLock()
    private var tempo = 1.0
    private var pitch = 0.0
    private var failNext = false

    func failNextApply() {
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

private final class AW31ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64] = []

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        values.append(generation)
    }
}

private func makeAW31Facade(
    project: ProjectID,
    rawPlayback: AW31PlaybackBoundaryBackend,
    dspBackend: AW31DSPBackend
) throws -> (
    facade: Lane3TempoBoundarySelectedTransportFacade,
    playback: RescheduleFencedPlaybackBackend,
    lifecycle: Lane3InterruptionLifecycleGate
) {
    let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
    let controller = try PracticeDSPProductionController(
        projectID: project,
        backend: dspBackend
    )
    let coordinator = PracticeDSPGenerationCoordinator(
        projectID: project,
        controller: controller,
        clickInvalidator: AW31ClickInvalidator()
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
    let telemetry = Lane3ProductionTelemetryCollector()
    let instrumented = Lane3InstrumentedInterruptionGate(
        gate: lifecycle,
        telemetry: telemetry
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
        tempoBackend: rawPlayback,
        tempoQuietPeriod: .milliseconds(3)
    )
    return (facade, playback, lifecycle)
}

@main
struct L3AW31TempoBoundarySelectedFacadeSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawPlayback = AW31PlaybackBoundaryBackend()
        let dspBackend = AW31DSPBackend()
        let stack = try makeAW31Facade(
            project: project,
            rawPlayback: rawPlayback,
            dspBackend: dspBackend
        )

        var executed = 0
        var superseded = 0
        await withTaskGroup(of: Lane3TempoBoundarySelectedOutcome?.self) { group in
            for index in 0..<200 {
                group.addTask {
                    try? await stack.facade.submitTempoRatio(0.75 + Double(index) / 400.0)
                }
            }
            for await result in group {
                guard let result else { preconditionFailure("tempo submission threw") }
                switch result {
                case .transport(let guarded, let boundary):
                    guard case .transport(.executed) = guarded else {
                        preconditionFailure("latest tempo did not execute")
                    }
                    precondition(boundary != nil)
                    executed += 1
                case .supersededBeforeBoundary:
                    superseded += 1
                case .cancelledBeforeBoundary:
                    preconditionFailure("unexpected cancellation")
                }
            }
        }
        precondition(executed == 1)
        precondition(superseded == 199)
        var raw = await rawPlayback.snapshot()
        precondition(raw.prepares == 1)
        precondition(raw.commits == 1)
        precondition(raw.cancels == 0)
        let tokenAfterRapidTempo = await stack.playback.rescheduleTokenSnapshot(projectID: project)
        precondition(tokenAfterRapidTempo?.generation == 1)
        precondition(tokenAfterRapidTempo?.reason == .tempoChange)

        dspBackend.failNextApply()
        let failed = try await stack.facade.submitTempoRatio(1.1)
        guard case let .transport(guarded, boundary) = failed,
              boundary != nil,
              case .transport(.failedAfterDispatch) = guarded else {
            preconditionFailure("forced DSP failure did not fail selected tempo route")
        }
        raw = await rawPlayback.snapshot()
        precondition(raw.prepares == 2)
        precondition(raw.commits == 1)
        precondition(raw.cancels == 1)

        await rawPlayback.setSeekDelay(.milliseconds(20))
        let seek = Task {
            try await stack.facade.submitSeek(to: 12, resume: true, loop: nil)
        }
        try? await Task.sleep(for: .milliseconds(2))
        let orderedTempo = Task {
            try await stack.facade.submitTempoRatio(1.25)
        }
        _ = try await seek.value
        _ = try await orderedTempo.value
        raw = await rawPlayback.snapshot()
        guard let seekEnd = raw.events.lastIndex(of: "seek-end"),
              let finalPrepare = raw.events.lastIndex(of: "tempo-prepare") else {
            preconditionFailure("ordering events missing")
        }
        precondition(seekEnd < finalPrepare)

        let beforeActiveBoundary = await rawPlayback.snapshot().prepares
        let began = await stack.lifecycle.submitInterruptionBegan()
        guard case .began = began else { preconditionFailure("interruption begin failed") }
        let blocked = try await stack.facade.submitTempoRatio(0.9)
        guard case let .transport(guarded, boundary) = blocked,
              boundary == nil,
              case .rejectedBeforeTransport(kind: .tempo, reason: .interruptionActive) = guarded else {
            preconditionFailure("active interruption must reject before Playback tempo boundary")
        }
        precondition(await rawPlayback.snapshot().prepares == beforeActiveBoundary)

        print(
            "L3-AW31 facade PASS executed=\(executed) superseded=\(superseded) "
                + "prepares=\(raw.prepares) commits=\(raw.commits) cancels=\(raw.cancels)"
        )
    }
}
