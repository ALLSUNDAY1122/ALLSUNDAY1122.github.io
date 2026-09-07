import Foundation

private final class AW25BenchBackend: PracticeDSPPitchTransitionBackendApplying, @unchecked Sendable {
    private var tempo: Double = 1
    private var pitch: Double = 0
    func apply(tempoRatio: Double, pitchSemitones: Double) throws { tempo = tempoRatio; pitch = pitchSemitones }
    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot { .init(tempoRatio: tempo, pitchSemitones: pitch) }
    func beginPitchTransition(tempoRatio: Double, fromPitchSemitones: Double, toPitchSemitones: Double, policy: PracticeDSPPitchTransitionPolicy) throws -> PracticeDSPPitchTransitionBackendReceipt {
        let plan = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: fromPitchSemitones, toSemitones: toPitchSemitones, sampleRate: 48_000, policy: policy)
        tempo = tempoRatio
        if plan.mode == .immediate { pitch = toPitchSemitones }
        return .init(plan: plan)
    }
    func finalizePitchTransition(tempoRatio: Double, pitchSemitones: Double) throws { tempo = tempoRatio; pitch = pitchSemitones }
    func cancelPitchTransition(tempoRatio: Double, pitchSemitones: Double) throws { tempo = tempoRatio; pitch = pitchSemitones }
}
private struct AW25BenchSleeper: PracticeDSPPitchTransitionSleeping { func sleepIgnoringCancellation(nanoseconds: UInt64) async {} }

@main
struct L3AW25PitchTransitionBenchmark {
    static func main() async throws {
        let rounds = 20
        let operationsPerRound = 5_000
        var durations: [Double] = []
        var checksum = 0
        for round in 0..<rounds {
            let backend = AW25BenchBackend()
            let gate = try PracticeDSPTransactionalApplicationGate(backend: backend, pitchTransitionSleeper: AW25BenchSleeper())
            var state = PracticeDSPState()
            let start = DispatchTime.now().uptimeNanoseconds
            for index in 0..<operationsPerRound {
                let magnitude = Double((index % 24) + 1)
                state.pitchSemitones = ((index + round) & 1) == 0 ? magnitude : -magnitude
                let committed = try await gate.apply(state)
                checksum &+= Int(committed.pitchSemitones.rounded())
                if let receipt = await gate.lastPitchTransitionReceipt() { checksum &+= Int(receipt.rampDurationFrames) }
            }
            let end = DispatchTime.now().uptimeNanoseconds
            durations.append(Double(end - start) / 1_000_000)
        }
        let sorted = durations.sorted()
        let median = sorted[rounds / 2]
        let p95 = sorted[Int((Double(rounds) * 0.95).rounded(.up)) - 1]
        let maxValue = sorted.last!
        print(String(format: "L3-AW25 benchmark PASS rounds=%d operations=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%d", rounds, operationsPerRound, median, p95, maxValue, checksum))
    }
}
