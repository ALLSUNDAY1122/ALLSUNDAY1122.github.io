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

public struct AnalysisChunkedSignal: Sendable {
    public let descriptor: AnalysisChunkedSignalDescriptor
    public let chunks: AsyncThrowingStream<AnalysisPCMChunk, Error>

    public init(
        descriptor: AnalysisChunkedSignalDescriptor,
        chunks: AsyncThrowingStream<AnalysisPCMChunk, Error>
    ) {
        self.descriptor = descriptor
        self.chunks = chunks
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
        let descriptor = AnalysisChunkedSignalDescriptor(
            sampleRate: signal.sampleRate,
            sampleCount: Int64(signal.monoSamples.count)
        )
        let chunkSize = chunkSampleCount
        let samples = signal.monoSamples
        let stream = AsyncThrowingStream<AnalysisPCMChunk, Error> { continuation in
            var start = 0
            while start < samples.count {
                let end = min(samples.count, start + chunkSize)
                continuation.yield(
                    AnalysisPCMChunk(
                        startSampleIndex: Int64(start),
                        monoSamples: Array(samples[start..<end])
                    )
                )
                start = end
            }
            continuation.finish()
        }
        return AnalysisChunkedSignal(descriptor: descriptor, chunks: stream)
    }
}
