import Foundation

@main
struct L3AW35InteractiveContinuityEvidenceBenchmark {
    static func main() {
        let rounds = 20
        let operations = 1_000_000
        var durations: [Double] = []
        durations.reserveCapacity(rounds)
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            var buffer = Lane3InteractiveContinuityEvidenceBuffer(capacity: 4_096)
            let start = ContinuousClock.now
            for index in 0..<operations {
                let base = UInt64(index) * 1_000
                let isSeek = index.isMultiple(of: 2)
                buffer.append(.init(
                    sampleID: UInt64(index),
                    operation: isSeek ? .seek : .loop,
                    outcome: .executed,
                    slotGenerationAtIntent: UInt64(1 + round),
                    slotGenerationAtCompletion: UInt64(1 + round),
                    transportTicket: UInt64(index),
                    playbackGeneration: UInt64(index + 1),
                    firstIntentUptimeNanoseconds: base,
                    tokenIssuedUptimeNanoseconds: base + 1_000,
                    audibleResultUptimeNanoseconds: base + 5_000,
                    requestedTarget: isSeek ? .seek(positionSeconds: Double(index % 10_000) / 10) : .loop(startSeconds: 1, endSeconds: 2),
                    appliedTarget: isSeek ? .seek(positionSeconds: Double(index % 10_000) / 10) : .loop(startSeconds: 1, endSeconds: 2),
                    callerCancellationObservedAfterDispatch: false
                ))
            }
            let elapsed = start.duration(to: .now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            durations.append(seconds * 1_000)
            let retained = buffer.orderedObservations()
            checksum &+= UInt64(retained.count)
            checksum &+= buffer.capacityDrops
            checksum &+= retained.first?.sampleID ?? 0
            checksum &+= retained.last?.sampleID ?? 0
        }

        let sorted = durations.sorted()
        let median = sorted[rounds / 2]
        let p95 = sorted[Int(ceil(Double(rounds) * 0.95)) - 1]
        let maximum = sorted.last ?? 0
        print(String(format: "L3-AW35 benchmark rounds=%d ops=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu", rounds, operations, median, p95, maximum, checksum))
    }
}
