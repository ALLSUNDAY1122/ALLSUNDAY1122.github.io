import Foundation

public enum MusicalKeyAnalyzer {
    private static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    public static func analyze(signal: AnalysisSignal, configuration: MusicAnalysisConfiguration = .productBaseline) -> MusicalKey? {
        let samples = signal.monoSamples.map { value -> Double in
            let sample = Double(value)
            return sample.isFinite ? sample : 0
        }
        guard samples.count >= configuration.analysisWindowSize,
              rms(samples) > 1e-5 else { return nil }

        let windowSize = configuration.analysisWindowSize
        let availableWindows = max(1, (samples.count - windowSize) / max(1, configuration.analysisHopSize) + 1)
        let selectedCount = min(configuration.maximumKeyWindows, availableWindows)
        let starts = uniformlySpacedWindowStarts(sampleCount: samples.count, windowSize: windowSize, count: selectedCount)

        var chroma = Array(repeating: 0.0, count: 12)
        var acceptedWindows = 0
        for start in starts {
            let slice = Array(samples[start..<(start + windowSize)])
            let local = chromaForWindow(slice, sampleRate: signal.sampleRate)
            let localTotal = local.reduce(0, +)
            guard localTotal > 1e-10 else { continue }
            for pitchClass in 0..<12 {
                chroma[pitchClass] += local[pitchClass] / localTotal
            }
            acceptedWindows += 1
        }
        guard acceptedWindows > 0 else { return nil }

        let total = chroma.reduce(0, +)
        guard total > 1e-10 else { return nil }
        chroma = chroma.map { $0 / total }

        let maxBin = chroma.max() ?? 0
        let activePitchClasses = chroma.filter { $0 >= maxBin * 0.16 }.count
        guard activePitchClasses >= 3 else { return nil }

        var scores: [(tonic: Int, mode: String, score: Double)] = []
        for tonic in 0..<12 {
            scores.append((tonic, "major", cosine(chroma, rotatedProfile(majorProfile, tonic: tonic))))
            scores.append((tonic, "minor", cosine(chroma, rotatedProfile(minorProfile, tonic: tonic))))
        }
        scores.sort { $0.score > $1.score }
        guard let best = scores.first else { return nil }
        let second = scores.dropFirst().first?.score ?? 0
        let margin = max(0, best.score - second)
        let confidence = min(1, margin / max(abs(best.score), 1e-9))
        guard confidence >= configuration.minimumKeyConfidence else { return nil }

        return MusicalKey(tonicPitchClass: best.tonic, mode: best.mode, confidence: confidence)
    }

    private static func chromaForWindow(_ samples: [Double], sampleRate: Double) -> [Double] {
        let n = samples.count
        guard n > 1 else { return Array(repeating: 0, count: 12) }
        var windowed = Array(repeating: 0.0, count: n)
        for index in 0..<n {
            let hann = 0.5 - 0.5 * cos((2 * Double.pi * Double(index)) / Double(n - 1))
            windowed[index] = samples[index] * hann
        }

        var chroma = Array(repeating: 0.0, count: 12)
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            guard frequency < sampleRate * 0.45 else { continue }
            let power = goertzelPower(windowed, sampleRate: sampleRate, frequency: frequency)
            let pitchClass = (midi % 12 + 12) % 12
            chroma[pitchClass] += sqrt(max(0, power))
        }
        return chroma
    }

    private static func goertzelPower(_ samples: [Double], sampleRate: Double, frequency: Double) -> Double {
        let omega = 2.0 * Double.pi * frequency / sampleRate
        let coefficient = 2.0 * cos(omega)
        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0
        for sample in samples {
            s0 = sample + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        return max(0, s1 * s1 + s2 * s2 - coefficient * s1 * s2)
    }

    private static func rotatedProfile(_ profile: [Double], tonic: Int) -> [Double] {
        (0..<12).map { pitchClass in
            profile[(pitchClass - tonic + 12) % 12]
        }
    }

    private static func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let dot = zip(lhs, rhs).reduce(0.0) { $0 + $1.0 * $1.1 }
        let left = sqrt(lhs.reduce(0.0) { $0 + $1 * $1 })
        let right = sqrt(rhs.reduce(0.0) { $0 + $1 * $1 })
        guard left > 1e-12, right > 1e-12 else { return 0 }
        return dot / (left * right)
    }

    private static func uniformlySpacedWindowStarts(sampleCount: Int, windowSize: Int, count: Int) -> [Int] {
        let lastStart = max(0, sampleCount - windowSize)
        guard count > 1, lastStart > 0 else { return [0] }
        return (0..<count).map { index in
            Int((Double(index) * Double(lastStart) / Double(count - 1)).rounded())
        }
    }

    private static func rms(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Double(samples.count))
    }
}
