import Foundation

public struct AnalysisChunkedInputDiagnostics: Codable, Equatable, Sendable {
    public let sourceSampleRate: Double
    public let sourceSampleCount: Int64
    public let sourceChunkCount: Int
    public let maximumSourceChunkSamples: Int
    public let maximumSourceChunkPCMBytes: Int64
    public let declaredWholeSourcePCMBytes: Int64
    public let analysisSampleRate: Double
    public let preparedSampleCount: Int
    public let preparedSampleComputations: Int
    public let maximumResamplerCarrySamples: Int
    public let sanitizedSourceSampleCount: Int64
    public let wholeSourcePCMMaterializedByChunkedPath: Bool
    public let contiguousCompleteSource: Bool
}

public struct AnalysisChunkedSinglePassPreparedAnalysis: Equatable, Sendable {
    public let analysis: AnalysisSinglePassPreparedAnalysis
    public let inputDiagnostics: AnalysisChunkedInputDiagnostics
}

public enum AnalysisChunkedPreparedFeatureExtractor {
    public static func extract(
        signal: AnalysisChunkedSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) async throws -> (features: AnalysisSinglePassPreparedFeatures, diagnostics: AnalysisChunkedInputDiagnostics) {
        try AnalysisCancellationPolicy.check()
        let descriptor = signal.descriptor
        guard descriptor.sampleRate.isFinite,
              descriptor.sampleRate > 0,
              descriptor.sampleCount >= 0,
              descriptor.sampleCount <= Int64(Int.max) else {
            throw AnalysisChunkedInputError.invalidDescriptor
        }

        let sourceSampleCount = Int(descriptor.sampleCount)
        let sourceDuration = descriptor.durationSeconds
        let analysisSampleRate = min(
            descriptor.sampleRate,
            AnalysisWorkingSetPolicy.maximumAnalysisSampleRate
        )
        let needsResampling = descriptor.sampleRate > analysisSampleRate * 1.05
        let preparedSampleCount: Int
        if sourceSampleCount == 0 {
            preparedSampleCount = 0
        } else if needsResampling {
            preparedSampleCount = max(
                1,
                Int((sourceDuration * analysisSampleRate).rounded())
            )
        } else {
            preparedSampleCount = sourceSampleCount
        }
        let preparedDuration = analysisSampleRate > 0
            ? Double(preparedSampleCount) / analysisSampleRate
            : 0

        let accumulator = AnalysisSequentialPreparedFeatureAccumulator(
            sampleRate: analysisSampleRate,
            sampleCount: preparedSampleCount,
            durationSeconds: preparedDuration,
            configuration: configuration
        )

        var expectedSourceStart: Int64 = 0
        var sourceChunkCount = 0
        var maximumSourceChunkSamples = 0
        var sanitizedSourceSampleCount: Int64 = 0
        var preparedComputations = 0
        var maximumResamplerCarrySamples = 0

        let ratio = descriptor.sampleRate / analysisSampleRate
        var preparedIndex = 0
        var rangeStart = 0
        var rangeEnd = 0
        var rangeSum = 0.0
        var rangeCount = 0

        func bounds(for outputIndex: Int) -> (start: Int, end: Int) {
            let rawStart = Int((Double(outputIndex) * ratio).rounded(.down))
            let rawEnd = Int((Double(outputIndex + 1) * ratio).rounded(.down))
            let start = min(sourceSampleCount, max(0, rawStart))
            let end = min(sourceSampleCount, max(start + 1, rawEnd))
            return (start, end)
        }

        if needsResampling, preparedSampleCount > 0 {
            let initial = bounds(for: 0)
            rangeStart = initial.start
            rangeEnd = initial.end
        }

        for try await chunk in signal.chunks {
            try AnalysisCancellationPolicy.check()
            guard !chunk.monoSamples.isEmpty else {
                throw AnalysisChunkedInputError.emptyChunk(startSampleIndex: chunk.startSampleIndex)
            }
            guard chunk.startSampleIndex == expectedSourceStart else {
                throw AnalysisChunkedInputError.nonContiguousChunk(
                    expected: expectedSourceStart,
                    actual: chunk.startSampleIndex
                )
            }
            let chunkEnd = chunk.startSampleIndex + Int64(chunk.monoSamples.count)
            guard chunkEnd <= descriptor.sampleCount else {
                throw AnalysisChunkedInputError.chunkExceedsDeclaredSampleCount(
                    declared: descriptor.sampleCount,
                    actualEnd: chunkEnd
                )
            }

            sourceChunkCount += 1
            maximumSourceChunkSamples = max(maximumSourceChunkSamples, chunk.monoSamples.count)

            for (localIndex, raw) in chunk.monoSamples.enumerated() {
                let absoluteSourceIndex = Int(chunk.startSampleIndex) + localIndex
                try AnalysisCancellationPolicy.checkIfNeeded(
                    enabled: true,
                    iteration: absoluteSourceIndex,
                    stride: AnalysisCancellationPolicy.preparationCheckStride
                )
                let value = AnalysisWorkingSetPolicy.boundedFinite(raw)
                if !raw.isFinite || abs(raw) > AnalysisWorkingSetPolicy.maximumAbsoluteSample {
                    sanitizedSourceSampleCount += 1
                }

                if needsResampling {
                    guard preparedIndex < preparedSampleCount else { continue }
                    if absoluteSourceIndex >= rangeStart, absoluteSourceIndex < rangeEnd {
                        rangeSum += Double(value)
                        rangeCount += 1
                        maximumResamplerCarrySamples = max(maximumResamplerCarrySamples, rangeCount)
                    }
                    if absoluteSourceIndex + 1 == rangeEnd {
                        let prepared = rangeCount > 0 ? Float(rangeSum / Double(rangeCount)) : 0
                        try accumulator.consume(prepared, at: preparedIndex)
                        preparedComputations += 1
                        preparedIndex += 1
                        rangeSum = 0
                        rangeCount = 0
                        if preparedIndex < preparedSampleCount {
                            let next = bounds(for: preparedIndex)
                            rangeStart = next.start
                            rangeEnd = next.end
                        }
                    }
                } else {
                    try accumulator.consume(value, at: preparedIndex)
                    preparedComputations += 1
                    preparedIndex += 1
                }
            }
            expectedSourceStart = chunkEnd
        }

        guard expectedSourceStart == descriptor.sampleCount else {
            throw AnalysisChunkedInputError.sourceSampleCountMismatch(
                expected: descriptor.sampleCount,
                actual: expectedSourceStart
            )
        }

        if needsResampling {
            if rangeCount > 0, preparedIndex < preparedSampleCount {
                try accumulator.consume(Float(rangeSum / Double(rangeCount)), at: preparedIndex)
                preparedComputations += 1
                preparedIndex += 1
            }
            // W11 leaves a zero in any theoretical output whose computed source
            // range starts after the declared source. Preserve that fail-safe
            // behavior rather than reading beyond the stream.
            while preparedIndex < preparedSampleCount {
                try accumulator.consume(0, at: preparedIndex)
                preparedComputations += 1
                preparedIndex += 1
            }
        }

        guard preparedIndex == preparedSampleCount else {
            throw AnalysisChunkedInputError.preparedSampleCountMismatch(
                expected: preparedSampleCount,
                actual: preparedIndex
            )
        }

        let features = try accumulator.finish(
            preparedSampleComputations: preparedComputations,
            preparedBlockLoads: 0
        )
        let maximumChunkBytes = Int64(maximumSourceChunkSamples) * Int64(MemoryLayout<Float>.stride)
        let diagnostics = AnalysisChunkedInputDiagnostics(
            sourceSampleRate: descriptor.sampleRate,
            sourceSampleCount: descriptor.sampleCount,
            sourceChunkCount: sourceChunkCount,
            maximumSourceChunkSamples: maximumSourceChunkSamples,
            maximumSourceChunkPCMBytes: maximumChunkBytes,
            declaredWholeSourcePCMBytes: descriptor.sampleCount * Int64(MemoryLayout<Float>.stride),
            analysisSampleRate: analysisSampleRate,
            preparedSampleCount: preparedSampleCount,
            preparedSampleComputations: preparedComputations,
            maximumResamplerCarrySamples: maximumResamplerCarrySamples,
            sanitizedSourceSampleCount: sanitizedSourceSampleCount,
            wholeSourcePCMMaterializedByChunkedPath: false,
            contiguousCompleteSource: expectedSourceStart == descriptor.sampleCount
        )
        return (features, diagnostics)
    }
}

