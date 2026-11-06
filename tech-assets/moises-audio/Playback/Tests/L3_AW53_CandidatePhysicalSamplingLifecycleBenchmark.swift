import Foundation

@main
enum L3AW53CandidatePhysicalSamplingLifecycleBenchmark {
    static func main() throws {
        let iterations = 20_000
        let start = ContinuousClock.now
        var aggregateSamples = 0
        for round in 0..<iterations {
            var lifecycle = Lane3CandidatePhysicalSamplingLifecycle()
            let base = Double(round) * 2_000
            try lifecycle.start(firstSampleUptimeSeconds: base)
            for index in 1...120 {
                try lifecycle.acceptSample(uptimeSeconds: base + Double(index) * 15)
            }
            try lifecycle.complete()
            aggregateSamples += lifecycle.acceptedSamples
        }
        let elapsed = start.duration(to: ContinuousClock.now)
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
        precondition(aggregateSamples == iterations * 121)
        print("L3_AW53_CandidatePhysicalSamplingLifecycleBenchmark iterations=\(iterations) elapsedSeconds=\(seconds) microsecondsPerLifecycle=\(seconds * 1_000_000 / Double(iterations)) aggregateSamples=\(aggregateSamples)")
    }
}
