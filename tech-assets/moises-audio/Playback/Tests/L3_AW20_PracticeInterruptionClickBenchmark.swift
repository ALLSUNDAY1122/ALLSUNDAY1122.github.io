import Foundation

private final class AW20BenchmarkPlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW20BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW20BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        precondition(generation >= self.generation)
        self.generation = generation
    }
}

@main
struct L3AW20PracticeInterruptionClickBenchmark {
    static func main() async throws {
        let rounds = 20
        let cyclesPerRound = 2_000
        var milliseconds: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let playback = RescheduleFencedPlaybackBackend(backend: AW20BenchmarkPlaybackBackend())
            let controller = try PracticeDSPProductionController(projectID: project, backend: AW20BenchmarkDSPBackend())
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW20BenchmarkClickInvalidator()
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
            let lifecycle = Lane3InterruptionLifecycleGate(authority: authority)
            let telemetry = Lane3ProductionTelemetryCollector()
            let instrumented = Lane3InstrumentedInterruptionGate(gate: lifecycle, telemetry: telemetry)
            let gate = Lane3PracticeInterruptionClickGate(transport: instrumented, coordinator: coordinator)

            _ = await instrumented.submitPlay()
            _ = try await gate.setMetronomeEnabled(true)

            let clock = ContinuousClock()
            let start = clock.now
            for cycle in 0..<cyclesPerRound {
                let countIn = try await gate.scheduleCountIn(clicks: (cycle % 4) + 1)
                let began = await gate.submitInterruptionBegan()
                precondition(began.countInAuthorizationRevoked)
                let ended = await gate.submitInterruptionEnded(shouldResume: true)
                precondition(!ended.countInAutoRestoreAllowed)
                guard let restore = ended.metronomeRestoreAuthorization else {
                    preconditionFailure("metronome restore authorization missing")
                }
                let plan = try await gate.makeMetronomeRestorePlan(
                    authorization: restore,
                    beatTimesSeconds: [0, 0.5, 1.0],
                    sourceStartSeconds: 0,
                    sourceEndSeconds: 1.5,
                    renderOriginSampleTime: Int64(cycle),
                    sampleRate: 48_000
                )
                checksum &+= plan.executionBatch.generation
                checksum &+= countIn.armSerial
                checksum &+= UInt64(round)
            }
            let duration = start.duration(to: clock.now)
            let components = duration.components
            let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
            milliseconds.append(seconds * 1_000)
        }

        let sorted = milliseconds.sorted()
        let median = sorted[sorted.count / 2]
        let p95Index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        let p95 = sorted[p95Index]
        let maximum = sorted.last ?? 0
        let medianText = String(format: "%.3f", median)
        let p95Text = String(format: "%.3f", p95)
        let maximumText = String(format: "%.3f", maximum)
        print(
            "L3-AW20 benchmark rounds=\(rounds) cycles=\(cyclesPerRound) " +
            "median_ms=\(medianText) p95_ms=\(p95Text) max_ms=\(maximumText) checksum=\(checksum)"
        )
    }
}
