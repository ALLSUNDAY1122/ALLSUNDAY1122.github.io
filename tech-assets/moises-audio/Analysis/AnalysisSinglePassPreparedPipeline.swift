import Foundation

public struct AnalysisSinglePassPreparedAnalysis: Equatable, Sendable {
    public let tempo: TempoAnalysis?
    public let key: MusicalKey?
    public let chords: [ChordEvent]
    public let sectionEnergySignal: AnalysisSignal
    public let featureDiagnostics: AnalysisSinglePassPreparedFeatureDiagnostics
}

public enum AnalysisSinglePassPreparedPipeline {
    public static func analyze(
        reader: AnalysisPreparedSampleReader,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> AnalysisSinglePassPreparedAnalysis {
        try AnalysisCancellationPolicy.check()
        let features = try AnalysisSinglePassPreparedFeatureExtractor.extract(
            reader: reader,
            configuration: configuration
        )
        guard features.durationSeconds >= configuration.minimumDurationSeconds else {
            return .init(
                tempo: nil,
                key: nil,
                chords: [],
                sectionEnergySignal: features.sectionEnergySignal,
                featureDiagnostics: features.diagnostics
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
        try AnalysisCancellationPolicy.check()
        return .init(
            tempo: tempo,
            key: key,
            chords: chords,
            sectionEnergySignal: features.sectionEnergySignal,
            featureDiagnostics: features.diagnostics
        )
    }
}
