import Foundation

private final class AW12BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW12BenchmarkClickInvalidator: @unchecked Sendable, PracticeDSPClickScheduleInvalidating {
    private let lock = NSLock()
    private var lastGeneration: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); lastGeneration = generation; lock.unlock()
    }

    func snapshot() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return lastGeneration
    }
}

@main
struct L3AW12ProductionGenerationCoordinatorBenchmark {
    static func main() async throws {
        let rounds = 20
        let operationsPerRound = 10_000
        var durationsMS: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let controller = try PracticeDSPProductionController(
                projectID: project,
                backend: AW12BenchmarkDSPBackend()
            )
            let invalidator = AW12BenchmarkClickInvalidator()
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: invalidator
            )
            var playbackGeneration: UInt64 = 0
            let start = ContinuousClock.now

            for index in 0..<operationsPerRound {
                switch index % 5 {
                case 0:
                    playbackGeneration += 1
                    _ = try await coordinator.bindTransportDiscontinuity(
                        playbackToken: PlaybackTransportRescheduleToken(
                            generation: playbackGeneration,
                            reason: .seek
                        )
                    )
                case 1:
                    _ = try await coordinator.setMetronomeEnabled((index & 1) == 0)
                case 2:
                    _ = try await coordinator.scheduleCountIn(clicks: (index % 8) + 1)
                case 3:
                    playbackGeneration += 1
                    _ = try await coordinator.applyTempoRatio(
                        0.75 + Double(index % 100) / 100,
                        playbackToken: PlaybackTransportRescheduleToken(
                            generation: playbackGeneration,
                            reason: .tempoChange
                        )
                    )
                default:
                    playbackGeneration += 1
                    _ = try await coordinator.bindTransportDiscontinuity(
                        playbackToken: PlaybackTransportRescheduleToken(
                            generation: playbackGeneration,
                            reason: .loopChange
                        )
                    )
                }
            }

            let elapsed = ContinuousClock.now - start
            let parts = elapsed.components
            durationsMS.append(
                Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
            )
            let snapshot = try await coordinator.snapshot()
            checksum &+= snapshot.dspState.scheduleGeneration
            checksum &+= playbackGeneration
            checksum &+= UInt64(round)
            checksum &+= invalidator.snapshot()
        }

        let sorted = durationsMS.sorted()
        let median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        let p95 = sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
        print(String(
            format: "L3-AW12 benchmark rounds=%d operations=%d median_ms=%.3f p95_ms=%.3f max_ms=%.3f checksum=%llu",
            rounds,
            operationsPerRound,
            median,
            p95,
            sorted.last ?? 0,
            checksum
        ))
    }
}
