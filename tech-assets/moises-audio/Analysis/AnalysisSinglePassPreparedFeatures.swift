import Foundation

public struct AnalysisPreparedChordFrameDecision: Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let label: String
    public let confidence: Double?

    public init(startSeconds: Double, endSeconds: Double, label: String, confidence: Double?) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.label = label
        self.confidence = confidence
    }
}

public struct AnalysisSinglePassPreparedFeatureDiagnostics: Codable, Equatable, Sendable {
    public let preparedSampleCount: Int
    public let preparedSampleRequests: Int
    public let preparedSampleComputations: Int
    public let preparedBlockLoads: Int
    public let tempoOnsetCount: Int
    public let keyWindowCount: Int
    public let keyWindowSampleCount: Int
    public let chordFrameDecisionCount: Int
    public let sectionEnergyFrameCount: Int
    public let maximumTempoRingSamples: Int
    public let maximumChordRingSamples: Int
    public let estimatedRetainedFeatureBytes: Int64
    public let exactSinglePreparedTraversal: Bool
    public private(set) var extremeDurationCompressionApplied: Bool = false
    public private(set) var tempoFrameStride: Int = 1
    public private(set) var chordFrameStride: Int = 1
    public private(set) var naturalSectionEnergyFrameCount: Int = 0
    public private(set) var sectionEnergyFrameStrideEquivalent: Int = 1
}

public struct AnalysisSinglePassPreparedFeatures: Equatable, Sendable {
    public let tempoOnset: [Double]
    public let tempoFrameSize: Int
    public let tempoHopSize: Int
    public let keyWindows: [[Double]]
    public let keyGlobalRMS: Double
    public let chordFrameDecisions: [AnalysisPreparedChordFrameDecision]
    public let sectionEnergySignal: AnalysisSignal
    public let sampleRate: Double
    public let durationSeconds: Double
    public let diagnostics: AnalysisSinglePassPreparedFeatureDiagnostics
}

public enum AnalysisSinglePassPreparedFeatureExtractor {
    public static func extract(
        reader: AnalysisPreparedSampleReader,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> AnalysisSinglePassPreparedFeatures {
        try AnalysisCancellationPolicy.check()
        guard reader.sampleCount > 0, reader.durationSeconds > 0 else {
            let emptySignal = AnalysisSignal(sampleRate: 1, monoSamples: [])
            return .init(
                tempoOnset: [], tempoFrameSize: 0, tempoHopSize: 0,
                keyWindows: [], keyGlobalRMS: 0, chordFrameDecisions: [],
                sectionEnergySignal: emptySignal, sampleRate: reader.sampleRate,
                durationSeconds: reader.durationSeconds,
                diagnostics: .init(
                    preparedSampleCount: reader.sampleCount,
                    preparedSampleRequests: 0,
                    preparedSampleComputations: 0,
                    preparedBlockLoads: 0,
                    tempoOnsetCount: 0,
                    keyWindowCount: 0,
                    keyWindowSampleCount: 0,
                    chordFrameDecisionCount: 0,
                    sectionEnergyFrameCount: 0,
                    maximumTempoRingSamples: 0,
                    maximumChordRingSamples: 0,
                    estimatedRetainedFeatureBytes: 0,
                    exactSinglePreparedTraversal: true
                )
            )
        }

        let computationStart = reader.preparedSampleComputationCount
        let blockLoadStart = reader.preparedBlockLoadCount
        let accumulator = AnalysisSequentialPreparedFeatureAccumulator(
            sampleRate: reader.sampleRate,
            sampleCount: reader.sampleCount,
            durationSeconds: reader.durationSeconds,
            configuration: configuration
        )
        for sampleIndex in 0..<reader.sampleCount {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: sampleIndex,
                stride: AnalysisCancellationPolicy.preparationCheckStride
            )
            try accumulator.consume(try reader.sample(at: sampleIndex), at: sampleIndex)
        }
        return try accumulator.finish(
            preparedSampleComputations: reader.preparedSampleComputationCount - computationStart,
            preparedBlockLoads: reader.preparedBlockLoadCount - blockLoadStart
        )
    }
}
