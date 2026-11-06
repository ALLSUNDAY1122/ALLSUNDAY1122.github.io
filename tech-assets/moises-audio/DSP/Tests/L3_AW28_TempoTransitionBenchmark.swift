import Foundation

private final class AW28BenchmarkTempoBackend: PracticeDSPTempoTransitionBackendApplying, @unchecked Sendable {
    private var applied = PracticeDSPBackendSnapshot(tempoRatio: 1, pitchSemitones: 0)
    private(set) var beginCount: UInt64 = 0
    private(set) var finalizeCount: UInt64 = 0

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        applied = .init(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot { applied }

    func beginTempoTransition(
        fromTempoRatio: Double,
        toTempoRatio: Double,
        pitchSemitones: Double,
        policy: PracticeDSPTempoTransitionPolicy
    ) throws -> PracticeDSPTempoTransitionBackendReceipt {
        beginCount &+= 1
        return .init(plan: try PracticeDSPTempoTransitionPlanner.makePlan(
            fromRatio: fromTempoRatio,
            toRatio: toTempoRatio,
            sampleRate: 48_000,
            policy: policy
        ))
    }

    func finalizeTempoTransition(tempoRatio: Double, pitchSemitones: Double) throws {
        finalizeCount &+= 1
        applied = .init(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    func cancelTempoTransition(tempoRatio: Double, pitchSemitones: Double) throws {
        applied = .init(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }
}

private struct AW28BenchmarkNoOpSleeper: PracticeDSPTempoTransitionSleeping {
    func sleepIgnoringCancellation(nanoseconds: UInt64) async {}
}

private func aw28Percentile95(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted[min(sorted.count - 1, Int((0.95 * Double(sorted.count - 1)).rounded(.up)))]
}

@main
struct L3AW28TempoTransitionBenchmark {
    static func main() async throws {
        let rounds = 20
        let operations = 5_000
        var samples: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let backend = AW28BenchmarkTempoBackend()
            let gate = try PracticeDSPTransactionalApplicationGate(
                backend: backend,
                tempoTransitionSleeper: AW28BenchmarkNoOpSleeper()
            )
            var state = PracticeDSPState()
            let start = DispatchTime.now().uptimeNanoseconds
            for index in 0..<operations {
                state.tempoRatio = index.isMultiple(of: 2) ? 0.75 : 1.25
                state.scheduleGeneration = UInt64(index + 1)
                state = try await gate.apply(state)
            }
            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(end - start) / 1_000_000)
            checksum &+= UInt64(round + 1) &* UInt64(operations)
            checksum &+= backend.beginCount &+ backend.finalizeCount
        }

        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        print(String(
            format: "L3-AW28 tempo transition benchmark rounds=%d operations=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu",
            rounds,
            operations,
            median,
            aw28Percentile95(samples),
            samples.max() ?? 0,
            checksum
        ))
    }
}
