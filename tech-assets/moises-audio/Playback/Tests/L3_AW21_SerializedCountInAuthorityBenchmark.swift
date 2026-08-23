import Foundation

private final class AW21BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW21BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        precondition(generation >= self.generation)
        self.generation = generation
    }
}

@main
struct L3AW21SerializedCountInAuthorityBenchmark {
    static func main() async throws {
        var samplesMs: [Double] = []
        var checksum: UInt64 = 0

        for _ in 0..<20 {
            let project = ProjectID()
            let controller = try PracticeDSPProductionController(
                projectID: project,
                backend: AW21BenchmarkDSPBackend()
            )
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW21BenchmarkClickInvalidator()
            )

            let start = ContinuousClock.now
            for i in 0..<2_000 {
                let clicks = (i % 4) + 1
                let arm = try await coordinator.scheduleCountIn(clicks: clicks)
                if i % 3 == 0 {
                    let receipt = try await coordinator.consumeScheduledCountIn(
                        expectedClickGeneration: arm.clickGeneration,
                        expectedClicks: clicks
                    )
                    precondition(receipt.acceptedSchedulePreserved)
                    checksum &+= receipt.committedClickGeneration
                } else {
                    let receipt = try await coordinator.discardCountIn(
                        expectedClickGeneration: arm.clickGeneration,
                        expectedClicks: clicks
                    )
                    precondition(!receipt.acceptedSchedulePreserved)
                    checksum &+= receipt.committedClickGeneration
                }
            }
            let duration = start.duration(to: .now)
            let milliseconds = Double(duration.components.seconds) * 1_000.0
                + Double(duration.components.attoseconds) / 1_000_000_000_000_000.0
            samplesMs.append(milliseconds)
            precondition((try await coordinator.snapshot()).dspState.pendingCountInClicks == nil)
        }

        samplesMs.sort()
        let median = (samplesMs[9] + samplesMs[10]) / 2.0
        let p95 = samplesMs[18]
        let maxValue = samplesMs[19]
        print(String(format: "L3-AW21 benchmark median_ms=%.3f p95_ms=%.3f max_ms=%.3f checksum=%llu", median, p95, maxValue, checksum))
    }
}
