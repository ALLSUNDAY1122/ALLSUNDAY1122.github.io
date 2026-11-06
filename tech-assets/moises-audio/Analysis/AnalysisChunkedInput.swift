import Foundation

public enum AnalysisChunkedInputError: Error, Equatable, Sendable {
    case invalidDescriptor
    case emptyChunk(startSampleIndex: Int64)
    case nonContiguousChunk(expected: Int64, actual: Int64)
    case chunkExceedsDeclaredSampleCount(declared: Int64, actualEnd: Int64)
    case sourceSampleCountMismatch(expected: Int64, actual: Int64)
    case preparedSampleCountMismatch(expected: Int, actual: Int)
    case nonSequentialPreparedSample(expected: Int, actual: Int)
}

public struct AnalysisPCMChunk: Equatable, Sendable {
    public let startSampleIndex: Int64
    public let monoSamples: [Float]

    public init(startSampleIndex: Int64, monoSamples: [Float]) {
        self.startSampleIndex = startSampleIndex
        self.monoSamples = monoSamples
    }
}

public struct AnalysisChunkedSignalDescriptor: Equatable, Sendable {
    public let sampleRate: Double
    public let sampleCount: Int64

    public init(sampleRate: Double, sampleCount: Int64) {
        self.sampleRate = sampleRate
        self.sampleCount = sampleCount
    }

    public var durationSeconds: Double {
        guard sampleRate.isFinite, sampleRate > 0, sampleCount >= 0 else { return 0 }
        return Double(sampleCount) / sampleRate
    }
}

/// Declared source-side memory contract. This is not device attestation and
/// does not prove that a concrete decoder has no hidden buffers. W23/W24
/// process RSS/physical-footprint telemetry remains authoritative.
public enum AnalysisChunkedSourceMemoryContract: String, Codable, Equatable, Sendable {
    /// Legacy/default construction did not declare how source PCM is retained.
    case unspecified = "UNSPECIFIED"
    /// Consumer-driven pull contract intended to keep only bounded decoder
    /// chunks resident at the Worker-4 seam.
    case boundedPull = "BOUNDED_PULL_CONTRACT"
    /// Compatibility adapter that first materializes the entire source signal.
    /// It is API-compatible but is never valid MOI-P021 bounded-input evidence.
    case wholeSignalCompatibilityMaterialized = "WHOLE_SIGNAL_COMPATIBILITY_MATERIALIZED"
}

/// Pull-based source contract. The Analysis consumer requests the next chunk
/// only after it has finished consuming the previous one, preventing an
/// unbounded producer queue from silently recreating whole-track retention.
/// A concrete decoder can still retain data internally, so W23/W24 physical
/// memory telemetry remains authoritative at Late Integration.
public protocol AnalysisPCMChunkPulling: Sendable {
    func nextChunk() async throws -> AnalysisPCMChunk?
}

public struct AnalysisChunkedSignal: Sendable {
    public let descriptor: AnalysisChunkedSignalDescriptor
    public let source: any AnalysisPCMChunkPulling
    public let sourceMemoryContract: AnalysisChunkedSourceMemoryContract

    public init(
        descriptor: AnalysisChunkedSignalDescriptor,
        source: any AnalysisPCMChunkPulling,
        sourceMemoryContract: AnalysisChunkedSourceMemoryContract = .unspecified
    ) {
        self.descriptor = descriptor
        self.source = source
        self.sourceMemoryContract = sourceMemoryContract
    }
}

/// Optional Lane-4-owned seam for a decoder capable of yielding sequential
/// mono Float PCM without allocating a whole-track `[Float]` first.
///
/// HQ/Lane 2 may make the concrete decoder conform in Late Integration. The
/// existing `AnalysisSignalLoading` contract remains supported as a fallback.
public protocol AnalysisChunkedSignalLoading: Sendable {
    func openChunkedSignal(
        projectID: ProjectID,
        asset: LocalAudioAsset
    ) async throws -> AnalysisChunkedSignal
}

private actor AnalysisWholeSignalChunkPuller: AnalysisPCMChunkPulling {
    private let samples: [Float]
    private let chunkSampleCount: Int
    private var nextStart = 0

    init(samples: [Float], chunkSampleCount: Int) {
        self.samples = samples
        self.chunkSampleCount = chunkSampleCount
    }

    func nextChunk() async throws -> AnalysisPCMChunk? {
        try AnalysisCancellationPolicy.check()
        guard nextStart < samples.count else { return nil }
        let start = nextStart
        let end = min(samples.count, start + chunkSampleCount)
        nextStart = end
        return AnalysisPCMChunk(
            startSampleIndex: Int64(start),
            monoSamples: Array(samples[start..<end])
        )
    }
}

/// Compatibility bridge for tests/integration migration. This adapter still
/// materializes the source via `AnalysisSignalLoading`; therefore it proves API
/// compatibility only and must not be used as evidence that whole-source PCM
/// allocation has been eliminated.
public struct AnalysisWholeSignalChunkedCompatibilityAdapter: AnalysisChunkedSignalLoading {
    private let loader: any AnalysisSignalLoading
    private let chunkSampleCount: Int

    public init(
        loader: any AnalysisSignalLoading,
        chunkSampleCount: Int = 32_768
    ) {
        precondition(chunkSampleCount > 0)
        self.loader = loader
        self.chunkSampleCount = chunkSampleCount
    }

    public func openChunkedSignal(
        projectID: ProjectID,
        asset: LocalAudioAsset
    ) async throws -> AnalysisChunkedSignal {
        let signal = try await loader.loadSignal(projectID: projectID, asset: asset)
        return AnalysisChunkedSignal(
            descriptor: .init(
                sampleRate: signal.sampleRate,
                sampleCount: Int64(signal.monoSamples.count)
            ),
            source: AnalysisWholeSignalChunkPuller(
                samples: signal.monoSamples,
                chunkSampleCount: chunkSampleCount
            ),
            sourceMemoryContract: .wholeSignalCompatibilityMaterialized
        )
    }
}
