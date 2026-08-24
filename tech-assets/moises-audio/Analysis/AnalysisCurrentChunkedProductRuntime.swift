import Foundation

/// Current W30-W34 chunked product runtime. Product analysis and W36 physical
/// workload capture both call these exact stage operations so the measurement
/// runner cannot silently drift back to the historical W25 materialized path.
public struct AnalysisCurrentChunkedProductRuntimeResult: Equatable, Sendable {
    public let snapshot: AnalysisSnapshot
    public let inputDiagnostics: AnalysisChunkedInputDiagnostics
    public let featureDiagnostics: AnalysisSinglePassPreparedFeatureDiagnostics

    public init(
        snapshot: AnalysisSnapshot,
        inputDiagnostics: AnalysisChunkedInputDiagnostics,
        featureDiagnostics: AnalysisSinglePassPreparedFeatureDiagnostics
    ) {
        self.snapshot = snapshot
        self.inputDiagnostics = inputDiagnostics
        self.featureDiagnostics = featureDiagnostics
    }
}

public enum AnalysisCurrentChunkedProductRuntime {
    public typealias Extracted = (
        features: AnalysisSinglePassPreparedFeatures,
        inputDiagnostics: AnalysisChunkedInputDiagnostics
    )

    public static func extract(
        signal: AnalysisChunkedSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) async throws -> Extracted {
        let extracted = try await AnalysisChunkedPreparedFeatureExtractor.extract(
            signal: signal,
            configuration: configuration
        )
        return (
            features: extracted.features,
            inputDiagnostics: extracted.diagnostics
        )
    }

    public static func finalizeTempo(
        features: AnalysisSinglePassPreparedFeatures,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> TempoAnalysis? {
        try AnalysisCancellationPolicy.check()
        guard features.durationSeconds >= configuration.minimumDurationSeconds else { return nil }
        return try StreamingBoundedTempoBeatAnalyzer.analyzePreparedOnsetCancellable(
            onset: features.tempoOnset,
            sampleRate: features.sampleRate,
            durationSeconds: features.durationSeconds,
            frameSize: features.tempoFrameSize,
            hopSize: features.tempoHopSize,
            configuration: configuration
        )
    }

    public static func observeBeatCount(_ tempo: TempoAnalysis?) throws -> Int {
        try AnalysisCancellationPolicy.check()
        return tempo?.beatTimesSeconds.count ?? 0
    }

    public static func finalizeKey(
        features: AnalysisSinglePassPreparedFeatures,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> MusicalKey? {
        try AnalysisCancellationPolicy.check()
        guard features.durationSeconds >= configuration.minimumDurationSeconds else { return nil }
        return try StreamingBoundedMusicalKeyAnalyzer.analyzePreparedWindowsCancellable(
            windows: features.keyWindows,
            sampleRate: features.sampleRate,
            globalRMS: features.keyGlobalRMS,
            configuration: configuration
        )
    }

    public static func finalizeChords(
        features: AnalysisSinglePassPreparedFeatures,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [ChordEvent] {
        try AnalysisCancellationPolicy.check()
        guard features.durationSeconds >= configuration.minimumDurationSeconds else { return [] }
        return try StreamingBoundedChordTimelineAnalyzer.finalizePreclassifiedFramesCancellable(
            features.chordFrameDecisions,
            duration: features.durationSeconds,
            configuration: configuration
        )
    }

    public static func finalizeSections(
        features: AnalysisSinglePassPreparedFeatures,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [SongSection] {
        try AnalysisCancellationPolicy.check()
        guard features.durationSeconds >= configuration.minimumDurationSeconds else { return [] }
        let signal = features.sectionEnergySignal
        let detected = try CancellableSongSectionPipeline.analyze(
            signal: signal,
            chords: chords,
            configuration: configuration
        )
        try AnalysisCancellationPolicy.check()
        return try SongSectionBoundaryHardener.harden(
            sections: detected,
            signal: signal,
            chords: chords,
            configuration: configuration
        )
    }

    public static func publishSnapshot(
        features: AnalysisSinglePassPreparedFeatures,
        tempo: TempoAnalysis?,
        key: MusicalKey?,
        chords: [ChordEvent],
        sections: [SongSection],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> AnalysisSnapshot {
        try AnalysisCancellationPolicy.check()
        guard features.durationSeconds >= configuration.minimumDurationSeconds else {
            return AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        }
        let raw = AnalysisSnapshot(
            tempo: tempo,
            key: key,
            chords: chords,
            sections: sections
        )
        return try AnalysisSnapshotRobustness.hardenCancellable(
            snapshot: raw,
            duration: features.durationSeconds,
            configuration: configuration
        )
    }

    public static func analyze(
        signal: AnalysisChunkedSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) async throws -> AnalysisCurrentChunkedProductRuntimeResult {
        let extracted = try await extract(signal: signal, configuration: configuration)
        let tempo = try finalizeTempo(features: extracted.features, configuration: configuration)
        _ = try observeBeatCount(tempo)
        let key = try finalizeKey(features: extracted.features, configuration: configuration)
        let chords = try finalizeChords(features: extracted.features, configuration: configuration)
        let sections = try finalizeSections(
            features: extracted.features,
            chords: chords,
            configuration: configuration
        )
        let snapshot = try publishSnapshot(
            features: extracted.features,
            tempo: tempo,
            key: key,
            chords: chords,
            sections: sections,
            configuration: configuration
        )
        return .init(
            snapshot: snapshot,
            inputDiagnostics: extracted.inputDiagnostics,
            featureDiagnostics: extracted.features.diagnostics
        )
    }
}
