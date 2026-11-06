import Foundation

private func percentile(_ sorted: [Double], _ p: Double) -> Double {
    let index = min(
        sorted.count - 1,
        max(0, Int((Double(sorted.count - 1) * p).rounded()))
    )
    return sorted[index]
}

@main
struct L3AW04ClickExecutionBenchmark {
    static func main() throws {
        let rounds = 20
        let batchesPerRound = 50_000
        let eventsPerBatch = 8
        var elapsedMilliseconds: [Double] = []
        var checksum: Int64 = 0

        for round in 0..<rounds {
            let generation = UInt64(1_000 + round)
            var state = DSPClickExecutionState(
                activeGeneration: generation
            )
            var cursor: Int64 = 96_000
            let started = DispatchTime.now().uptimeNanoseconds

            for batchIndex in 0..<batchesPerRound {
                var events: [DSPClickEvent] = []
                events.reserveCapacity(eventsPerBatch)
                for eventIndex in 0..<eventsPerBatch {
                    cursor += 256
                    events.append(
                        DSPClickEvent(
                            sampleTime: cursor,
                            beatIndex: batchIndex * eventsPerBatch + eventIndex,
                            accent: eventIndex == 0,
                            generation: generation
                        )
                    )
                }
                let batch = try DSPClickExecutionPlanner.preflight(
                    events: events,
                    activeGeneration: generation,
                    renderOriginSampleTime: 96_000,
                    sampleRate: 48_000,
                    kind: .metronome
                )
                try state.acceptAppend(batch)
                checksum &+= batch.lastProjectSampleTime ?? 0
            }

            let ended = DispatchTime.now().uptimeNanoseconds
            elapsedMilliseconds.append(
                Double(ended - started) / 1_000_000.0
            )
        }

        let sorted = elapsedMilliseconds.sorted()
        print(
            String(
                format: "L3-AW04 click execution benchmark median %.3fms p95 %.3fms p99 %.3fms max %.3fms checksum %lld",
                percentile(sorted, 0.50),
                percentile(sorted, 0.95),
                percentile(sorted, 0.99),
                sorted.last ?? 0,
                checksum
            )
        )
    }
}
