import Foundation

private final class AW15BenchmarkBlockingBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let condition = NSCondition()
    private var tempoRatio = 1.0
    private var pitchSemitones = 0.0
    private var blockNextSnapshot = false
    private var blockedCount = 0
    private var releasedCount = 0

    func arm() -> Int {
        condition.lock(); defer { condition.unlock() }
        precondition(!blockNextSnapshot)
        blockNextSnapshot = true
        return blockedCount + 1
    }

    func wait(_ target: Int, timeout: TimeInterval = 3) -> Bool {
        condition.lock(); defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while blockedCount < target {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }

    func release(_ target: Int) {
        condition.lock(); defer { condition.unlock() }
        releasedCount = max(releasedCount, target)
        condition.broadcast()
    }

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        condition.lock(); defer { condition.unlock() }
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        condition.lock(); defer { condition.unlock() }
        if blockNextSnapshot {
            blockNextSnapshot = false
            blockedCount += 1
            let ticket = blockedCount
            condition.broadcast()
            while releasedCount < ticket { condition.wait() }
        }
        return PracticeDSPBackendSnapshot(
            tempoRatio: tempoRatio,
            pitchSemitones: pitchSemitones
        )
    }
}

private struct AW15BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating {
    func invalidateSchedule(to generation: UInt64) throws { }
}

@main
struct L3AW15CoordinatorConcurrencyBenchmark {
    static func main() async throws {
        let rounds = 20
        let cyclesPerRound = 200
        var durationsMS: [Double] = []
        var checksum: UInt64 = 0

        for _ in 0..<rounds {
            let project = ProjectID()
            let backend = AW15BenchmarkBlockingBackend()
            let controller = try PracticeDSPProductionController(projectID: project, backend: backend)
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW15BenchmarkClickInvalidator()
            )
            var playbackGeneration: UInt64 = 1
            _ = try await coordinator.recover(
                playbackToken: PlaybackTransportRescheduleToken(
                    generation: playbackGeneration,
                    reason: .recovery
                )
            )

            let start = ContinuousClock.now
            for _ in 0..<cyclesPerRound {
                playbackGeneration += 1
                let inFlightGeneration = playbackGeneration
                let ticket = backend.arm()
                let first = Task {
                    try await coordinator.bindTransportDiscontinuity(
                        playbackToken: PlaybackTransportRescheduleToken(
                            generation: inFlightGeneration,
                            reason: .seek
                        )
                    )
                }
                precondition(backend.wait(ticket), "benchmark transport failed to suspend")

                playbackGeneration += 1
                do {
                    _ = try await coordinator.bindTransportDiscontinuity(
                        playbackToken: PlaybackTransportRescheduleToken(
                            generation: playbackGeneration,
                            reason: .loopChange
                        )
                    )
                    preconditionFailure("overlapping newer token unexpectedly committed")
                } catch PracticeDSPGenerationCoordinatorError.operationInFlight { }

                backend.release(ticket)
                do {
                    _ = try await first.value
                    preconditionFailure("superseded in-flight operation unexpectedly committed")
                } catch PracticeDSPGenerationCoordinatorError.operationSuperseded { }

                playbackGeneration += 1
                let recovered = try await coordinator.recover(
                    playbackToken: PlaybackTransportRescheduleToken(
                        generation: playbackGeneration,
                        reason: .recovery
                    )
                )
                checksum &+= recovered.playbackGeneration
                checksum &+= recovered.clickGeneration
            }
            let elapsed = ContinuousClock.now - start
            durationsMS.append(milliseconds(elapsed))
            let authority = await coordinator.authoritySnapshot()
            precondition(!authority.isPoisoned && !authority.operationInFlight)
            precondition(authority.activeBinding?.playbackGeneration == playbackGeneration)
        }

        let sorted = durationsMS.sorted()
        let median = sorted[sorted.count / 2]
        let p95 = sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
        let maximum = sorted.last ?? 0
        print(String(format: "L3-AW15 concurrency benchmark rounds=%d cycles=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu", rounds, cyclesPerRound, median, p95, maximum, checksum))
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
