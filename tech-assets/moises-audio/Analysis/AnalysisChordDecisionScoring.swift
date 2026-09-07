import Foundation

struct AnalysisChordSpectrumEvidence: Equatable, Sendable {
    let chroma: [Double]
    let bassPitchClass: Int?
    let bassDominance: Double
}

enum AnalysisChordDecisionScorer {
    private struct Candidate {
        let root: Int
        let quality: ChordQuality
        let score: Double
        let coverage: Double
        let requiredSupport: Double
    }

    static func classify(
        evidence: AnalysisChordSpectrumEvidence,
        configuration: MusicAnalysisConfiguration,
        vocabulary: ChordVocabularyMode
    ) -> (label: String, confidence: Double?) {
        guard evidence.chroma.count == 12 else { return ("X", nil) }
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
                let scored = candidateScore(
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
                        score: scored.score,
                        coverage: scored.coverage,
                        requiredSupport: scored.requiredSupport
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
}