public enum AnalysisChunkedSinglePassPreparedPipeline {
    public static func analyze(
        signal: AnalysisChunkedSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) async throws -> AnalysisChunkedSinglePassPreparedAnalysis {
        let extracted = try await AnalysisChunkedPreparedFeatureExtractor.extract(
            signal: signal,
            configuration: configuration
        )
        let features = extracted.features
        if features.durationSeconds < configuration.minimumDurationSeconds {
            return .init(
                analysis: .init(
                    tempo: nil,
                    key: nil,
                    chords: [],
                    sectionEnergySignal: features.sectionEnergySignal,
                    featureDiagnostics: features.diagnostics
                ),
                inputDiagnostics: extracted.diagnostics
            )
        }
        let tempo = try StreamingBoundedTempoBeatAnalyzer.analyzePreparedOnsetCancellable(
            onset: features.tempoOnset,
            sampleRate: features.sampleRate,
            durationSeconds: features.durationSeconds,
            frameSize: features.tempoFrameSize,
            hopSize: features.tempoHopSize,
            configuration: configuration
        )
        try AnalysisCancellationPolicy.check()
        let key = try StreamingBoundedMusicalKeyAnalyzer.analyzePreparedWindowsCancellable(
            windows: features.keyWindows,
            sampleRate: features.sampleRate,
            globalRMS: features.keyGlobalRMS,
            configuration: configuration
        )
        try AnalysisCancellationPolicy.check()
        let chords = try StreamingBoundedChordTimelineAnalyzer.finalizePreclassifiedFramesCancellable(
            features.chordFrameDecisions,
            duration: features.durationSeconds,
            configuration: configuration
        )
        return .init(
            analysis: .init(
                tempo: tempo,
                key: key,
                chords: chords,
                sectionEnergySignal: features.sectionEnergySignal,
                featureDiagnostics: features.diagnostics
            ),
            inputDiagnostics: extracted.diagnostics
        )
    }
}
