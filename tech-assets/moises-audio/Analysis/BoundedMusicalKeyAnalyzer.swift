import Foundation

public enum BoundedMusicalKeyAnalyzer {
    private static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    private struct KeyCandidate {
        let tonic: Int
        let mode: String
        let score: Double
        let triadSupport: Double
    }

    private struct KeyEvidence {
        let best: KeyCandidate
        let normalizedMargin: Double
        let activePitchClasses: Int
    }

    private struct ModalCandidate {
        let tonic: Int
        let mode: String
        let score: Double
        let tonicSupport: Double
        let alteredSupport: Double
        let conventionalSupport: Double
    }

    private static let modalDefinitions: [(name: String, scale: [Int], altered: Int, conventional: Int, qualityThird: Int)] = [
        ("dorian", [0, 2, 3, 5, 7, 9, 10], 9, 8, 3),
        ("phrygian", [0, 1, 3, 5, 7, 8, 10], 1, 2, 3),
        ("lydian", [0, 2, 4, 6, 7, 9, 11], 6, 5, 4),
        ("mixolydian", [0, 2, 4, 5, 7, 9, 10], 10, 11, 4),
        ("locrian", [0, 1, 3, 5, 6, 8, 10], 6, 7, 3)
    ]

    public static func analyze(signal: AnalysisSignal, configuration: MusicAnalysisConfiguration = .productBaseline) -> MusicalKey? {
        let samples = signal.monoSamples
        guard samples.count >= configuration.analysisWindowSize,
              AnalysisWorkingSetPolicy.rms(samples, maximumSamples: AnalysisWorkingSetPolicy.maximumRMSProbeSamples) > 1e-5 else { return nil }
        let windowSize = configuration.analysisWindowSize
        let availableWindows = max(1, (samples.count - windowSize) / max(1, configuration.analysisHopSize) + 1)
        let selectedCount = min(configuration.maximumKeyWindows, availableWindows)
        let starts = uniformlySpacedWindowStarts(sampleCount: samples.count, windowSize: windowSize, count: selectedCount)
        var localChromas: [[Double]] = []
        localChromas.reserveCapacity(starts.count)
        for start in starts {
            let local = chromaForWindow(samples, start: start, count: windowSize, sampleRate: signal.sampleRate)
            let localTotal = local.reduce(0, +)
            guard localTotal > 1e-10 else { continue }
            localChromas.append(local.map { $0 / localTotal })
        }
        guard localChromas.count >= 2 else { return nil }
        let chroma = normalizedSum(localChromas)
        guard let global = keyEvidence(chroma), global.activePitchClasses >= 3 else { return nil }
        let ranked = rankedCandidates(chroma)
        if let relative = relativeCounterpart(of: global.best, in: ranked) {
            let relativeGap = max(0, global.best.score - relative.score) / max(abs(global.best.score), 1e-9)
            let tonicGap = abs(chroma[global.best.tonic] - chroma[relative.tonic])
            if relativeGap < configuration.keyRelativeAmbiguityMargin, tonicGap < 0.035 { return nil }
        }
        if global.activePitchClasses >= 5,
           let modal = bestModalCandidate(chroma),
           modal.tonic == global.best.tonic,
           modal.tonicSupport >= 0.55,
           modal.alteredSupport >= 0.20,
           modal.alteredSupport > modal.conventionalSupport * 1.20,
           modal.score >= 0.72 { return nil }
        let halves = temporalHalves(localChromas)
        var temporalAgreement = 1.0
        if let first = keyEvidence(halves.first),
           let second = keyEvidence(halves.second),
           first.activePitchClasses >= 5,
           second.activePitchClasses >= 5,
           first.normalizedMargin >= configuration.keyModulationMargin,
           second.normalizedMargin >= configuration.keyModulationMargin,
           (first.best.tonic != second.best.tonic || first.best.mode != second.best.mode) {
            return nil
        } else if let first = keyEvidence(halves.first), let second = keyEvidence(halves.second) {
            let agreeingHalves = [first.best, second.best].filter { $0.tonic == global.best.tonic && $0.mode == global.best.mode }.count
            temporalAgreement = Double(agreeingHalves) / 2
        }
        let calibratedMargin = min(1, global.normalizedMargin / 0.08)
        let confidence = clamp01(calibratedMargin * 0.68 + global.best.triadSupport * 0.20 + temporalAgreement * 0.12)
        guard confidence >= configuration.minimumKeyConfidence else { return nil }
        return MusicalKey(tonicPitchClass: global.best.tonic, mode: global.best.mode, confidence: confidence)
    }

    private static func chromaForWindow(_ samples: [Float], start: Int, count: Int, sampleRate: Double) -> [Double] {
        let lower = max(0, min(samples.count, start))
        let upper = max(lower, min(samples.count, start + count))
        let n = upper - lower
        guard n > 1 else { return Array(repeating: 0, count: 12) }
        var windowed = Array(repeating: 0.0, count: n)
        for localIndex in 0..<n {
            let hann = 0.5 - 0.5 * cos((2 * Double.pi * Double(localIndex)) / Double(n - 1))
            windowed[localIndex] = Double(AnalysisWorkingSetPolicy.boundedFinite(samples[lower + localIndex])) * hann
        }
        var chroma = Array(repeating: 0.0, count: 12)
        for midi in 36...83 {
            let frequency = 440 * pow(2, Double(midi - 69) / 12)
            guard frequency < sampleRate * 0.45 else { continue }
            let power = goertzelPower(windowed, sampleRate: sampleRate, frequency: frequency)
            chroma[(midi % 12 + 12) % 12] += sqrt(max(0, power))
        }
        return chroma
    }

