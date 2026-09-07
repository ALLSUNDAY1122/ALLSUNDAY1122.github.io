import Foundation

@main
struct L3M03ControlSafetyBenchmark {
    static func main() throws {
        let ids = (0..<8).map { _ in StemID() }
        let role = StemRole(rawValue: "benchmark")
        let previous = ids.enumerated().map { i, id in
            PlaybackTrackMix(stemID: id, role: role, volume: Double(i + 1) / 8.0, muted: false, soloed: false)
        }
        let next = ids.enumerated().map { i, id in
            PlaybackTrackMix(stemID: id, role: role, volume: Double(8 - i) / 8.0, muted: i % 3 == 0, soloed: i == 2 || i == 5)
        }
        let beats = (0..<256).map { Double($0) * 0.5 }
        var durations: [Double] = []
        durations.reserveCapacity(20)
        var checksum = 0.0

        for round in 0..<20 {
            let start = ContinuousClock.now
            for i in 0..<50_000 {
                let plan = try PlaybackControlSafety.planGainTransition(
                    from: i % 2 == 0 ? previous : next,
                    to: i % 2 == 0 ? next : previous,
                    sampleRate: 48_000
                )
                checksum += plan.segments[round % plan.segments.count].gain(atFrame: 288)
            }
            for i in 0..<5_000 {
                let state = PracticeDSPState(
                    tempoRatio: 0.5 + Double(i % 150) / 100.0,
                    pitchSemitones: Double((i % 25) - 12),
                    metronomeEnabled: i % 2 == 0,
                    pendingCountInClicks: (i % 32) + 1,
                    scheduleGeneration: UInt64(i)
                )
                try PracticeDSPStateValidator.validate(state, capabilities: .appleTimePitchBaseline)
                let events = try SampleTimelinePlanner.planClicks(
                    beatTimesSeconds: beats,
                    sourceStartSeconds: 0,
                    renderStartSampleTime: 48_000,
                    tempoRatio: state.tempoRatio,
                    sampleRate: 48_000,
                    generation: UInt64(i)
                )
                checksum += Double(events.last?.sampleTime ?? 0) * 1e-12
            }
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            let ms = Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
            durations.append(ms)
        }

        durations.sort()
        func percentile(_ p: Double) -> Double {
            let idx = min(durations.count - 1, Int((Double(durations.count - 1) * p).rounded(.up)))
            return durations[idx]
        }
        let median = durations[durations.count / 2]
        print(String(format: "L3-M03 benchmark: median %.3fms p95 %.3fms p99/max %.3fms checksum %.6f", median, percentile(0.95), percentile(0.99), checksum))
    }
}
