import Foundation

public struct AnalysisSignal: Equatable, Sendable {
    public let sampleRate: Double
    public let monoSamples: [Float]

    public init(sampleRate: Double, monoSamples: [Float]) {
        precondition(sampleRate.isFinite && sampleRate > 0)
        self.sampleRate = sampleRate
        self.monoSamples = monoSamples
    }

    public var durationSeconds: Double {
        Double(monoSamples.count) / sampleRate
    }
}

public protocol AnalysisSignalLoading: Sendable {
    func loadSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSignal
}

public struct MusicAnalysisConfiguration: Equatable, Sendable {
    public var minimumDurationSeconds: Double
    public var minimumTempoConfidence: Double
    public var minimumKeyConfidence: Double
    public var keyRelativeAmbiguityMargin: Double
    public var keyModulationMargin: Double
    public var minimumChordConfidence: Double
    public var minimumChordTemplateScore: Double
    public var noChordRMS: Double
    public var tempoRange: ClosedRange<Double>
    public var analysisWindowSize: Int
    public var analysisHopSize: Int
    public var maximumKeyWindows: Int
    public var chordWindowSeconds: Double
    public var chordHopSeconds: Double
    public var minimumChordSegmentSeconds: Double
    public var chordAnalysisSampleRate: Double
    public var sectionContextSeconds: Double
    public var sectionHopSeconds: Double
    public var minimumSectionSeconds: Double
    public var minimumEdgeSectionSeconds: Double
    public var sectionNoveltyThreshold: Double
    public var sectionEnergyJumpThreshold: Double
    public var sectionClusterSimilarity: Double
    public var minimumFunctionalSectionConfidence: Double
    public var minimumSectionChordCoverage: Double
    public var sectionSilenceRMS: Double