    private static func goertzelPower(_ samples: [Double], sampleRate: Double, frequency: Double) -> Double {
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
        var s0 = 0.0, s1 = 0.0, s2 = 0.0
        for sample in samples { s0 = sample + coefficient * s1 - s2; s2 = s1; s1 = s0 }
        return max(0, s1 * s1 + s2 * s2 - coefficient * s1 * s2)
    }

    private static func rankedCandidates(_ chroma: [Double]) -> [KeyCandidate] {
        let maxBin = max(chroma.max() ?? 0, 1e-12)
        var candidates: [KeyCandidate] = []
        candidates.reserveCapacity(24)
        for tonic in 0..<12 {
            for (mode, profile, third) in [("major", majorProfile, 4), ("minor", minorProfile, 3)] {
                let profileScore = cosine(chroma, rotatedProfile(profile, tonic: tonic))
                let triadSupport = min(1, (chroma[tonic] * 0.45 + chroma[(tonic + third) % 12] * 0.30 + chroma[(tonic + 7) % 12] * 0.25) / maxBin)
                candidates.append(KeyCandidate(tonic: tonic, mode: mode, score: profileScore * 0.88 + triadSupport * 0.12, triadSupport: triadSupport))
            }
        }
        return candidates.sorted { $0.score > $1.score }
    }

    private static func keyEvidence(_ chroma: [Double]) -> KeyEvidence? {
        let ranked = rankedCandidates(chroma)
        guard ranked.count >= 2 else { return nil }
        let best = ranked[0], second = ranked[1]
        let normalizedMargin = max(0, best.score - second.score) / max(abs(best.score), 1e-9)
        let maxBin = chroma.max() ?? 0
        return KeyEvidence(best: best, normalizedMargin: normalizedMargin, activePitchClasses: chroma.filter { $0 >= maxBin * 0.16 }.count)
    }

    private static func relativeCounterpart(of candidate: KeyCandidate, in ranked: [KeyCandidate]) -> KeyCandidate? {
        let tonic = candidate.mode == "major" ? (candidate.tonic + 9) % 12 : (candidate.tonic + 3) % 12
        let mode = candidate.mode == "major" ? "minor" : "major"
        return ranked.first { $0.tonic == tonic && $0.mode == mode }
    }

    private static func bestModalCandidate(_ chroma: [Double]) -> ModalCandidate? {
        let maxBin = max(chroma.max() ?? 0, 1e-12)
        var best: ModalCandidate?
        for tonic in 0..<12 {
            for definition in modalDefinitions {
                let scale = Set(definition.scale.map { ($0 + tonic) % 12 })
                let coverage = scale.reduce(0.0) { $0 + chroma[$1] }
                let tonicSupport = chroma[tonic] / maxBin
                let alteredSupport = chroma[(tonic + definition.altered) % 12] / maxBin
                let conventionalSupport = chroma[(tonic + definition.conventional) % 12] / maxBin
                let thirdSupport = chroma[(tonic + definition.qualityThird) % 12] / maxBin
                let candidate = ModalCandidate(tonic: tonic, mode: definition.name, score: coverage * 0.58 + tonicSupport * 0.18 + alteredSupport * 0.14 + thirdSupport * 0.10, tonicSupport: tonicSupport, alteredSupport: alteredSupport, conventionalSupport: conventionalSupport)
                if best == nil || candidate.score > best!.score { best = candidate }
            }
        }
        return best
    }

    private static func temporalHalves(_ localChromas: [[Double]]) -> (first: [Double], second: [Double]) {
        let split = max(1, localChromas.count / 2)
        let first = Array(localChromas[..<split])
        let second = split < localChromas.count ? Array(localChromas[split...]) : []
        return (normalizedSum(first), normalizedSum(second))
    }

    private static func normalizedSum(_ chromas: [[Double]]) -> [Double] {
        var result = Array(repeating: 0.0, count: 12)
        for chroma in chromas where chroma.count >= 12 { for pitchClass in 0..<12 { result[pitchClass] += chroma[pitchClass] } }
        let total = result.reduce(0, +)
        guard total > 1e-12 else { return result }
        return result.map { $0 / total }
    }

    private static func rotatedProfile(_ profile: [Double], tonic: Int) -> [Double] { (0..<12).map { profile[($0 - tonic + 12) % 12] } }
    private static func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let dot = zip(lhs, rhs).reduce(0.0) { $0 + $1.0 * $1.1 }
        let left = sqrt(lhs.reduce(0.0) { $0 + $1 * $1 }), right = sqrt(rhs.reduce(0.0) { $0 + $1 * $1 })
        guard left > 1e-12, right > 1e-12 else { return 0 }
        return dot / (left * right)
    }
    private static func uniformlySpacedWindowStarts(sampleCount: Int, windowSize: Int, count: Int) -> [Int] {
        let lastStart = max(0, sampleCount - windowSize)
        guard count > 1, lastStart > 0 else { return [0] }
        return (0..<count).map { Int((Double($0) * Double(lastStart) / Double(count - 1)).rounded()) }
    }
    private static func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }
}
