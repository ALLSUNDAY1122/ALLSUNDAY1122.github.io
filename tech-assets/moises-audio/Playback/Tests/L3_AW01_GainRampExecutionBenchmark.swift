import Foundation

@main
struct L3AW01GainRampExecutionBenchmarkMain {
    static func main() throws {
        let ids = (0..<8).map { index in
            StemID(rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!)
        }
        let rates = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
            (id, [44_100.0, 48_000.0, 96_000.0][index % 3])
        })

        var samples: [Double] = []
        var checksum: Int64 = 0
        for round in 0..<20 {
            var current = Dictionary(uniqueKeysWithValues: ids.map { ($0, 1.0) })
            let start = ContinuousClock.now
            for step in 0..<50_000 {
                let target = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
                    (id, Double((step + index + round) % 101) / 100.0)
                })
                let plan = try PlaybackGainRampExecutionPlanner.plan(
                    currentGains: current,
                    targetGains: target,
                    renderSampleRates: rates
                )
                checksum &+= plan.steps.reduce(0) { $0 &+ $1.frameCount }
                current = plan.committedTargetGains
            }
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            let milliseconds = Double(components.seconds) * 1_000
                + Double(components.attoseconds) / 1e15
            samples.append(milliseconds)
        }

        let sorted = samples.sorted()
        func percentile(_ p: Double) -> Double {
            let idx = min(
                sorted.count - 1,
                Int((Double(sorted.count - 1) * p).rounded(.up))
            )
            return sorted[idx]
        }
        print(String(
            format: "median=%.3fms p95=%.3fms p99=%.3fms max=%.3fms checksum=%lld",
            percentile(0.50),
            percentile(0.95),
            percentile(0.99),
            sorted.last!,
            checksum
        ))
    }
}
