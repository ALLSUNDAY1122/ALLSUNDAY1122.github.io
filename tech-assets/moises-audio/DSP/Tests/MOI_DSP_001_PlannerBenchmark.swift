import Foundation

@main
struct PlannerBenchmark {
    static func main() throws {
        let beats = (0..<7200).map { Double($0) * 0.5 }
        let iterations = 200
        var durationsMs: [Double] = []
        durationsMs.reserveCapacity(iterations)
        let clock = ContinuousClock()
        for i in 0..<iterations {
            let start = clock.now
            let events = try SampleTimelinePlanner.planClicks(
                beatTimesSeconds: beats,
                sourceStartSeconds: 0,
                renderStartSampleTime: 0,
                tempoRatio: 1.25,
                sampleRate: 48_000,
                generation: UInt64(i + 1)
            )
            precondition(events.count == beats.count)
            let elapsed = start.duration(to: clock.now)
            let components = elapsed.components
            let ms = Double(components.seconds) * 1000.0 + Double(components.attoseconds) / 1e15
            durationsMs.append(ms)
        }
        durationsMs.sort()
        let median = durationsMs[durationsMs.count / 2]
        let p99 = durationsMs[min(durationsMs.count - 1, Int(Double(durationsMs.count - 1) * 0.99))]
        let maxv = durationsMs.last!
        print(String(format: "events=7200 iterations=%d median_ms=%.4f p99_ms=%.4f max_ms=%.4f", iterations, median, p99, maxv))
    }
}
