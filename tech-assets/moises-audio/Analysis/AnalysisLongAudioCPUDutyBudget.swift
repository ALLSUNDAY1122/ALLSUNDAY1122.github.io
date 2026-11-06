import Foundation

public struct AnalysisLongAudioCPUDutyBudget: Codable, Equatable, Sendable {
    public let durationSeconds: Double
    public let analysisSampleRate: Double
    public let tempoFrameSize: Int
    public let tempoNaturalFrameCount: Int
    public let tempoUsesRollingReuse: Bool
    public let baselineTempoWindowSquareTerms: Int64
    public let rollingTempoSquareUpdatesUpperBound: Int64
    public let rollingTempoPeriodicRebaseSquareTermsUpperBound: Int64
    public let tempoSquareTermReductionRatio: Double
    public let chordWindowSamples: Int
    public let chordFrameCount: Int
    public let chordSpectralBinCount: Int
    public let baselineChordSetupTranscendentalEvaluations: Int64
    public let reusedChordSetupTranscendentalEvaluations: Int64
    public let chordSetupTranscendentalReductionRatio: Double
    public let goertzelSampleIterationsUnchanged: Int64
}

public enum AnalysisLongAudioCPUDutyBudgetEstimator {
    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisLongAudioCPUDutyBudget {
        precondition(sourceSampleRate.isFinite && sourceSampleRate > 0)
        precondition(durationSeconds.isFinite && durationSeconds >= 0)

        let analysisRate = min(sourceSampleRate, configuration.chordAnalysisSampleRate)
        let sampleCount = safeRoundedCount(analysisRate * durationSeconds)
        let tempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((analysisRate * 0.046).rounded()))
        )
        let tempoHop = min(
            configuration.analysisHopSize,
            max(32, Int((analysisRate * 0.010).rounded()))
        )
        let tempoFrames = sampleCount >= tempoFrameSize
            ? 1 + (sampleCount - tempoFrameSize) / max(1, tempoHop)
            : 0
        let baselineTempoTerms = saturatingMultiply(
            Int64(tempoFrames),
            Int64(tempoFrameSize)
        )
        let rollingEnabled = durationSeconds >= AnalysisLongAudioCPUDutyPolicy.rollingTempoMinimumDurationSeconds
        let rollingUpdates: Int64
        let rebaseTerms: Int64
        if rollingEnabled, sampleCount > 0 {
            rollingUpdates = saturatingAdd(
                Int64(sampleCount),
                Int64(max(0, sampleCount - tempoFrameSize))
            )
            let rebases = ceilDiv(
                tempoFrames,
                AnalysisLongAudioCPUDutyPolicy.rollingTempoRebaseFrameInterval
            )
            rebaseTerms = saturatingMultiply(Int64(rebases), Int64(tempoFrameSize))
        } else {
            rollingUpdates = baselineTempoTerms
            rebaseTerms = 0
        }
        let optimizedTempoTerms = saturatingAdd(rollingUpdates, rebaseTerms)
        let tempoRatio = optimizedTempoTerms > 0
            ? Double(baselineTempoTerms) / Double(optimizedTempoTerms)
            : 0

        let chordWindowSamples = max(
            256,
            min(max(1, sampleCount), Int((configuration.chordWindowSeconds * analysisRate).rounded()))
        )
        let chordHopSamples = max(1, Int((configuration.chordHopSeconds * analysisRate).rounded()))
        let chordFrames = sampleCount > 0 ? ceilDiv(sampleCount, chordHopSamples) : 0
        let activeBins = activeChordBinCount(sampleRate: analysisRate)
        let setupPerFrame = saturatingAdd(
            Int64(chordWindowSamples),
            Int64(48 + activeBins)
        )
        let baselineChordSetup = saturatingMultiply(Int64(chordFrames), setupPerFrame)
        let reusedChordSetup = chordFrames > 0 ? setupPerFrame : 0
        let chordSetupRatio = reusedChordSetup > 0
            ? Double(baselineChordSetup) / Double(reusedChordSetup)
            : 0
        let goertzelIterations = saturatingMultiply(
            saturatingMultiply(Int64(chordFrames), Int64(activeBins)),
            Int64(chordWindowSamples)
        )

        return .init(
            durationSeconds: durationSeconds,
            analysisSampleRate: analysisRate,
            tempoFrameSize: tempoFrameSize,
            tempoNaturalFrameCount: tempoFrames,
            tempoUsesRollingReuse: rollingEnabled,
            baselineTempoWindowSquareTerms: baselineTempoTerms,
            rollingTempoSquareUpdatesUpperBound: rollingUpdates,
            rollingTempoPeriodicRebaseSquareTermsUpperBound: rebaseTerms,
            tempoSquareTermReductionRatio: tempoRatio,
            chordWindowSamples: chordWindowSamples,
            chordFrameCount: chordFrames,
            chordSpectralBinCount: activeBins,
            baselineChordSetupTranscendentalEvaluations: baselineChordSetup,
            reusedChordSetupTranscendentalEvaluations: reusedChordSetup,
            chordSetupTranscendentalReductionRatio: chordSetupRatio,
            goertzelSampleIterationsUnchanged: goertzelIterations
        )
    }

    private static func activeChordBinCount(sampleRate: Double) -> Int {
        var result = 0
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            if frequency < sampleRate * 0.45 { result += 1 }
        }
        return result
    }

    private static func ceilDiv(_ numerator: Int, _ denominator: Int) -> Int {
        guard numerator > 0 else { return 0 }
        let divisor = max(1, denominator)
        return 1 + (numerator - 1) / divisor
    }

    private static func safeRoundedCount(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        if value >= Double(Int.max) { return Int.max }
        return Int(value.rounded())
    }

    private static func saturatingMultiply(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? Int64.max : max(0, result.partialValue)
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int64.max : max(0, result.partialValue)
    }
}
