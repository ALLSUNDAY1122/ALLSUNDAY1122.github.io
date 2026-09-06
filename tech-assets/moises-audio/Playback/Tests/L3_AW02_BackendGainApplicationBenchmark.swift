import Foundation

@main
enum L3AW02BackendGainApplicationBenchmark {
    static func main() throws {
        let ids: [StemID] = (1...8).map { index in
            StemID(
                rawValue: UUID(
                    uuidString: String(
                        format: "00000000-0000-0000-0000-%012d",
                        index
                    )
                )!
            )
        }
        let rates = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
            (id, [44_100.0, 48_000.0, 96_000.0][index % 3])
        })

        var samples: [Double] = []
        var checksum: Int64 = 0
        for round in 0..<20 {
            var committed = Dictionary(uniqueKeysWithValues: ids.map { ($0, 1.0) })
            let start = DispatchTime.now().uptimeNanoseconds
            for iteration in 0..<50_000 {
                var requested: [StemID: Double] = [:]
                for (index, id) in ids.enumerated() {
                    requested[id] = Double(
                        (iteration * 7 + index * 13 + round) % 101
                    ) / 100
                }
                let plan = try PlaybackBackendGainApplicationPlanner.plan(
                    loadedStemIDs: Array(ids.reversed()),
                    committedGains: committed,
                    requestedGains: requested,
                    renderSampleRates: rates,
                    isPlaying: iteration % 4 != 0
                )
                committed = plan.normalizedTargetGains
                checksum &+= plan.execution.steps.reduce(0) {
                    $0 + $1.frameCount
                }
            }
            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(end - start) / 1_000_000)
        }

        let sorted = samples.sorted()
        func percentile(_ fraction: Double) -> Double {
            let index = min(
                sorted.count - 1,
                Int((Double(sorted.count - 1) * fraction).rounded(.up))
            )
            return sorted[index]
        }
        print(
            String(
                format: "L3-AW02 20x50000 eight-stem plans median %.3fms p95 %.3fms p99 %.3fms max %.3fms checksum %lld",
                percentile(0.5),
                percentile(0.95),
                percentile(0.99),
                sorted.last ?? 0,
                checksum
            )
        )
    }
}
