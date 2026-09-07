import Foundation

public struct AnalysisExtremeDurationRetentionPlan: Codable, Equatable, Sendable {
    public let naturalTempoFrameCount: Int
    public let retainedTempoFrameUpperBound: Int
    public let tempoFrameStride: Int
    public let tempoHopSamples: Int
    public let tempoResolutionSafe: Bool
    public let naturalChordFrameCount: Int
    public let retainedChordFrameUpperBound: Int
    public let chordFrameStride: Int
    public let chordHopSamples: Int
    public let chordWindowRetentionSafe: Bool
    public let naturalSectionEnergyFrameCount: Int
    public let retainedSectionEnergyFrameCount: Int
    public let sectionFrameStrideEquivalent: Int
    public let sectionResolutionSafe: Bool
    public let compressionApplied: Bool

    public var compressedDomains: [String] {
        var result: [String] = []
        if tempoFrameStride > 1 { result.append("TEMPO_ONSET") }
        if chordFrameStride > 1 { result.append("CHORD_PREDECISION") }
        if retainedSectionEnergyFrameCount < naturalSectionEnergyFrameCount { result.append("SECTION_ENERGY") }
        return result
    }

    public var suppressedDomains: [String] {
        var result: [String] = []
        if !tempoResolutionSafe { result.append("TEMPO_ONSET") }
        if !chordWindowRetentionSafe { result.append("CHORD_PREDECISION") }
        if !sectionResolutionSafe { result.append("SECTION_ENERGY") }
        return result
    }
}

public enum AnalysisExtremeDurationRetentionPolicy {
    /// Resource-cardinality limits only. These are not quality/PARITY thresholds.
    /// Normal songs remain on the exact W29/W30 cadence whenever their natural
    /// feature counts fit below these limits. The Chord cap intentionally keeps
    /// the default 0.25 s cadence exact through 24-hour 8 kHz Analysis input.
    public static let maximumTempoFrames = 1_048_576
    public static let maximumChordFrameDecisions = 524_288
    public static let maximumSectionEnergyFrames = 262_144

    public static func plan(
        sampleRate: Double,
        sampleCount: Int,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisExtremeDurationRetentionPlan {
        guard sampleRate.isFinite, sampleRate > 0, sampleCount > 0,
              durationSeconds.isFinite, durationSeconds > 0 else {
            return .init(
                naturalTempoFrameCount: 0,
                retainedTempoFrameUpperBound: 0,
                tempoFrameStride: 1,
                tempoHopSamples: 1,
                tempoResolutionSafe: true,
                naturalChordFrameCount: 0,
                retainedChordFrameUpperBound: 0,
                chordFrameStride: 1,
                chordHopSamples: 1,
                chordWindowRetentionSafe: true,
                naturalSectionEnergyFrameCount: 0,
                retainedSectionEnergyFrameCount: 0,
                sectionFrameStrideEquivalent: 1,
                sectionResolutionSafe: true,
                compressionApplied: false
            )
        }

        let tempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((sampleRate * 0.046).rounded()))
        )
        let baseTempoHop = min(
            configuration.analysisHopSize,
            max(32, Int((sampleRate * 0.010).rounded()))
        )
        let naturalTempo = sampleCount >= tempoFrameSize
            ? 1 + (sampleCount - tempoFrameSize) / max(1, baseTempoHop)
            : 0
        let tempoStride = max(1, ceilDiv(naturalTempo, maximumTempoFrames))
        let tempoHop = saturatingMultiply(baseTempoHop, tempoStride)
        // W31 computes the original natural-cadence onset first, then max-pools
        // each contiguous stride group. This keeps transient coverage while
        // bounding retained cardinality.
        let candidateTempo = ceilDiv(naturalTempo, tempoStride)
        let envelopeRate = sampleRate / Double(max(1, tempoHop))
        let maximumBeatFrequency = configuration.tempoRange.upperBound / 60.0
        let tempoSafe = envelopeRate + 1e-12 >= maximumBeatFrequency * 2.0
        let retainedTempo = tempoSafe ? candidateTempo : 0

        let baseChordHop = max(1, Int((configuration.chordHopSeconds * sampleRate).rounded()))
        let naturalChord = ceilDiv(sampleCount, baseChordHop)
        let chordStride = max(1, ceilDiv(naturalChord, maximumChordFrameDecisions))
        let chordHop = saturatingMultiply(baseChordHop, chordStride)
        let chordWindow = max(
            256,
            min(sampleCount, Int((configuration.chordWindowSeconds * sampleRate).rounded()))
        )
        let chordSafe = chordHop <= chordWindow
        let candidateChord = ceilDiv(sampleCount, max(1, chordHop))
        let retainedChord = chordSafe ? candidateChord : 1

        let naturalSection = max(
            1,
            safeRoundedCount(durationSeconds * AnalysisSectionEnergyFeatureExtractor.targetFramesPerSecond)
        )
        let candidateSection = min(naturalSection, maximumSectionEnergyFrames)
        let sectionStride = max(1, ceilDiv(naturalSection, max(1, candidateSection)))
        let effectiveSectionRate = Double(candidateSection) / durationSeconds
        let sectionSafe = effectiveSectionRate * configuration.minimumSectionSeconds >= 1.0
        let retainedSection = sectionSafe ? candidateSection : 0

        return .init(
            naturalTempoFrameCount: naturalTempo,
            retainedTempoFrameUpperBound: retainedTempo,
            tempoFrameStride: tempoStride,
            tempoHopSamples: tempoHop,
            tempoResolutionSafe: tempoSafe,
            naturalChordFrameCount: naturalChord,
            retainedChordFrameUpperBound: retainedChord,
            chordFrameStride: chordStride,
            chordHopSamples: chordHop,
            chordWindowRetentionSafe: chordSafe,
            naturalSectionEnergyFrameCount: naturalSection,
            retainedSectionEnergyFrameCount: retainedSection,
            sectionFrameStrideEquivalent: sectionStride,
            sectionResolutionSafe: sectionSafe,
            compressionApplied: tempoStride > 1 || chordStride > 1 || candidateSection < naturalSection
                || !tempoSafe || !chordSafe || !sectionSafe
        )
    }

    private static func ceilDiv(_ numerator: Int, _ denominator: Int) -> Int {
        guard numerator > 0 else { return 0 }
        let divisor = max(1, denominator)
        return 1 + (numerator - 1) / divisor
    }

    private static func saturatingMultiply(_ lhs: Int, _ rhs: Int) -> Int {
        let product = lhs.multipliedReportingOverflow(by: rhs)
        return product.overflow ? Int.max : max(1, product.partialValue)
    }

    private static func safeRoundedCount(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        if value >= Double(Int.max) { return Int.max }
        return Int(value.rounded())
    }
}
