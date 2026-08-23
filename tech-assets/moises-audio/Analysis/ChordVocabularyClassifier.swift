import Foundation

enum ChordVocabularyMode: Sendable {
    case conservativeMajorMinor
    case extendedDiagnostic
}

enum ChordQuality: String, CaseIterable, Sendable {
    case major
    case minor
    case dominant7
    case major7
    case minor7
    case sus2
    case sus4
    case diminished
    case augmented

    var suffix: String {
        switch self {
        case .major: return ""
        case .minor: return ":min"
        case .dominant7: return ":7"
        case .major7: return ":maj7"
        case .minor7: return ":min7"
        case .sus2: return ":sus2"
        case .sus4: return ":sus4"
        case .diminished: return ":dim"
        case .augmented: return ":aug"
        }
    }

    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .dominant7: return [0, 4, 7, 10]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        }
    }

    var discriminatingIntervals: [Int] {
        switch self {
        case .dominant7: return [10]
        case .major7: return [11]
        case .minor7: return [10]
        case .sus2: return [2]
        case .sus4: return [5]
        case .diminished: return [6]
        case .augmented: return [8]
        case .major, .minor: return []
        }
    }

    var isConservative: Bool {
        self == .major || self == .minor
    }
}

struct NormalizedChordLabel: Equatable, Sendable {
    let root: Int
    let quality: ChordQuality
    let bass: Int?
}

enum ChordLabelNormalizer {
    static let pitchNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func format(_ chord: NormalizedChordLabel, includeInversion: Bool = true) -> String {
        guard pitchNames.indices.contains(chord.root) else { return "X" }
        var value = pitchNames[chord.root] + chord.quality.suffix
        if includeInversion,
           let bass = chord.bass,
           pitchNames.indices.contains(bass),
           bass != chord.root {
            value += "/" + pitchNames[bass]
        }
        return value
    }

    static func canonicalize(_ raw: String) -> String? {
        if raw == "N" || raw == "X" { return raw }
        guard let parsed = parse(raw) else { return nil }
        return format(parsed)
    }

    static func parse(_ raw: String) -> NormalizedChordLabel? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "N", trimmed != "X" else { return nil }

        let slashParts = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let base = slashParts.first, !base.isEmpty else { return nil }
        let bass = slashParts.count == 2 ? pitchClass(String(slashParts[1])) : nil
        if slashParts.count == 2, bass == nil { return nil }

        let baseParts = base.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let root = pitchClass(String(baseParts[0])) else { return nil }
        let qualityToken = baseParts.count == 2 ? String(baseParts[1]).lowercased() : ""
        guard let quality = quality(for: qualityToken) else { return nil }
        return NormalizedChordLabel(root: root, quality: quality, bass: bass)
    }

    private static func quality(for token: String) -> ChordQuality? {
        switch token {
        case "", "maj", "major": return .major
        case "m", "min", "minor": return .minor
        case "7", "dom7": return .dominant7
        case "maj7", "major7": return .major7
        case "m7", "min7", "minor7": return .minor7
        case "sus2": return .sus2
        case "sus4", "sus": return .sus4
        case "dim", "diminished": return .diminished
        case "aug", "+", "augmented": return .augmented
        default: return nil
        }
    }

    private static func pitchClass(_ token: String) -> Int? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
        let aliases: [String: Int] = [
            "C": 0, "B#": 0,
            "C#": 1, "Db": 1,
            "D": 2,
            "D#": 3, "Eb": 3,
            "E": 4, "Fb": 4,
            "E#": 5, "F": 5,
            "F#": 6, "Gb": 6,
            "G": 7,
            "G#": 8, "Ab": 8,
            "A": 9,
            "A#": 10, "Bb": 10,
            "B": 11, "Cb": 11
        ]
        return aliases[normalized]
    }
}

enum ChordFrameClassifier {
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
        sampleRate: Double,
        configuration: MusicAnalysisConfiguration,
        vocabulary: ChordVocabularyMode = .conservativeMajorMinor
    ) -> (label: String, confidence: Double?) {
        guard !samples.isEmpty else { return ("N", 1) }
        guard rms(samples) >= configuration.noChordRMS else { return ("N", 1) }

        let evidence = spectrumEvidence(samples, sampleRate: sampleRate)
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

        // Augmented pitch-class sets are root-symmetric. Strong low-register evidence can
        // anchor a diagnostic root; otherwise do not manufacture one.
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

    private static func spectrumEvidence(_ samples: [Double], sampleRate: Double) -> SpectrumEvidence {
        guard samples.count > 1 else {
            return SpectrumEvidence(chroma: Array(repeating: 0, count: 12), bassPitchClass: nil, bassDominance: 0)
        }
        var windowed = Array(repeating: 0.0, count: samples.count)
        for index in samples.indices {
            let hann = 0.5 - 0.5 * cos((2 * Double.pi * Double(index)) / Double(samples.count - 1))
            windowed[index] = samples[index] * hann
        }

        var chroma = Array(repeating: 0.0, count: 12)
        var bassChroma = Array(repeating: 0.0, count: 12)
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            guard frequency < sampleRate * 0.45 else { continue }
            let amplitude = sqrt(max(0, goertzelPower(windowed, sampleRate: sampleRate, frequency: frequency)))
            let pitchClass = (midi % 12 + 12) % 12
            chroma[pitchClass] += amplitude
            if midi <= 59 {
                let lowRegisterWeight = 1.0 + Double(59 - midi) / 46.0
                bassChroma[pitchClass] += amplitude * lowRegisterWeight
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

    private static func goertzelPower(_ samples: [Double], sampleRate: Double, frequency: Double) -> Double {
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
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
