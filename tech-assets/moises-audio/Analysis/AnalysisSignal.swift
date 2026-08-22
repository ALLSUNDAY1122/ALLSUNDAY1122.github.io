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

    public init(
        minimumDurationSeconds: Double = 1.5,
        minimumTempoConfidence: Double = 0.18,
        minimumKeyConfidence: Double = 0.015,
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
        chordAnalysisSampleRate: Double = 8_000
    ) {
        precondition(minimumDurationSeconds >= 0)
        precondition((0...1).contains(minimumTempoConfidence))
        precondition((0...1).contains(minimumKeyConfidence))
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
        self.minimumDurationSeconds = minimumDurationSeconds
        self.minimumTempoConfidence = minimumTempoConfidence
        self.minimumKeyConfidence = minimumKeyConfidence
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
        let signal = try await loader.loadSignal(projectID: projectID, asset: asset)
        guard signal.durationSeconds >= configuration.minimumDurationSeconds else {
            return AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        }

        let tempo = TempoBeatAnalyzer.analyze(signal: signal, configuration: configuration)
        let key = MusicalKeyAnalyzer.analyze(signal: signal, configuration: configuration)
        let chords = ChordTimelineAnalyzer.analyze(signal: signal, configuration: configuration)
        return AnalysisSnapshot(tempo: tempo, key: key, chords: chords, sections: [])
    }
}
