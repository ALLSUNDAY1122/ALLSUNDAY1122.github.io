import Foundation

private final class AW23PlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private enum AW23BackendError: Error { case injected }

private final class AW23DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var tempo = 1.0
    private var pitch = 0.0
    private var failAllApplies = false

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        if failAllApplies { throw AW23BackendError.injected }
        tempo = tempoRatio
        pitch = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        lock.lock(); defer { lock.unlock() }
        return PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }

    func setFailAllApplies(_ enabled: Bool) {
        lock.lock(); defer { lock.unlock() }
        failAllApplies = enabled
    }
}

private final class AW23ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        precondition(generation >= self.generation)
        self.generation = generation
    }
}

private func aw23Executed(_ outcome: Lane3PitchControlOutcome) -> Lane3PitchControlExecutionReceipt? {
    guard case let .executed(receipt) = outcome else { return nil }
    return receipt
}

@main
struct L3AW23UnifiedPracticeControlAuthoritySelfTest {
    static func main() async throws {
        let project = ProjectID()
        let rawDSP = AW23DSPBackend()
        let telemetry = Lane3DSPRuntimeTelemetryCollector()
        let probe = Lane3DSPRuntimeTelemetryProbe(collector: telemetry)
        let measuredDSP = Lane3DSPTelemetryTransactionalBackend(backend: rawDSP, collector: telemetry)
        let playback = RescheduleFencedPlaybackBackend(backend: AW23PlaybackBackend())
        let controller = try PracticeDSPProductionController(projectID: project, backend: measuredDSP)
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: AW23ClickInvalidator()
        )
        let transportAuthority = Lane3UnifiedProductionTransportAuthority(
            projectID: project,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: .milliseconds(2),
                loopQuietPeriod: .milliseconds(2),
                tempoQuietPeriod: .milliseconds(2)
            )
        )
        let lifecycle = Lane3InterruptionLifecycleGate(authority: transportAuthority)
        let instrumented = Lane3InstrumentedInterruptionGate(
            gate: lifecycle,
            telemetry: Lane3ProductionTelemetryCollector()
        )
        let aw20 = Lane3PracticeInterruptionClickGate(transport: instrumented, coordinator: coordinator)
        let aw21 = Lane3SerializedPracticeClickGate(practiceGate: aw20, coordinator: coordinator)
        let authority = Lane3UnifiedPracticeControlAuthority(
            projectID: project,
            transport: instrumented,
            practice: aw21,
            controller: controller,
            coordinator: coordinator,
            telemetryProbe: probe
        )

        let before = try await coordinator.snapshot()
        guard let first = aw23Executed(await authority.submitPitchSemitones(7)) else {
            preconditionFailure("first pitch did not execute")
        }
        precondition(first.clickGenerationPreserved)
        precondition(first.lifecycleRevisionPreserved)
        precondition(first.coordinatorOperationSerialPreserved)
        let after = try await coordinator.snapshot()
        precondition(after.dspState.pitchSemitones == 7)
        precondition(after.dspState.scheduleGeneration == before.dspState.scheduleGeneration)

        if case let .rejectedBeforeDispatch(_, reason) = await authority.submitPitchSemitones(25) {
            precondition(reason == .invalidPitchSemitones)
        } else {
            preconditionFailure("out-of-range pitch not rejected")
        }

        var rapid: [Task<Lane3PitchControlOutcome, Never>] = []
        for index in 0..<500 {
            rapid.append(Task {
                await authority.submitPitchSemitones(Double((index % 49) - 24))
            })
        }
        var rapidExecuted = 0
        var rapidSuperseded = 0
        for task in rapid {
            switch await task.value {
            case .executed: rapidExecuted += 1
            case .supersededBeforeDispatch: rapidSuperseded += 1
            default: break
            }
        }
        precondition(rapidExecuted >= 1)
        precondition(rapidSuperseded >= 1)

        for index in 0..<200 {
            async let tempo = authority.submitTempoRatio(0.75 + Double(index % 20) / 20.0)
            async let pitch = authority.submitPitchSemitones(Double((index % 25) - 12))
            _ = await tempo
            _ = await pitch
        }
        let mixed = try await coordinator.snapshot()
        precondition(mixed.dspState.tempoRatio.isFinite)
        precondition(mixed.dspState.pitchSemitones.isFinite)

        _ = await authority.submitInterruptionBegan()
        if case let .rejectedBeforeDispatch(_, reason) = await authority.submitPitchSemitones(3) {
            precondition(reason == .interruptionOrLifecycleBlocked)
        } else {
            preconditionFailure("pitch accepted during interruption")
        }
        _ = await authority.submitInterruptionEnded(shouldResume: false)
        precondition(aw23Executed(await authority.submitPitchSemitones(4)) != nil)

        rawDSP.setFailAllApplies(true)
        let failed = await authority.submitPitchSemitones(5)
        if case let .failedAfterDispatch(receipt) = failed {
            precondition(receipt.reason == .backendRequiresRecovery)
            precondition(receipt.automaticRecoveryAttempted)
            precondition(!receipt.automaticRecoverySucceeded)
        } else {
            preconditionFailure("desynchronizing pitch failure did not fail closed")
        }

        let telemetrySnapshot = probe.snapshot()
        let pitchTelemetry = telemetrySnapshot.perKind.first(where: { $0.kind == Lane3DSPRuntimeOperationKind.pitch.rawValue })
        precondition((pitchTelemetry?.productSubmissions ?? 0) > 0)
        precondition((pitchTelemetry?.backendPrimaryEntries ?? 0) > 0)

        let final = await authority.snapshot()
        precondition(!final.pitchBarrierClosed)
        precondition(final.sharedOperationsInFlight == 0)

        print(
            "L3-AW23 unified practice authority self-test PASS " +
            "rapidExecuted=\(rapidExecuted) rapidSuperseded=\(rapidSuperseded)"
        )
    }
}