    public init(
        minimumDurationSeconds: Double = 1.5,
        minimumTempoConfidence: Double = 0.18,
        minimumKeyConfidence: Double = 0.015,
        keyRelativeAmbiguityMargin: Double = 0.020,
        keyModulationMargin: Double = 0.014,
        minimumChordConfidence: Double = 0.12,
        minimumChordTemplateScore: Double = 0.58,
        noChordRMS: Double = 0.0015,
        tempoRange: ClosedRange<Double> = 55...210,
        analysisWindowSize: Int = 2048,
        analysisHopSize: Int = 512,
        maximumKeyWindows: Int = 24,
        chordWindowSeconds: Double = 0.70,
        chordHopSeconds: Double = 0.25,
        minimumChordSegmentSeconds: Double = 0.35,
        chordAnalysisSampleRate: Double = 8_000,
        sectionContextSeconds: Double = 2.0,
        sectionHopSeconds: Double = 1.0,
        minimumSectionSeconds: Double = 4.0,
        minimumEdgeSectionSeconds: Double = 4.0,
        sectionNoveltyThreshold: Double = 0.42,
        sectionEnergyJumpThreshold: Double = 0.25,
        sectionClusterSimilarity: Double = 0.82,
        minimumFunctionalSectionConfidence: Double = 0.58,
        minimumSectionChordCoverage: Double = 0.25,
        sectionSilenceRMS: Double = 0.0005
    ) {
        precondition(minimumDurationSeconds >= 0)
        precondition((0...1).contains(minimumTempoConfidence))
        precondition((0...1).contains(minimumKeyConfidence))
        precondition((0...1).contains(keyRelativeAmbiguityMargin))
        precondition((0...1).contains(keyModulationMargin))
        precondition((0...1).contains(minimumChordConfidence))
        precondition((0...1).contains(minimumChordTemplateScore))
        precondition(noChordRMS >= 0 && noChordRMS.isFinite)
        precondition(tempoRange.lowerBound > 0 && tempoRange.upperBound >= tempoRange.lowerBound)
        precondition(analysisWindowSize >= 256)
        precondition(analysisHopSize > 0 && analysisHopSize <= analysisWindowSize)
        precondition(maximumKeyWindows > 0)
        precondition(chordWindowSeconds > 0 && chordWindowSeconds.isFinite)
        precondition(chordHopSeconds > 0 && chordHopSeconds.isFinite)
        precondition(chordHopSeconds <= chordWindowSeconds)
        precondition(minimumChordSegmentSeconds >= 0 && minimumChordSegmentSeconds.isFinite)
        precondition(chordAnalysisSampleRate >= 2_000 && chordAnalysisSampleRate.isFinite)
        precondition(sectionContextSeconds > 0 && sectionContextSeconds.isFinite)
        precondition(sectionHopSeconds > 0 && sectionHopSeconds.isFinite)
        precondition(sectionHopSeconds <= sectionContextSeconds)
        precondition(minimumSectionSeconds > 0 && minimumSectionSeconds.isFinite)
        precondition(minimumEdgeSectionSeconds > 0 && minimumEdgeSectionSeconds.isFinite)
        precondition((0...1).contains(sectionNoveltyThreshold))
        precondition((0...1).contains(sectionEnergyJumpThreshold))
        precondition((0...1).contains(sectionClusterSimilarity))
        precondition((0...1).contains(minimumFunctionalSectionConfidence))
        precondition((0...1).contains(minimumSectionChordCoverage))
        precondition(sectionSilenceRMS >= 0 && sectionSilenceRMS.isFinite)
        self.minimumDurationSeconds = minimumDurationSeconds
        self.minimumTempoConfidence = minimumTempoConfidence
        self.minimumKeyConfidence = minimumKeyConfidence
        self.keyRelativeAmbiguityMargin = keyRelativeAmbiguityMargin
        self.keyModulationMargin = keyModulationMargin
        self.minimumChordConfidence = minimumChordConfidence
        self.minimumChordTemplateScore = minimumChordTemplateScore
        self.noChordRMS = noChordRMS
        self.tempoRange = tempoRange
        self.analysisWindowSize = analysisWindowSize
        self.analysisHopSize = analysisHopSize
        self.maximumKeyWindows = maximumKeyWindows
        self.chordWindowSeconds = chordWindowSeconds
        self.chordHopSeconds = chordHopSeconds
        self.minimumChordSegmentSeconds = minimumChordSegmentSeconds
        self.chordAnalysisSampleRate = chordAnalysisSampleRate
        self.sectionContextSeconds = sectionContextSeconds
        self.sectionHopSeconds = sectionHopSeconds
        self.minimumSectionSeconds = minimumSectionSeconds
        self.minimumEdgeSectionSeconds = minimumEdgeSectionSeconds
        self.sectionNoveltyThreshold = sectionNoveltyThreshold
        self.sectionEnergyJumpThreshold = sectionEnergyJumpThreshold
        self.sectionClusterSimilarity = sectionClusterSimilarity
        self.minimumFunctionalSectionConfidence = minimumFunctionalSectionConfidence
        self.minimumSectionChordCoverage = minimumSectionChordCoverage
        self.sectionSilenceRMS = sectionSilenceRMS
    }

    public static let productBaseline = MusicAnalysisConfiguration()
}

public actor ProjectOwnedMusicAnalyzer: MusicAnalyzing {
    private let loader: any AnalysisSignalLoading
    private let configuration: MusicAnalysisConfiguration

    public init(loader: any AnalysisSignalLoading, configuration: MusicAnalysisConfiguration = .productBaseline) {
        self.loader = loader
        self.configuration = configuration
    }

    public func analyze(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSnapshot {
        let loadedSignal = try await loader.loadSignal(projectID: projectID, asset: asset)
        let signal = AnalysisSnapshotRobustness.sanitize(signal: loadedSignal)
        guard signal.durationSeconds >= configuration.minimumDurationSeconds else {
            return AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        }

        let tempo = TempoBeatAnalyzer.analyze(signal: signal, configuration: configuration)
        let key = MusicalKeyAnalyzer.analyze(signal: signal, configuration: configuration)
        let chords = ChordTimelineAnalyzer.analyze(signal: signal, configuration: configuration)
        let sections = SongSectionHardener.analyze(signal: signal, chords: chords, configuration: configuration)
        let rawSnapshot = AnalysisSnapshot(tempo: tempo, key: key, chords: chords, sections: sections)
        return AnalysisSnapshotRobustness.harden(
            snapshot: rawSnapshot,
            duration: signal.durationSeconds,
            configuration: configuration
        )
    }
}
