import Foundation

struct AnalysisReusableChordSpectralBin: Sendable {
    let pitchClass: Int
    let coefficient: Double
    let bassWeight: Double?
}

struct AnalysisReusableChordSpectralKernel: Sendable {
    let sampleRate: Double
    let windowSampleCount: Int
    let hannWeights: [Double]
    let bins: [AnalysisReusableChordSpectralBin]

    init(sampleRate: Double, windowSampleCount: Int) {
        precondition(sampleRate.isFinite && sampleRate > 0)
        precondition(windowSampleCount > 0)
        self.sampleRate = sampleRate
        self.windowSampleCount = windowSampleCount

        if windowSampleCount > 1 {
            hannWeights = (0..<windowSampleCount).map { index in
                0.5 - 0.5 * cos(
                    (2 * Double.pi * Double(index)) / Double(windowSampleCount - 1)
                )
            }
        } else {
            hannWeights = [1]
        }

        var preparedBins: [AnalysisReusableChordSpectralBin] = []
        preparedBins.reserveCapacity(48)
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            guard frequency < sampleRate * 0.45 else { continue }
            let omega = 2 * Double.pi * frequency / sampleRate
            let coefficient = 2 * cos(omega)
            let pitchClass = (midi % 12 + 12) % 12
            let bassWeight: Double? = midi <= 59
                ? 1.0 + Double(59 - midi) / 46.0
                : nil
            preparedBins.append(
                .init(
                    pitchClass: pitchClass,
                    coefficient: coefficient,
                    bassWeight: bassWeight
                )
            )
        }
        bins = preparedBins
    }
}

struct AnalysisReusableChordSpectralWorkspace {
    let kernel: AnalysisReusableChordSpectralKernel
    var windowedScratch: [Double]
    private(set) var classificationCount = 0

    init(sampleRate: Double, windowSampleCount: Int) {
        kernel = .init(sampleRate: sampleRate, windowSampleCount: windowSampleCount)
        windowedScratch = Array(repeating: 0, count: windowSampleCount)
    }

    mutating func markClassification() {
        classificationCount += 1
    }
}

enum AnalysisReusableChordFrameClassifier {
    private struct Candidate {
        let root: Int
        let quality: ChordQuality
        let score: Double
        let coverage: Double
        let requiredSupport: Double
    }

    private struct SpectrumEvidence {
        let chroma: [Double]
        let bassPitchClass: Int?
        let bassDominance: Double
    }

    static func classify(
        samples: [Double],
        workspace: inout AnalysisReusableChordSpectralWorkspace,
        sampleRate: Double,
        configuration: MusicAnalysisConfiguration,
        vocabulary: ChordVocabularyMode = .conservativeMajorMinor
    ) -> (label: String, confidence: Double?) {
        guard !samples.isEmpty else { return ("N", 1) }
        guard samples.count == workspace.kernel.windowSampleCount,
              sampleRate == workspace.kernel.sampleRate else {
            return ChordFrameClassifier.classify(
                samples: samples,
                sampleRate: sampleRate,
                configuration: configuration,
                vocabulary: vocabulary
            )
        }
        guard rms(samples) >= configuration.noChordRMS else { return ("N", 1) }

        workspace.markClassification()
        let evidence = spectrumEvidence(samples, workspace: &workspace)
        let total = evidence.chroma.reduce(0, +)
        guard total > 1e-12 else { return ("X", nil) }
        let chroma = evidence.chroma.map { $0 / total }
        let maximum = chroma.max() ?? 0
        let activePitchClasses = chroma.filter { $0 >= maximum * 0.16 }.count
        guard activePitchClasses >= 2, activePitchClasses <= 8 else { return ("X", nil) }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(12 * ChordQuality.allCases.count)
        for root in 0..<12 {
            for quality in ChordQuality.allCases {
                let candidateEvidence = candidateScore(
                    chroma: chroma,
                    root: root,
                    quality: quality,
                    bass: evidence.bassPitchClass,
                    bassDominance: evidence.bassDominance
                )
                candidates.append(
                    Candidate(
                        root: root,
                        quality: quality,
                        score: candidateEvidence.score,
                        coverage: candidateEvidence.coverage,
                        requiredSupport: candidateEvidence.requiredSupport
                    )
                )
            }
        }
        candidates.sort {
            if abs($0.score - $1.score) <= 1e-12 {
                if $0.root == $1.root { return $0.quality.rawValue < $1.quality.rawValue }
                return $0.root < $1.root
            }
            return $0.score > $1.score
        }
        guard var best = candidates.first else { return ("X", nil) }

        if best.quality == .augmented {
            if let bass = evidence.bassPitchClass,
               evidence.bassDominance >= 0.10,
               let bassCandidate = candidates.first(where: { $0.quality == .augmented && $0.root == bass }),
               bassCandidate.score >= best.score - 0.08 {
                best = bassCandidate
            } else {
                return ("X", nil)
            }
        }

        let runnerUp = candidates.first { $0.root != best.root || $0.quality != best.quality }
        let secondScore = runnerUp?.score ?? 0
        let margin = max(0, best.score - secondScore) / max(best.score, 1e-9)
        let scoreStrength = max(0, min(1, (best.score - 0.48) / 0.52))
        let confidence = min(1, 0.58 * margin + 0.30 * scoreStrength + 0.12 * best.requiredSupport)

        guard best.score >= configuration.minimumChordTemplateScore,
              confidence >= configuration.minimumChordConfidence else {
            return ("X", confidence)
        }

        if best.quality.isConservative, vocabulary == .conservativeMajorMinor {
            if let complex = candidates.first(where: {
                !$0.quality.isConservative && $0.root == best.root
            }),
               complex.requiredSupport >= 0.28,
               best.score - complex.score < 0.035 {
                return ("X", confidence)
            }
        }

        if !best.quality.isConservative, vocabulary == .conservativeMajorMinor {
            return ("X", confidence)
        }

        if let runnerUp,
           runnerUp.quality == best.quality,
           runnerUp.root != best.root,
           margin < 0.025,
           evidence.bassDominance < 0.20 {
            return ("X", confidence)
        }

        let chordTones = Set(best.quality.intervals.map { (best.root + $0) % 12 })
        let inversionBass: Int?
        if let bass = evidence.bassPitchClass,
           bass != best.root,
           chordTones.contains(bass),
           evidence.bassDominance >= 0.16 {
            inversionBass = bass
        } else {
            inversionBass = nil
        }

        let label = ChordLabelNormalizer.format(
            NormalizedChordLabel(root: best.root, quality: best.quality, bass: inversionBass),
            includeInversion: vocabulary == .extendedDiagnostic
        )
        return (label, confidence)
    }

