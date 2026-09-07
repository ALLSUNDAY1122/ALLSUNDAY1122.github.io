import Foundation

@main
struct L3M04OfflineReferenceBenchmark {
    static func main() throws {
        let sampleRate = 48_000.0
        let duration = 24.0 * 60.0 * 60.0
        let stemSpecs: [(String, Double, Double)] = [
            ("vocals", 0, 1), ("drums", 0.125, 0.9), ("bass", 0.25, 0.8), ("other", 0.5, 0.7),
            ("guitar", 1.0, 0.6), ("keys", 2.0, 0.5), ("strings", 4.0, 0.4), ("fx", 8.0, 0.3)
        ]
        let stems = stemSpecs.map { id, start, gain in
            Lane3ReferenceStemDescriptor(
                id: id,
                startSeconds: start,
                frameCount: Int64(((duration - start) * sampleRate).rounded(.down)),
                sampleRate: sampleRate,
                gain: gain
            )
        }
        let beats = stride(from: 0.0, through: duration, by: 0.5).map { $0 }
        let request = Lane3ReferenceRenderRequest(
            fixtureID: "L3-M04-24H-8STEM",
            stems: stems,
            projectStartSeconds: 0,
            projectEndSeconds: duration,
            outputSampleRate: sampleRate,
            practice: Lane3ReferencePracticeSettings(
                tempoRatio: 0.75,
                pitchSemitones: -2,
                metronomeEnabled: true,
                countInClicks: 4,
                downbeatStride: 4
            ),
            beatTimesSeconds: beats,
            countInBeatIntervalSeconds: 0.5
        )

        var timings: [Double] = []
        timings.reserveCapacity(12)
        var signature = ""
        var eventCount = 0
        for _ in 0..<12 {
            let start = ContinuousClock.now
            let plan = try Lane3OfflineReferencePlanner.makePlan(request)
            let elapsed = start.duration(to: .now)
            let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
            timings.append(ms)
            signature = plan.controlSignatureFNV1A64
            eventCount = plan.events.count
            precondition(plan.outputFrameCount > 0)
        }
        timings.sort()
        func percentile(_ p: Double) -> Double {
            let index = min(timings.count - 1, Int((Double(timings.count - 1) * p).rounded(.up)))
            return timings[index]
        }
        let median = timings[timings.count / 2]
        print(String(format: "L3-M04 24h/8-stem/%.0f-beat benchmark x12: median %.3fms p95 %.3fms p99 %.3fms max %.3fms events=%d signature=%@",
                     Double(beats.count), median, percentile(0.95), percentile(0.99), timings.last!, eventCount, signature))
    }
}
