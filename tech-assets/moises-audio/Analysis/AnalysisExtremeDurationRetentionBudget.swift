import Foundation

public struct AnalysisExtremeDurationRetentionBudget: Codable, Equatable, Sendable {
    public let durationSeconds: Double
    public let analysisSampleRate: Double
    public let plan: AnalysisExtremeDurationRetentionPlan
    public let tempoOnsetAndMedianScratchBytes: Int64
    public let keyWindowRetentionBytes: Int64
    public let chordDecisionRetentionBytes: Int64
    public let sectionEnergyRetentionBytes: Int64
    public let tempoAndChordRingBytes: Int64
    public let sectionStructuralScratchBytes: Int64
    public let readerCacheUpperBoundBytes: Int64
    public let estimatedMajorWorker4WorkingSetBytes: Int64
    public let previousUnboundedEstimateBytes: Int64
    public let previousToBoundedReductionRatio: Double
}

public enum AnalysisExtremeDurationRetentionBudgetEstimator {
    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisExtremeDurationRetentionBudget {
        let previous = AnalysisSinglePassPreparedBudget.estimate(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: durationSeconds,
            configuration: configuration
        )
        let analysisRate = previous.analysisSampleRate
        let analysisCount = previous.logicalPreparedSamplesPerSinglePass
        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: analysisRate,
            sampleCount: analysisCount,
            durationSeconds: previous.durationSeconds,
            configuration: configuration
        )

        let tempoBytes = Int64(plan.retainedTempoFrameUpperBound)
            * Int64(MemoryLayout<Double>.stride) * 2
        let availableKeyWindows = analysisCount >= configuration.analysisWindowSize
            ? max(1, (analysisCount - configuration.analysisWindowSize) / max(1, configuration.analysisHopSize) + 1)
            : 0
        let selectedKeyWindows = min(configuration.maximumKeyWindows, availableKeyWindows)
        let keyBytes = Int64(selectedKeyWindows)
            * Int64(configuration.analysisWindowSize)
            * Int64(MemoryLayout<Double>.stride)
        let chordBytes = Int64(plan.retainedChordFrameUpperBound) * 64
        let sectionBytes = Int64(plan.retainedSectionEnergyFrameCount)
            * Int64(MemoryLayout<Float>.stride)

        let tempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((analysisRate * 0.046).rounded()))
        )
        let chordWindow = max(
            256,
            min(max(1, analysisCount), Int((configuration.chordWindowSeconds * analysisRate).rounded()))
        )
        let ringBytes = Int64(max(1, tempoFrameSize) + max(1, chordWindow))
            * Int64(MemoryLayout<Float>.stride)
        let sectionScratch = Int64(SongSectionComplexityBudget.maximumBoundaryCandidates + 1) * 128
        let readerCache = previous.readerCacheUpperBoundBytes
        let total = readerCache + tempoBytes + keyBytes + chordBytes + sectionBytes + ringBytes + sectionScratch
        let ratio = total > 0
            ? Double(previous.estimatedMajorAdditionalWorkingSetBytes) / Double(total)
            : 0

        return .init(
            durationSeconds: previous.durationSeconds,
            analysisSampleRate: analysisRate,
            plan: plan,
            tempoOnsetAndMedianScratchBytes: tempoBytes,
            keyWindowRetentionBytes: keyBytes,
            chordDecisionRetentionBytes: chordBytes,
            sectionEnergyRetentionBytes: sectionBytes,
            tempoAndChordRingBytes: ringBytes,
            sectionStructuralScratchBytes: sectionScratch,
            readerCacheUpperBoundBytes: readerCache,
            estimatedMajorWorker4WorkingSetBytes: total,
            previousUnboundedEstimateBytes: previous.estimatedMajorAdditionalWorkingSetBytes,
            previousToBoundedReductionRatio: ratio
        )
    }
}
