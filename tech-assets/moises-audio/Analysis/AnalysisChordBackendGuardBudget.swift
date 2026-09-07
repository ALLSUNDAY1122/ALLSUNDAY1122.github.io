import Foundation

public struct AnalysisChordBackendGuardBudget: Codable, Equatable, Sendable {
    public let chordFrameCount: Int
    public let verificationFrameLimit: Int
    public let verificationFramesUpperBound: Int
    public let chordWindowSamples: Int
    public let chordSpectralBinCount: Int
    public let baselineVectorizedWindowElementVisits: Int64
    public let maximumExtraReferenceWindowElementVisits: Int64
    public let totalGoertzelRecurrenceUpdates: Int64
    public let maximumExtraVerificationRecurrenceUpdates: Int64
    public let verificationRecurrenceOverheadFraction: Double
}

public enum AnalysisChordBackendGuardBudgetEstimator {
    public static func estimate(
        durationSeconds: Double,
        sourceSampleRate: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisChordBackendGuardBudget {
        precondition(durationSeconds.isFinite && durationSeconds >= 0)
        precondition(sourceSampleRate.isFinite && sourceSampleRate > 0)

        let analysisRate = min(sourceSampleRate, configuration.chordAnalysisSampleRate)
        let sampleCount = safeRoundedCount(analysisRate * durationSeconds)
        let windowSamples = max(
            256,
            min(max(1, sampleCount), Int((configuration.chordWindowSeconds * analysisRate).rounded()))
        )
        let hopSamples = max(1, Int((configuration.chordHopSeconds * analysisRate).rounded()))
        let frameCount = sampleCount > 0 ? ceilDiv(sampleCount, hopSamples) : 0
        let activeBins = activeChordBinCount(sampleRate: analysisRate)
        let verificationFrames = min(
            frameCount,
            AnalysisChordBackendEquivalenceGuard.verificationFrameLimit
        )

        let baselineVisits = saturatingMultiply(Int64(frameCount), Int64(windowSamples))
        let totalUpdates = saturatingMultiply(
            saturatingMultiply(Int64(frameCount), Int64(activeBins)),
            Int64(windowSamples)
        )
        let extraVerification = saturatingMultiply(
            saturatingMultiply(Int64(verificationFrames), Int64(activeBins)),
            Int64(windowSamples)
        )
        let overheadFraction = totalUpdates > 0
            ? Double(extraVerification) / Double(totalUpdates)
            : 0

        return .init(
            chordFrameCount: frameCount,
            verificationFrameLimit: AnalysisChordBackendEquivalenceGuard.verificationFrameLimit,
            verificationFramesUpperBound: verificationFrames,
            chordWindowSamples: windowSamples,
            chordSpectralBinCount: activeBins,
            baselineVectorizedWindowElementVisits: baselineVisits,
            maximumExtraReferenceWindowElementVisits: extraVerification,
            totalGoertzelRecurrenceUpdates: totalUpdates,
            maximumExtraVerificationRecurrenceUpdates: extraVerification,
            verificationRecurrenceOverheadFraction: overheadFraction
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
