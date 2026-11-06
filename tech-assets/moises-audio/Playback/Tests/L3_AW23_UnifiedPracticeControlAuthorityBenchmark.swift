import Foundation

private final class AW23BenchmarkPlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW23BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW23BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

@main
struct L3AW23UnifiedPracticeControlAuthorityBenchmark {
    static func main() async throws {
        let rounds = 20
        let operationsPerRound = 2_000
        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        var checksum = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let rawDSP = AW23BenchmarkDSPBackend()
            let telemetry = Lane3DSPRuntimeTelemetryCollector()
            let probe = Lane3DSPRuntimeTelemetryProbe(collector: telemetry)
            let measuredDSP = Lane3DSPTelemetryTransactionalBackend(backend: rawDSP, collector: telemetry)
            let playback = RescheduleFencedPlaybackBackend(backend: AW23BenchmarkPlaybackBackend())
            let controller = try PracticeDSPProductionController(projectID: project, backend: measuredDSP)
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW23BenchmarkClickInvalidator()
            )
            let transportAuthority = Lane3UnifiedProductionTransportAuthority(
                projectID: project,
                playback: playback,
                coordinator: coordinator,
                policy: Lane3UnifiedTransportPolicy(
                    seekQuietPeriod: .milliseconds(1),
                    loopQuietPeriod: .milliseconds(1),
                    tempoQuietPeriod: .milliseconds(1)
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

            let start = clock.now
            var tasks: [Task<Lane3PitchControlOutcome, Never>] = []
            tasks.reserveCapacity(operationsPerRound)
            for index in 0..<operationsPerRound {
                tasks.append(Task {
                    await authority.submitPitchSemitones(Double((index % 49) - 24))
                })
            }
            for task in tasks {
                switch await task.value {
                case .executed:
                    checksum &+= 3
                case .supersededBeforeDispatch:
                    checksum &+= 1
                default:
                    checksum &+= 7
                }
            }
            checksum &+= round
            let components = start.duration(to: clock.now).components
            milliseconds.append(
                (Double(components.seconds) + Double(components.attoseconds) / 1e18) * 1_000
            )
        }

        let sorted = milliseconds.sorted()
        let median = sorted[sorted.count / 2]
        let p95Index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        let p95 = sorted[p95Index]
        let maximum = sorted.last ?? 0
        print(
            "L3-AW23 benchmark rounds=\(rounds) operations=\(operationsPerRound) " +
            "median_ms=\(String(format: \"%.3f\", median)) " +
            "p95_ms=\(String(format: \"%.3f\", p95)) " +
            "max_ms=\(String(format: \"%.3f\", maximum)) checksum=\(checksum)"
        )
    }
}
