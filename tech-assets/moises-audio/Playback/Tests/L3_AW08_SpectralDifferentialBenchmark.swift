import Foundation
import Dispatch

@main
struct L3AW08SpectralDifferentialBenchmark {
    static func main() throws {
        let sampleRate = 48_000.0
        let frames = 16_384
        let ratio = pow(2.0, 1.0 / 12.0)
        let reference = descriptor(signal(frames: frames, sampleRate: sampleRate, frequencies: [196, 293.66, 392, 587.33, 783.99]), sampleRate)
        let observed = descriptor(signal(frames: frames, sampleRate: sampleRate, frequencies: [196, 293.66, 392, 587.33, 783.99].map { $0 * ratio }), sampleRate)
        let configuration = Lane3SpectralDifferentialConfiguration(
            windowSize: 1_024,
            hopSize: 512,
            minimumFrequencyHz: 50,
            maximumFrequencyHz: 16_000,
            expectedFrequencyRatio: ratio,
            frequencyRatioSearchRadiusCents: 120,
            frequencyRatioSearchStepCents: 5,
            highBandStartHz: 6_000,
            maximumWindows: 30
        )
        let rounds = 20
        let operationsPerRound = 10
        var elapsedMS: [Double] = []
        var checksum = 0.0
        elapsedMS.reserveCapacity(rounds)
        for _ in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<operationsPerRound {
                let report = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
                    reference: reference,
                    observed: observed,
                    configuration: configuration
                )
                checksum += report.bestScaleCorrelation
                checksum += report.meanLogSpectralDistanceDB
                checksum += report.medianSpectralPeakRatioErrorCents ?? 0
            }
            let end = DispatchTime.now().uptimeNanoseconds
            elapsedMS.append(Double(end - start) / 1_000_000)
        }
        let sorted = elapsedMS.sorted()
        let median = percentile(sorted, 0.50)
        let p95 = percentile(sorted, 0.95)
        let p99 = percentile(sorted, 0.99)
        print(String(format: "rounds=%d operations=%d frames=%d median=%.3fms p95=%.3fms p99/max=%.3fms checksum=%.6f", rounds, operationsPerRound, frames, median, p95, p99, checksum))
    }

    static func percentile(_ sorted: [Double], _ percentile: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * percentile).rounded(.up)))
        return sorted[index]
    }

    static func descriptor(_ mono: [Float], _ sampleRate: Double) -> Lane3PCMBufferDescriptor {
        var stereo: [Float] = []
        stereo.reserveCapacity(mono.count * 2)
        for value in mono { stereo.append(value); stereo.append(value) }
        return Lane3PCMBufferDescriptor(interleavedSamples: stereo, channels: 2, sampleRate: sampleRate)
    }

    static func signal(frames: Int, sampleRate: Double, frequencies: [Double]) -> [Float] {
        var output = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            let t = Double(frame) / sampleRate
            let envelope = 0.75 + 0.15 * sin(2 * Double.pi * 2.7 * t) + 0.10 * sin(2 * Double.pi * 5.3 * t)
            var value = 0.0
            for (index, frequency) in frequencies.enumerated() {
                value += sin(2 * Double.pi * frequency * t + Double(index) * 0.23) / Double(index + 1)
            }
            output[frame] = Float(0.18 * envelope * value)
        }
        return output
    }
}
