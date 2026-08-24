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

    var isConservative: Bool { self == .major || self == .minor }
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
            "C": 0, "B#": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
            "E": 4, "Fb": 4, "E#": 5, "F": 5, "F#": 6, "Gb": 6, "G": 7,
            "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11
        ]
        return aliases[normalized]
    }
}

enum ChordFrameClassifier {
    static func classify(
        samples: [Double],
        sampleRate: Double,
        configuration: MusicAnalysisConfiguration,
        vocabulary: ChordVocabularyMode = .conservativeMajorMinor
    ) -> (label: String, confidence: Double?) {
        guard !samples.isEmpty else { return ("N", 1) }
        guard rms(samples) >= configuration.noChordRMS else { return ("N", 1) }
        return AnalysisChordDecisionScorer.classify(
            evidence: spectrumEvidence(samples, sampleRate: sampleRate),
            configuration: configuration,
            vocabulary: vocabulary
        )
    }

    static func spectrumEvidence(
        _ samples: [Double],
        sampleRate: Double
    ) -> AnalysisChordSpectrumEvidence {
        guard samples.count > 1 else {
            return AnalysisChordSpectrumEvidence(
                chroma: Array(repeating: 0, count: 12),
                bassPitchClass: nil,
                bassDominance: 0
            )
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
        return AnalysisChordSpectrumEvidence(
            chroma: chroma,
            bassPitchClass: bestBass > 1e-10 ? bassIndex : nil,
            bassDominance: dominance
        )
    }

    private static func goertzelPower(_ samples: [Double], sampleRate: Double, frequency: Double) -> Double {
        let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
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
