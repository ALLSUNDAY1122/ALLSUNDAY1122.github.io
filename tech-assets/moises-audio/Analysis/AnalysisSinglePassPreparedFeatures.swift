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
    public let extremeDurationCompressionApplied: Bool
    public let tempoFrameStride: Int
    public let chordFrameStride: Int
    public let naturalSectionEnergyFrameCount: Int
    public let sectionEnergyFrameStrideEquivalent: Int
    public let tempoResolutionSafe: Bool
    public let chordWindowRetentionSafe: Bool
    public let sectionResolutionSafe: Bool

    public init(
        preparedSampleCount: Int,
        preparedSampleRequests: Int,
        preparedSampleComputations: Int,
        preparedBlockLoads: Int,
        tempoOnsetCount: Int,
        keyWindowCount: Int,
        keyWindowSampleCount: Int,
        chordFrameDecisionCount: Int,
        sectionEnergyFrameCount: Int,
        maximumTempoRingSamples: Int,
        maximumChordRingSamples: Int,
        estimatedRetainedFeatureBytes: Int64,
        exactSinglePreparedTraversal: Bool,
        extremeDurationCompressionApplied: Bool = false,
        tempoFrameStride: Int = 1,
        chordFrameStride: Int = 1,
        naturalSectionEnergyFrameCount: Int = 0,
        sectionEnergyFrameStrideEquivalent: Int = 1,
        tempoResolutionSafe: Bool = true,
        chordWindowRetentionSafe: Bool = true,
        sectionResolutionSafe: Bool = true
    ) {
        self.preparedSampleCount = preparedSampleCount
        self.preparedSampleRequests = preparedSampleRequests
        self.preparedSampleComputations = preparedSampleComputations
        self.preparedBlockLoads = preparedBlockLoads
        self.tempoOnsetCount = tempoOnsetCount
        self.keyWindowCount = keyWindowCount
        self.keyWindowSampleCount = keyWindowSampleCount
        self.chordFrameDecisionCount = chordFrameDecisionCount
        self.sectionEnergyFrameCount = sectionEnergyFrameCount
        self.maximumTempoRingSamples = maximumTempoRingSamples
        self.maximumChordRingSamples = maximumChordRingSamples
        self.estimatedRetainedFeatureBytes = estimatedRetainedFeatureBytes
        self.exactSinglePreparedTraversal = exactSinglePreparedTraversal
        self.extremeDurationCompressionApplied = extremeDurationCompressionApplied
        self.tempoFrameStride = max(1, tempoFrameStride)
        self.chordFrameStride = max(1, chordFrameStride)
        self.naturalSectionEnergyFrameCount = max(0, naturalSectionEnergyFrameCount)
        self.sectionEnergyFrameStrideEquivalent = max(1, sectionEnergyFrameStrideEquivalent)
        self.tempoResolutionSafe = tempoResolutionSafe
        self.chordWindowRetentionSafe = chordWindowRetentionSafe
        self.sectionResolutionSafe = sectionResolutionSafe
    }

    private enum CodingKeys: String, CodingKey {
        case preparedSampleCount
        case preparedSampleRequests
        case preparedSampleComputations
        case preparedBlockLoads
        case tempoOnsetCount
        case keyWindowCount
        case keyWindowSampleCount
        case chordFrameDecisionCount
        case sectionEnergyFrameCount
        case maximumTempoRingSamples
        case maximumChordRingSamples
        case estimatedRetainedFeatureBytes
        case exactSinglePreparedTraversal
        case extremeDurationCompressionApplied
        case tempoFrameStride
        case chordFrameStride
        case naturalSectionEnergyFrameCount
        case sectionEnergyFrameStrideEquivalent
        case tempoResolutionSafe
        case chordWindowRetentionSafe
        case sectionResolutionSafe
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            preparedSampleCount: try values.decode(Int.self, forKey: .preparedSampleCount),
            preparedSampleRequests: try values.decode(Int.self, forKey: .preparedSampleRequests),
            preparedSampleComputations: try values.decode(Int.self, forKey: .preparedSampleComputations),
            preparedBlockLoads: try values.decode(Int.self, forKey: .preparedBlockLoads),
            tempoOnsetCount: try values.decode(Int.self, forKey: .tempoOnsetCount),
            keyWindowCount: try values.decode(Int.self, forKey: .keyWindowCount),
            keyWindowSampleCount: try values.decode(Int.self, forKey: .keyWindowSampleCount),
            chordFrameDecisionCount: try values.decode(Int.self, forKey: .chordFrameDecisionCount),
            sectionEnergyFrameCount: try values.decode(Int.self, forKey: .sectionEnergyFrameCount),
            maximumTempoRingSamples: try values.decode(Int.self, forKey: .maximumTempoRingSamples),
            maximumChordRingSamples: try values.decode(Int.self, forKey: .maximumChordRingSamples),
            estimatedRetainedFeatureBytes: try values.decode(Int64.self, forKey: .estimatedRetainedFeatureBytes),
            exactSinglePreparedTraversal: try values.decode(Bool.self, forKey: .exactSinglePreparedTraversal),
            extremeDurationCompressionApplied: try values.decodeIfPresent(Bool.self, forKey: .extremeDurationCompressionApplied) ?? false,
            tempoFrameStride: try values.decodeIfPresent(Int.self, forKey: .tempoFrameStride) ?? 1,
            chordFrameStride: try values.decodeIfPresent(Int.self, forKey: .chordFrameStride) ?? 1,
            naturalSectionEnergyFrameCount: try values.decodeIfPresent(Int.self, forKey: .naturalSectionEnergyFrameCount) ?? 0,
            sectionEnergyFrameStrideEquivalent: try values.decodeIfPresent(Int.self, forKey: .sectionEnergyFrameStrideEquivalent) ?? 1,
            tempoResolutionSafe: try values.decodeIfPresent(Bool.self, forKey: .tempoResolutionSafe) ?? true,
            chordWindowRetentionSafe: try values.decodeIfPresent(Bool.self, forKey: .chordWindowRetentionSafe) ?? true,
            sectionResolutionSafe: try values.decodeIfPresent(Bool.self, forKey: .sectionResolutionSafe) ?? true
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(preparedSampleCount, forKey: .preparedSampleCount)
        try values.encode(preparedSampleRequests, forKey: .preparedSampleRequests)
        try values.encode(preparedSampleComputations, forKey: .preparedSampleComputations)
        try values.encode(preparedBlockLoads, forKey: .preparedBlockLoads)
        try values.encode(tempoOnsetCount, forKey: .tempoOnsetCount)
        try values.encode(keyWindowCount, forKey: .keyWindowCount)
        try values.encode(keyWindowSampleCount, forKey: .keyWindowSampleCount)
        try values.encode(chordFrameDecisionCount, forKey: .chordFrameDecisionCount)
        try values.encode(sectionEnergyFrameCount, forKey: .sectionEnergyFrameCount)
        try values.encode(maximumTempoRingSamples, forKey: .maximumTempoRingSamples)
        try values.encode(maximumChordRingSamples, forKey: .maximumChordRingSamples)
        try values.encode(estimatedRetainedFeatureBytes, forKey: .estimatedRetainedFeatureBytes)
        try values.encode(exactSinglePreparedTraversal, forKey: .exactSinglePreparedTraversal)
        try values.encode(extremeDurationCompressionApplied, forKey: .extremeDurationCompressionApplied)
        try values.encode(tempoFrameStride, forKey: .tempoFrameStride)
        try values.encode(chordFrameStride, forKey: .chordFrameStride)
        try values.encode(naturalSectionEnergyFrameCount, forKey: .naturalSectionEnergyFrameCount)
        try values.encode(sectionEnergyFrameStrideEquivalent, forKey: .sectionEnergyFrameStrideEquivalent)
        try values.encode(tempoResolutionSafe, forKey: .tempoResolutionSafe)
        try values.encode(chordWindowRetentionSafe, forKey: .chordWindowRetentionSafe)
        try values.encode(sectionResolutionSafe, forKey: .sectionResolutionSafe)
    }
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
