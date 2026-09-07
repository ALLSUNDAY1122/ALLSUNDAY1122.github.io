import Foundation

private func makeAW10BenchmarkFixture(
    frames: Int,
    sampleRate: Double,
    fundamentalHz: Double
) -> Lane3PCMBufferDescriptor {
    let formants = [(700.0, 180.0), (1_300.0, 220.0), (2_500.0, 300.0)]
    var mono = [Float](repeating: 0, count: frames)
    for frame in 0..<frames {
        let t = Double(frame) / sampleRate
        var value = 0.0
        for harmonic in 1...24 {
            let frequency = fundamentalHz * Double(harmonic)
            if frequency >= sampleRate / 2 { break }
            var amplitude = 1.0 / Double(harmonic)
            for (center, width) in formants {
                amplitude *= 0.15 + exp(-0.5 * pow((frequency - center) / width, 2))
            }
            value += amplitude * sin(2 * Double.pi * frequency * t)
        }
        mono[frame] = Float(value * 0.18)
    }
    var stereo: [Float] = []
    stereo.reserveCapacity(frames * 2)
    for sample in mono { stereo.append(sample); stereo.append(sample) }
    return Lane3PCMBufferDescriptor(interleavedSamples: stereo, channels: 2, sampleRate: sampleRate)
}

@main
enum L3AW10Benchmark {
    static func main() throws {
        let sampleRate = 48_000.0
        let frames = 16_384
        let rounds = 20
        let operationsPerRound = 10
        let reference = makeAW10BenchmarkFixture(frames: frames, sampleRate: sampleRate, fundamentalHz: 200)
        let observed = makeAW10BenchmarkFixture(frames: frames, sampleRate: sampleRate, fundamentalHz: 300)
        let configuration = Lane3CepstralEnvelopeConfiguration(
            windowSize: 1_024,
            hopSize: 512,
            maximumWindows: 30
        )
        var elapsed: [Double] = []
        var checksum = 0.0
        for _ in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<operationsPerRound {
                let report = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(
                    reference: reference,
                    observed: observed,
                    configuration: configuration
                )
                checksum += report.meanEnvelopeRMSEDB + (report.medianAbsoluteFormantPeakErrorCents ?? 0)
            }
            elapsed.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        let sorted = elapsed.sorted()
        let median = (sorted[9] + sorted[10]) / 2
        let p95 = sorted[Int(ceil(0.95 * Double(sorted.count))) - 1]
        print(String(format: "rounds=%d ops=%d median_ms=%.3f p95_ms=%.3f max_ms=%.3f checksum=%.6f", rounds, operationsPerRound, median, p95, sorted.last ?? 0, checksum))
    }
}
