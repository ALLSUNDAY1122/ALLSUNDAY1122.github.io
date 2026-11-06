import Foundation

public struct AnalysisSinglePassPreparedPipelineBudget: Codable, Equatable, Sendable {
    public let sourceSampleRate: Double
    public let durationSeconds: Double
    public let analysisSampleRate: Double
    public let sourcePCMBytes: Int64
    public let avoidedWholeTrackPreparedPCMBytes: Int64
    public let readerCacheUpperBoundBytes: Int64
    public let tempoOnsetBufferBytes: Int64
    public let tempoMedianScratchUpperBoundBytes: Int64
    public let keyWindowRetentionUpperBoundBytes: Int64
    public let chordDecisionRetentionUpperBoundBytes: Int64
    public let sectionEnergyFeatureBytes: Int64
    public let tempoAndChordRingBytes: Int64
    public let sectionStructuralScratchUpperBoundBytes: Int64
    public let estimatedMajorAdditionalWorkingSetBytes: Int64
    public let preparedToMajorAdditionalReductionRatio: Double
    public let logicalPreparedSamplesPerSinglePass: Int
}

public enum AnalysisSinglePassPreparedBudget {
    /// Analytical Worker-4 buffer budget for W29. Source PCM remains owned by
    /// AnalysisSignalLoading and is deliberately reported but not counted as a
    /// W29-created additional buffer. Physical-iPhone W23/W24 telemetry remains
    /// authoritative for allocator overhead, VM footprint, thermal and battery.
    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisSinglePassPreparedPipelineBudget {
        let prepared = AnalysisPreparedSampleReader.estimate(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: durationSeconds
        )
        let analysisCount = prepared.analysisSampleCount
        let analysisRate = prepared.analysisSampleRate
        let tempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((analysisRate * 0.046).rounded()))
        )
        let tempoHopSize = min(
            configuration.analysisHopSize,
            max(32, Int((analysisRate * 0.010).rounded()))
        )
        let tempoFrameCount = analysisCount >= tempoFrameSize
            ? 1 + (analysisCount - tempoFrameSize) / max(1, tempoHopSize)
            : 0
        let onsetBytes = Int64(tempoFrameCount) * Int64(MemoryLayout<Double>.stride)

        let availableKeyWindows = analysisCount >= configuration.analysisWindowSize
            ? max(1, (analysisCount - configuration.analysisWindowSize) / max(1, configuration.analysisHopSize) + 1)
            : 0
        let selectedKeyWindows = min(configuration.maximumKeyWindows, availableKeyWindows)
        let keyBytes = Int64(selectedKeyWindows)
            * Int64(configuration.analysisWindowSize)
            * Int64(MemoryLayout<Double>.stride)

        let chordWindow = max(
            256,
            min(analysisCount, Int((configuration.chordWindowSeconds * analysisRate).rounded()))
        )
        let chordHop = max(1, Int((configuration.chordHopSeconds * analysisRate).rounded()))
        let chordFrameCount = analysisCount == 0 ? 0 : Int(ceil(Double(analysisCount) / Double(chordHop)))
        let chordBytes = Int64(chordFrameCount) * 64
        let ringBytes = Int64(max(1, tempoFrameSize) + max(1, chordWindow)) * Int64(MemoryLayout<Float>.stride)
        let sectionScratch = Int64(SongSectionComplexityBudget.maximumBoundaryCandidates + 1) * 128

        let majorAdditional = prepared.maximumCachedPreparedPCMBytes
            + onsetBytes
            + onsetBytes
            + keyBytes
            + chordBytes
            + prepared.sectionEnergyFeaturePCMBytesEstimate
            + ringBytes
            + sectionScratch
        let ratio = majorAdditional > 0
            ? Double(prepared.logicalPreparedPCMBytes) / Double(majorAdditional)
            : 0

        return .init(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: prepared.durationSeconds,
            analysisSampleRate: analysisRate,
            sourcePCMBytes: prepared.sourcePCMBytes,
            avoidedWholeTrackPreparedPCMBytes: prepared.logicalPreparedPCMBytes,
            readerCacheUpperBoundBytes: prepared.maximumCachedPreparedPCMBytes,
            tempoOnsetBufferBytes: onsetBytes,
            tempoMedianScratchUpperBoundBytes: onsetBytes,
            keyWindowRetentionUpperBoundBytes: keyBytes,
            chordDecisionRetentionUpperBoundBytes: chordBytes,
            sectionEnergyFeatureBytes: prepared.sectionEnergyFeaturePCMBytesEstimate,
            tempoAndChordRingBytes: ringBytes,
            sectionStructuralScratchUpperBoundBytes: sectionScratch,
            estimatedMajorAdditionalWorkingSetBytes: majorAdditional,
            preparedToMajorAdditionalReductionRatio: ratio,
            logicalPreparedSamplesPerSinglePass: analysisCount
        )
    }
}
