import Foundation

public struct AnalysisChordSpectralVectorizationBudget: Codable, Equatable, Sendable {
    public let durationSeconds: Double
    public let analysisSampleRate: Double
    public let chordWindowSamples: Int
    public let chordHopSamples: Int
    public let chordFrameCount: Int
    public let activeSpectralBinCount: Int
    public let referenceWindowElementVisits: Int64
    public let interleavedWindowElementVisits: Int64
    public let recurrenceUpdates: Int64
    public let windowTraversalReductionRatio: Double
}

public enum AnalysisChordSpectralVectorizationBudgetEstimator {
    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisChordSpectralVectorizationBudget {
        precondition(sourceSampleRate.isFinite && sourceSampleRate > 0)
        precondition(durationSeconds.isFinite && durationSeconds >= 0)

        let analysisRate = min(sourceSampleRate, configuration.chordAnalysisSampleRate)
        let sampleCount = safeRoundedCount(analysisRate * durationSeconds)
        let windowSamples = max(
            256,
            min(max(1, sampleCount), Int((configuration.chordWindowSeconds * analysisRate).rounded()))
        )
        let hopSamples = max(1, Int((configuration.chordHopSeconds * analysisRate).rounded()))
        let frameCount = sampleCount > 0 ? ceilDiv(sampleCount, hopSamples) : 0
        let binCount = activeBinCount(sampleRate: analysisRate)
        let recurrenceUpdates = saturatingMultiply(
            saturatingMultiply(Int64(frameCount), Int64(binCount)),
            Int64(windowSamples)
        )
        let referenceVisits = recurrenceUpdates
        let interleavedVisits = saturatingMultiply(Int64(frameCount), Int64(windowSamples))
        let ratio = interleavedVisits > 0
            ? Double(referenceVisits) / Double(interleavedVisits)
            : 0

        return .init(
            durationSeconds: durationSeconds,
            analysisSampleRate: analysisRate,
            chordWindowSamples: windowSamples,
            chordHopSamples: hopSamples,
            chordFrameCount: frameCount,
            activeSpectralBinCount: binCount,
            referenceWindowElementVisits: referenceVisits,
            interleavedWindowElementVisits: interleavedVisits,
            recurrenceUpdates: recurrenceUpdates,
            windowTraversalReductionRatio: ratio
        )
    }

    private static func activeBinCount(sampleRate: Double) -> Int {
        var count = 0
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            if frequency < sampleRate * 0.45 { count += 1 }
        }
        return count
    }

    private static func ceilDiv(_ numerator: Int, _ denominator: Int) -> Int {
        guard numerator > 0 else { return 0 }
        return 1 + (numerator - 1) / max(1, denominator)
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
}
