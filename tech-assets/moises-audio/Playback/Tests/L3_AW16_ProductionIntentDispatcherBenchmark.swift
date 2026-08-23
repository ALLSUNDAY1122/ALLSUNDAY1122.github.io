import Foundation

private final class AW16BenchmarkPlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    private let lock = NSLock()
    private var seekCount = 0

    func count() -> Int {
        lock.lock(); defer { lock.unlock() }
        return seekCount
    }

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {
        lock.lock(); seekCount += 1; lock.unlock()
    }
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW16BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW16BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

@main
struct L3AW16ProductionIntentDispatcherBenchmark {
    static func main() async throws {
        let rounds = 20
        let intentsPerRound = 2_000
        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        var checksum = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let rawPlayback = AW16BenchmarkPlaybackBackend()
            let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
            let dspBackend = AW16BenchmarkDSPBackend()
            let controller = try PracticeDSPProductionController(projectID: project, backend: dspBackend)
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW16BenchmarkClickInvalidator()
            )
            let dispatcher = Lane3ProductionIntentDispatcher(
                projectID: project,
                playback: playback,
                coordinator: coordinator,
                policy: Lane3ContinuousDispatchPolicy(
                    seekQuietPeriod: .milliseconds(2),
                    loopQuietPeriod: .milliseconds(2),
                    tempoQuietPeriod: .milliseconds(2)
                )
            )

            let start = clock.now
            var executed = 0
            var superseded = 0
            await withTaskGroup(of: Lane3IntentDispatchOutcome.self) { group in
                for index in 0..<intentsPerRound {
                    group.addTask {
                        await dispatcher.submitSeek(
                            to: Double(index),
                            resume: true,
                            loop: nil
                        )
                    }
                }
                for await result in group {
                    switch result {
                    case .executed:
                        executed += 1
                    case .superseded:
                        superseded += 1
                    default:
                        preconditionFailure("benchmark burst must only execute latest or supersede predecessor")
                    }
                }
            }
            let duration = start.duration(to: clock.now)
            let components = duration.components
            let ms = Double(components.seconds) * 1_000
                + Double(components.attoseconds) / 1_000_000_000_000_000
            milliseconds.append(ms)

            precondition(executed == 1)
            precondition(superseded == intentsPerRound - 1)
            precondition(rawPlayback.count() == 1)
            checksum += executed * 31 + superseded + rawPlayback.count() + round
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
            "L3-AW16 dispatcher benchmark 20x2000 median %.3fms p95 %.3fms max %.3fms checksum %d",
            percentile(0.50), percentile(0.95), milliseconds.last!, checksum
        ))
    }
}
