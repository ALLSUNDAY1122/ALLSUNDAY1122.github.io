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
    /// source. W31 retained-feature caps are included. Decoder-internal buffers,
    /// Swift allocator overhead and VM behavior remain W23/W24 device evidence.
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
        let w31 = AnalysisExtremeDurationRetentionBudgetEstimator.estimate(
            sourceSampleRate: sourceSampleRate,
            durationSeconds: durationSeconds,
            configuration: configuration
        )
        // The W31 whole-signal analytical estimate includes the W28/W29
        // prepared-reader cache. The W30 pull path replaces that allowance by
        // exactly one bounded upstream source chunk.
        let featureBytes = max(
            0,
            w31.estimatedMajorWorker4WorkingSetBytes - w31.readerCacheUpperBoundBytes
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
