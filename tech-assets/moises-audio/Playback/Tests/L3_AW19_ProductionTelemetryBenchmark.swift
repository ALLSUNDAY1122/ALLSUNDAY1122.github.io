import Foundation

private final class AW19BenchmarkPlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW19BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW19BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

@main
struct L3AW19ProductionTelemetryBenchmark {
    static func main() async throws {
        let rounds = 20
        let seekSubmissions = 2_000
        let discreteCommands = 200
        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let telemetry = Lane3ProductionTelemetryCollector(
                policy: Lane3TelemetryPolicy(
                    seekQuietPeriodNanoseconds: 2_000_000,
                    loopQuietPeriodNanoseconds: 2_000_000,
                    tempoQuietPeriodNanoseconds: 2_000_000
                )
            )
            let correlations = Lane3TelemetryDispatchCorrelationBridge(maxPendingPerKind: 256)
            let measuredBackend = Lane3TelemetryPlaybackBackend(
                backend: AW19BenchmarkPlaybackBackend(),
                telemetry: telemetry,
                correlations: correlations
            )
            let playback = RescheduleFencedPlaybackBackend(backend: measuredBackend)
            let controller = try PracticeDSPProductionController(
                projectID: project,
                backend: AW19BenchmarkDSPBackend()
            )
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW19BenchmarkClickInvalidator()
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
            let instrumented = Lane3InstrumentedInterruptionGate(
                gate: gate,
                telemetry: telemetry,
                correlations: correlations
            )

            let start = clock.now
            var seekExecuted = 0
            var seekSuperseded = 0
            await withTaskGroup(of: Lane3InterruptionGuardedOutcome.self) { group in
                for index in 0..<seekSubmissions {
                    group.addTask {
                        await instrumented.submitSeek(to: Double(index), resume: false, loop: nil)
                    }
                }
                for await outcome in group {
                    switch outcome {
                    case .transport(.executed): seekExecuted += 1
                    case .transport(.supersededBeforeToken): seekSuperseded += 1
                    default: break
                    }
                }
            }

            for index in 0..<discreteCommands {
                if index.isMultiple(of: 2) {
                    _ = await instrumented.submitPlay()
                } else {
                    _ = await instrumented.submitPause()
                }
            }
            let snapshot = await instrumented.telemetrySnapshot()
            let correlationHealth = await instrumented.telemetryCorrelationHealthSnapshot()!
            let duration = start.duration(to: clock.now).components
            let ms = Double(duration.seconds) * 1_000
                + Double(duration.attoseconds) / 1_000_000_000_000_000
            milliseconds.append(ms)

            precondition(seekExecuted + seekSuperseded == seekSubmissions)
            precondition(snapshot.totalProductSubmissions == UInt64(seekSubmissions + discreteCommands))
            precondition(snapshot.totalPlaybackTokensObserved >= UInt64(seekExecuted + discreteCommands))
            precondition(snapshot.backendDispatchEntrySamplesUnmatched == 0)
            precondition(snapshot.privacy.aggregationOnly)
            precondition(!snapshot.counterOverflowed)
            precondition(correlationHealth.pendingEntries == 0)
            precondition(correlationHealth.overflowDrops == 0)
            precondition(correlationHealth.unmatchedBackendOutcomes == 0)
            checksum &+= snapshot.totalProductSubmissions
            checksum &+= snapshot.totalPlaybackTokensObserved
            checksum &+= snapshot.totalPreTokenSuperseded
            checksum &+= UInt64(round)
        }

        milliseconds.sort()
        func percentile(_ fraction: Double) -> Double {
            let index = min(
                milliseconds.count - 1,
                Int((Double(milliseconds.count - 1) * fraction).rounded())
            )
            return milliseconds[index]
        }

        print(String(format:
            "L3-AW19 production telemetry benchmark 20x(2000 seek + 200 play/pause) median %.3fms p95 %.3fms max %.3fms checksum %llu",
            percentile(0.50), percentile(0.95), milliseconds.last!, checksum
        ))
    }
}
