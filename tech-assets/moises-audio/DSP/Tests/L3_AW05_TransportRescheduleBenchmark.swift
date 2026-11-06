import Foundation

@main
struct L3AW05TransportRescheduleBenchmark {
    static func main() throws {
        let rounds = 20
        let operations = 100_000
        var milliseconds: [Double] = []
        milliseconds.reserveCapacity(rounds)
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            var playback = PlaybackTransportRescheduleFence()
            var dsp = PracticeDSPTransportRescheduleGate()
            var clickGeneration: UInt64 = 0
            let start = ContinuousClock.now
            for index in 0..<operations {
                let pReason = PlaybackTransportDiscontinuityReason.allCases[index % PlaybackTransportDiscontinuityReason.allCases.count]
                let dReason = PracticeDSPTransportDiscontinuityReason.allCases[index % PracticeDSPTransportDiscontinuityReason.allCases.count]
                let token = try playback.invalidate(for: pReason)
                let intent = try dsp.begin(playbackGeneration: token.generation, reason: dReason)
                clickGeneration += 1
                let binding = try dsp.commit(intent: intent, clickGeneration: clickGeneration)
                checksum &+= binding.playbackGeneration &+ binding.clickGeneration &+ UInt64(round)
            }
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            let ms = Double(components.seconds) * 1_000
                + Double(components.attoseconds) / 1_000_000_000_000_000
            milliseconds.append(ms)
        }

        let sorted = milliseconds.sorted()
        func percentile(_ p: Double) -> Double {
            let raw = Int((Double(sorted.count - 1) * p).rounded(.up))
            return sorted[min(max(raw, 0), sorted.count - 1)]
        }
        let median = percentile(0.50)
        let p95 = percentile(0.95)
        let p99 = percentile(0.99)
        print(String(format: "rounds=%d operations=%d median=%.3fms p95=%.3fms p99/max=%.3fms checksum=%llu", rounds, operations, median, p95, p99, checksum))
    }
}
