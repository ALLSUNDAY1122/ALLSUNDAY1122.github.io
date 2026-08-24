import Foundation

public struct AnalysisChunkedInputMemoryBudget: Codable, Equatable, Sendable {
    public let sourceSampleRate: Double
    public let durationSeconds: Double
    public let declaredWholeSourcePCMBytes: Int64
    public let maximumChunkSamples: Int
    public let maximumChunkPCMBytes: Int64
    public let avoidedWholeSourcePCMRetentionBytes: Int64
    public let sourceToMaximumChunkReductionRatio: Double
    public let worker4FeatureWorkingSetBytes: Int64
    public let estimatedChunkedAnalysisWorkingSetBytes: Int64
    public let wholeSourcePCMMaterializedByChunkedPath: Bool
}

public enum AnalysisChunkedInputBudget {
    /// Analytical handoff budget. It assumes the upstream decoder honors the
    /// W30 chunk contract and does not separately retain the entire decoded
    /// source. Decoder-internal buffers, Swift allocator overhead and VM
    /// behavior are intentionally excluded and must be measured by W23/W24.
    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        maximumChunkSamples: Int = 32_768,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisChunkedInputMemoryBudget {
        precondition(sourceSampleRate.isFinite && sourceSampleRate > 0)
        precondition(durationSeconds.isFinite && durationSeconds >= 0)
        precondition(maximumChunkSamples > 0)

        let sourceSamples = max(0, Int64((sourceSampleRate * durationSeconds).rounded()))
        let sourceBytes = sourceSamples * Int64(MemoryLayout<Float>.stride)
        let chunkBytes = Int64(maximumChunkSamples) * Int64(MemoryLayout<Float>.stride)
        let w29 = AnalysisSinglePassPreparedBudget.estimate(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: durationSeconds,
            configuration: configuration
        )
        // W30 feeds the sequential accumulator directly and therefore does not
        // need W29's two-block prepared-reader cache. Replace that allowance by
        // the one upstream source chunk retained by the chunked source.
        let featureBytes = max(
            0,
            w29.estimatedMajorAdditionalWorkingSetBytes - w29.readerCacheUpperBoundBytes
        )
        let chunkedBytes = featureBytes + chunkBytes
        return .init(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: durationSeconds,
            declaredWholeSourcePCMBytes: sourceBytes,
            maximumChunkSamples: maximumChunkSamples,
            maximumChunkPCMBytes: chunkBytes,
            avoidedWholeSourcePCMRetentionBytes: sourceBytes,
            sourceToMaximumChunkReductionRatio: chunkBytes > 0
                ? Double(sourceBytes) / Double(chunkBytes)
                : 0,
            worker4FeatureWorkingSetBytes: featureBytes,
            estimatedChunkedAnalysisWorkingSetBytes: chunkedBytes,
            wholeSourcePCMMaterializedByChunkedPath: false
        )
    }
}
