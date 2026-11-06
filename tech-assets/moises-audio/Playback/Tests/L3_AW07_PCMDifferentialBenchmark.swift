import Foundation

@main
struct L3AW07PCMDifferentialBenchmark {
    static func main() throws {
        let rounds = 20
        let operationsPerRound = 100
        let frames = 24_000
        let referenceSamples = makeSignal(frames: frames)
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: referenceSamples, channels: 2, sampleRate: 48_000)
        let configuration = Lane3PCMDifferentialConfiguration(
            maximumAlignmentLagFrames: 64,
            alignmentWindowFrames: 12_000,
            localDriftSearchFrames: 16,
            localWindowFrames: 4_096,
            driftAnchorCount: 3,
            onsetSearchRadiusFrames: 128,
            expectedEventMaskRadiusFrames: 64,
            minimumComparableFrames: 1_024
        )
        let events: [Int64] = [2_000, 14_000]
        var timings: [Double] = []
        var checksum: Int64 = 0
        for round in 0..<rounds {
            let start = ContinuousClock.now
            for op in 0..<operationsPerRound {
                let shift = (round + op) % 31
                let observed = Lane3PCMBufferDescriptor(
                    interleavedSamples: makeSignal(frames: frames, shift: shift),
                    channels: 2,
                    sampleRate: 48_000
                )
                let report = try Lane3PCMDifferentialAnalyzer.analyze(
                    reference: reference,
                    observed: observed,
                    expectedEventFrames: events,
                    configuration: configuration
                )
                checksum &+= Int64(report.globalLagFrames)
                checksum &+= Int64(report.unexpectedDiscontinuityCount)
                checksum &+= Int64(report.driftSpanFrames)
            }
            let duration = start.duration(to: ContinuousClock.now)
            timings.append(durationMilliseconds(duration))
        }
        timings.sort()
        let median = timings[timings.count / 2]
        let p95Index = min(timings.count - 1, Int((Double(timings.count) * 0.95).rounded(.up)) - 1)
        let p95 = timings[p95Index]
        let maximum = timings.last ?? 0
        print(String(format: "rounds=%d ops=%d median_ms=%.3f p95_ms=%.3f max_ms=%.3f checksum=%lld", rounds, operationsPerRound, median, p95, maximum, checksum))
    }

    static func durationMilliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000.0 + Double(components.attoseconds) / 1e15
    }

    static func makeSignal(frames: Int, shift: Int = 0) -> [Float] {
        var mono: [Double] = []
        mono.reserveCapacity(frames + shift)
        var rng: UInt64 = 0x9e3779b97f4a7c15
        for i in 0..<frames {
            let t = Double(i) / 48_000.0
            rng ^= rng << 13
            rng ^= rng >> 7
            rng ^= rng << 17
            let noise = (Double(rng & 0xffff) / 65_535.0 - 0.5) * 0.12
            var value = 0.18 * sin(2 * Double.pi * 220 * t)
                + 0.09 * sin(2 * Double.pi * 1_013 * t)
                + noise
            if i % 12_000 == 2_000 { value += 0.8 }
            mono.append(value)
        }
        if shift > 0 { mono = Array(repeating: 0, count: shift) + mono }
        var output: [Float] = []
        output.reserveCapacity(mono.count * 2)
        for value in mono {
            output.append(Float(value))
            output.append(Float(value * 0.95))
        }
        return output
    }
}
