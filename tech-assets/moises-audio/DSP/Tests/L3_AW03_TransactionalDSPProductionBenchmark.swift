import Foundation

private final class BenchmarkTransactionalDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    var tempo = 1.0
    var pitch = 0.0

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        PracticeDSPBackendSnapshot(
            tempoRatio: tempo,
            pitchSemitones: pitch
        )
    }

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        tempo = tempoRatio
        pitch = pitchSemitones
    }
}

@main
struct L3AW03TransactionalDSPProductionBenchmark {
    static func main() async throws {
        let rounds = 20
        let operationsPerRound = 10_000
        var samples: [Double] = []
        var checksum = 0.0

        for round in 0..<rounds {
            let backend = BenchmarkTransactionalDSPBackend()
            let gate = try PracticeDSPTransactionalApplicationGate(backend: backend)
            let start = DispatchTime.now().uptimeNanoseconds

            for index in 0..<operationsPerRound {
                let tempo = 0.5 + Double((index + round) % 151) / 100.0
                let pitch = Double(((index * 7 + round) % 49) - 24)
                let candidate = PracticeDSPState(
                    tempoRatio: tempo,
                    pitchSemitones: pitch,
                    scheduleGeneration: UInt64(index + 1)
                )
                _ = try await gate.apply(candidate)
                checksum += tempo + pitch
            }

            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsed) / 1_000_000.0)
        }

        samples.sort()
        func percentile(_ fraction: Double) -> Double {
            let index = min(
                samples.count - 1,
                Int((Double(samples.count - 1) * fraction).rounded())
            )
            return samples[index]
        }

        print(
            String(
                format: "L3-AW03 benchmark rounds=%d ops=%d median=%.3fms p95=%.3fms p99=%.3fms max=%.3fms checksum=%.3f",
                rounds,
                operationsPerRound,
                percentile(0.50),
                percentile(0.95),
                percentile(0.99),
                samples.last ?? 0,
                checksum
            )
        )
    }
}
