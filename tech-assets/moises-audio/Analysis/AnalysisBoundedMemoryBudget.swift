import Foundation

public struct AnalysisBoundedMemoryPipelineBudget: Codable, Equatable, Sendable {
    public let sourceSampleRate: Double
    public let durationSeconds: Double
    public let analysisSampleRate: Double
    public let sourcePCMBytes: Int64
    public let avoidedWholeTrackPreparedPCMBytes: Int64
    public let readerCacheUpperBoundBytes: Int64
    public let tempoOnsetBufferBytes: Int64
    public let tempoMedianScratchUpperBoundBytes: Int64
    public let keyWindowScratchUpperBoundBytes: Int64
    public let chordDecisionScratchUpperBoundBytes: Int64
    public let sectionEnergyFeatureBytes: Int64
    public let sectionStructuralScratchUpperBoundBytes: Int64
    public let estimatedMajorAdditionalWorkingSetBytes: Int64
    public let preparedToMajorAdditionalReductionRatio: Double
}

public enum AnalysisBoundedMemoryBudget {
    /// Conservative analytical budget for the Worker-4-owned Analysis buffers.
    /// This deliberately excludes the source PCM owned by AnalysisSignalLoading.
    /// Per-item Swift allocator overhead is not modeled; physical-iPhone W23/W24
    /// telemetry remains authoritative for actual process memory.
    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisBoundedMemoryPipelineBudget {
        let prepared = AnalysisPreparedSampleReader.estimate(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: durationSeconds
        )
        let analysisCount = prepared.analysisSampleCount
        let analysisRate = prepared.analysisSampleRate
        let frameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((analysisRate * 0.046).rounded()))
        )
        let hopSize = min(
            configuration.analysisHopSize,
            max(32, Int((analysisRate * 0.010).rounded()))
        )
        let tempoFrameCount = analysisCount >= frameSize
            ? 1 + (analysisCount - frameSize) / max(1, hopSize)
            : 0
        let onsetBytes = Int64(tempoFrameCount) * Int64(MemoryLayout<Double>.stride)
        let keyScratch = Int64(configuration.analysisWindowSize) * Int64(MemoryLayout<Double>.stride)
        let chordHop = max(1, Int((configuration.chordHopSeconds * analysisRate).rounded()))
        let chordFrameCount = analysisCount == 0 ? 0 : Int(ceil(Double(analysisCount) / Double(chordHop)))
        // FrameDecision currently contains 3 Doubles/String/Optional<Double>. Use a
        // deliberately padded 64-byte analytical allowance rather than relying
        // on an ABI-specific MemoryLayout for a private implementation type.
        let chordScratch = Int64(chordFrameCount) * 64
        // W13 caps section boundary candidates at 16,384. Allow 128 bytes each
        // for boundary/work/prototype scratch so the estimate remains conservative.
        let sectionScratch = Int64(SongSectionComplexityBudget.maximumBoundaryCandidates + 1) * 128
        let majorAdditional = prepared.maximumCachedPreparedPCMBytes
            + onsetBytes
            + onsetBytes
            + keyScratch
            + chordScratch
            + prepared.sectionEnergyFeaturePCMBytesEstimate
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
            keyWindowScratchUpperBoundBytes: keyScratch,
            chordDecisionScratchUpperBoundBytes: chordScratch,
            sectionEnergyFeatureBytes: prepared.sectionEnergyFeaturePCMBytesEstimate,
            sectionStructuralScratchUpperBoundBytes: sectionScratch,
            estimatedMajorAdditionalWorkingSetBytes: majorAdditional,
            preparedToMajorAdditionalReductionRatio: ratio
        )
    }
}