    private static func candidateScore(
        chroma: [Double],
        root: Int,
        quality: ChordQuality,
        bass: Int?,
        bassDominance: Double
    ) -> (score: Double, coverage: Double, requiredSupport: Double) {
        let intervals = quality.intervals
        var template = Array(repeating: 0.0, count: 12)
        let weights: [Double] = intervals.count == 4
            ? [1.0, 0.84, 0.72, 0.68]
            : [1.0, 0.84, 0.72]
        for (index, interval) in intervals.enumerated() {
            template[(root + interval) % 12] = weights[min(index, weights.count - 1)]
        }

        let dot = zip(chroma, template).reduce(0.0) { $0 + $1.0 * $1.1 }
        let chromaNorm = sqrt(chroma.reduce(0.0) { $0 + $1 * $1 })
        let templateNorm = sqrt(template.reduce(0.0) { $0 + $1 * $1 })
        let cosineScore = chromaNorm > 1e-12 && templateNorm > 1e-12
            ? dot / (chromaNorm * templateNorm)
            : 0
        let coverage = intervals.reduce(0.0) { $0 + chroma[(root + $1) % 12] }
        let maxBin = max(chroma.max() ?? 0, 1e-12)
        let requiredSupport = quality.discriminatingIntervals.isEmpty
            ? 1
            : quality.discriminatingIntervals.map { chroma[(root + $0) % 12] / maxBin }.min() ?? 0
        let rootSupport = chroma[root] / maxBin
        let bassRootBonus = bass == root ? min(1, bassDominance) : 0

        var score = 0.54 * cosineScore
            + 0.31 * coverage
            + 0.08 * rootSupport
            + 0.07 * bassRootBonus
        if !quality.discriminatingIntervals.isEmpty {
            score *= 0.70 + 0.30 * min(1, requiredSupport)
        }
        return (score, coverage, requiredSupport)
    }

    private static func spectrumEvidence(
        _ samples: [Double],
        workspace: inout AnalysisReusableChordSpectralWorkspace
    ) -> SpectrumEvidence {
        guard samples.count > 1 else {
            return SpectrumEvidence(chroma: Array(repeating: 0, count: 12), bassPitchClass: nil, bassDominance: 0)
        }

        for index in samples.indices {
            workspace.windowedScratch[index] = samples[index] * workspace.kernel.hannWeights[index]
        }

        var chroma = Array(repeating: 0.0, count: 12)
        var bassChroma = Array(repeating: 0.0, count: 12)
        for bin in workspace.kernel.bins {
            let amplitude = sqrt(max(0, goertzelPower(
                workspace.windowedScratch,
                coefficient: bin.coefficient
            )))
            chroma[bin.pitchClass] += amplitude
            if let bassWeight = bin.bassWeight {
                bassChroma[bin.pitchClass] += amplitude * bassWeight
            }
        }

        let totalBass = bassChroma.reduce(0, +)
        let bassIndex = bassChroma.indices.max(by: { bassChroma[$0] < bassChroma[$1] })
        let bestBass = bassIndex.map { bassChroma[$0] } ?? 0
        let sortedBass = bassChroma.sorted(by: >)
        let secondBass = sortedBass.dropFirst().first ?? 0
        let dominance = totalBass > 1e-12 ? max(0, (bestBass - secondBass) / totalBass) : 0

        return SpectrumEvidence(
            chroma: chroma,
            bassPitchClass: bestBass > 1e-10 ? bassIndex : nil,
            bassDominance: dominance
        )
    }

    private static func goertzelPower(_ samples: [Double], coefficient: Double) -> Double {
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

    private static func rms(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Double(samples.count))
    }
}
