import Foundation

private final class AW22BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private var tempo = 1.0
    private var pitch = 0.0

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        tempo = tempoRatio
        pitch = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW22BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private var generation: UInt64 = 0
    func invalidateSchedule(to generation: UInt64) throws {
        precondition(generation >= self.generation)
        self.generation = generation
    }
}

@main
struct L3AW22DSPRuntimeTelemetryBenchmark {
    static func main() async throws {
        let rounds = 20
        let operationsPerRound = 2_000
        var milliseconds: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let collector = Lane3DSPRuntimeTelemetryCollector()
            let probe = Lane3DSPRuntimeTelemetryProbe(collector: collector)
            let measuredBackend = Lane3DSPTelemetryTransactionalBackend(
                backend: AW22BenchmarkDSPBackend(),
                collector: collector
            )
            let measuredInvalidator = Lane3DSPTelemetryClickInvalidator(
                invalidator: AW22BenchmarkClickInvalidator(),
                collector: collector
            )
            let controller = try PracticeDSPProductionController(
                projectID: project,
                backend: measuredBackend
            )
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: measuredInvalidator
            )

            var playbackGeneration: UInt64 = 0
            let clock = ContinuousClock()
            let start = clock.now
            for operation in 0..<operationsPerRound {
                if operation.isMultiple(of: 2) {
                    playbackGeneration += 1
                    let ratio = 0.75 + Double(operation % 101) / 100.0
                    let token = PlaybackTransportRescheduleToken(
                        generation: playbackGeneration,
                        reason: .tempoChange
                    )
                    let receipt = try await probe.measureAsync(kind: .tempo) {
                        try await coordinator.applyTempoRatio(ratio, playbackToken: token)
                    }
                    checksum &+= receipt.clickGeneration
                } else {
                    let pitch = Double((operation % 25) - 12)
                    try await probe.measureAsync(kind: .pitch) {
                        try await controller.setPitchSemitones(pitch, projectID: project)
                    }
                    checksum &+= UInt64(operation)
                }
            }
            let duration = start.duration(to: clock.now).components
            milliseconds.append(
                (Double(duration.seconds) + Double(duration.attoseconds) / 1e18) * 1_000
            )
            let snapshot = probe.snapshot()
            checksum &+= snapshot.perKind.reduce(0) {
                $0 &+ $1.productSubmissions &+ $1.backendApplyCalls &+ $1.clickInvalidationCalls
            }
            checksum &+= UInt64(round)
        }

        let sorted = milliseconds.sorted()
        let median = sorted[sorted.count / 2]
        let p95Index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        let p95 = sorted[p95Index]
        let maximum = sorted.last ?? 0
        print(
            "L3-AW22 benchmark rounds=\(rounds) operations=\(operationsPerRound) " +
            "median_ms=\(String(format: \"%.3f\", median)) " +
            "p95_ms=\(String(format: \"%.3f\", p95)) " +
            "max_ms=\(String(format: \"%.3f\", maximum)) checksum=\(checksum)"
        )
    }
}
