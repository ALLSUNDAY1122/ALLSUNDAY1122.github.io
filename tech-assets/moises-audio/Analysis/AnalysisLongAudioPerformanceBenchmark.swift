import Foundation

public struct AnalysisLongAudioBudget: Codable, Equatable, Sendable {
    public let durationSeconds: Double
    public let sourceSampleRate: Double
    public let analysisSampleRate: Double
    public let sourcePCMBytes: Int64
    public let preparedPCMBytes: Int64
    public let estimatedTempoEnvelopeBytes: Int64
    public let estimatedBoundedWindowBytes: Int64
    public let estimatedTimelineBytes: Int64
    public let estimatedPeakAdditionalBytes: Int64
    public let legacyWholeTrackDoubleBytes: Int64
    public let estimatedPeakReductionRatio: Double

    enum CodingKeys: String, CodingKey {
        case durationSeconds = "duration_seconds"
        case sourceSampleRate = "source_sample_rate"
        case analysisSampleRate = "analysis_sample_rate"
        case sourcePCMBytes = "source_pcm_bytes"
        case preparedPCMBytes = "prepared_pcm_bytes"
        case estimatedTempoEnvelopeBytes = "estimated_tempo_envelope_bytes"
        case estimatedBoundedWindowBytes = "estimated_bounded_window_bytes"
        case estimatedTimelineBytes = "estimated_timeline_bytes"
        case estimatedPeakAdditionalBytes = "estimated_peak_additional_bytes"
        case legacyWholeTrackDoubleBytes = "legacy_whole_track_double_bytes"
        case estimatedPeakReductionRatio = "estimated_peak_reduction_ratio"
    }
}

public struct AnalysisPreparationBenchmarkRow: Codable, Equatable, Sendable {
    public let durationSeconds: Double
    public let sourceSampleRate: Double
    public let analysisSampleRate: Double
    public let sourceSampleCount: Int
    public let analysisSampleCount: Int
    public let wallSeconds: Double
    public let realtimeFactor: Double?
    public let syntheticOnly: Bool
    public let parityEligible: Bool

    enum CodingKeys: String, CodingKey {
        case durationSeconds = "duration_seconds"
        case sourceSampleRate = "source_sample_rate"
        case analysisSampleRate = "analysis_sample_rate"
        case sourceSampleCount = "source_sample_count"
        case analysisSampleCount = "analysis_sample_count"
        case wallSeconds = "wall_seconds"
        case realtimeFactor = "rtf"
        case syntheticOnly = "synthetic_only"
        case parityEligible = "parity_eligible"
    }
}

public enum AnalysisLongAudioPerformanceBenchmark {
    public static func estimate(sourceSampleRate: Double, durationSeconds: Double, configuration: MusicAnalysisConfiguration = .productBaseline) -> AnalysisLongAudioBudget {
        let preparation = AnalysisWorkingSetPolicy.estimate(sourceSampleRate: sourceSampleRate, durationSeconds: durationSeconds)
        let analysisRate = preparation.analysisSampleRate
        let tempoHop = min(configuration.analysisHopSize, max(32, Int((analysisRate * 0.010).rounded())))
        let tempoFrameCount = tempoHop > 0 ? max(0, Int(ceil(Double(preparation.analysisSampleCount) / Double(tempoHop)))) : 0
        let tempoEnvelopeBytes = Int64(tempoFrameCount) * Int64(MemoryLayout<Double>.stride)
        let chordWindowSamples = max(256, Int((configuration.chordWindowSeconds * analysisRate).rounded()))
        let keyWindowSamples = max(256, configuration.analysisWindowSize)
        let boundedWindowBytes = Int64(max(chordWindowSamples, keyWindowSamples)) * Int64(MemoryLayout<Double>.stride)
        let chordHopSamples = max(1, Int((configuration.chordHopSeconds * analysisRate).rounded()))
        let timelineFrames = max(0, Int(ceil(Double(preparation.analysisSampleCount) / Double(chordHopSamples))))
        let timelineBytes = Int64(timelineFrames) * 48
        let transient = max(tempoEnvelopeBytes, boundedWindowBytes + timelineBytes)
        let peakAdditional = preparation.analysisPCMBytes + transient
        let legacy = preparation.avoidedLegacyWholeTrackDoubleBytes
        let ratio = peakAdditional > 0 ? Double(legacy) / Double(peakAdditional) : 0
        return AnalysisLongAudioBudget(durationSeconds: durationSeconds, sourceSampleRate: sourceSampleRate, analysisSampleRate: analysisRate, sourcePCMBytes: preparation.sourcePCMBytes, preparedPCMBytes: preparation.analysisPCMBytes, estimatedTempoEnvelopeBytes: tempoEnvelopeBytes, estimatedBoundedWindowBytes: boundedWindowBytes, estimatedTimelineBytes: timelineBytes, estimatedPeakAdditionalBytes: peakAdditional, legacyWholeTrackDoubleBytes: legacy, estimatedPeakReductionRatio: ratio)
    }

    public static func benchmarkPreparation(signal: AnalysisSignal, syntheticOnly: Bool) -> (prepared: AnalysisSignal, row: AnalysisPreparationBenchmarkRow) {
        let start = ContinuousClock.now
        let result = AnalysisWorkingSetPolicy.prepare(signal: signal)
        let elapsed = ContinuousClock.now - start
        let components = elapsed.components
        let wallSeconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        let duration = signal.durationSeconds
        return (result.signal, AnalysisPreparationBenchmarkRow(durationSeconds: duration, sourceSampleRate: signal.sampleRate, analysisSampleRate: result.signal.sampleRate, sourceSampleCount: signal.monoSamples.count, analysisSampleCount: result.signal.monoSamples.count, wallSeconds: wallSeconds, realtimeFactor: duration > 0 ? wallSeconds / duration : nil, syntheticOnly: syntheticOnly, parityEligible: false))
    }
}
