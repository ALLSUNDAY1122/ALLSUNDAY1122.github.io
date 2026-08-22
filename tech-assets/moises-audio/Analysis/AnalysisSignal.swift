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
    public var tempoRange: ClosedRange<Double>
    public var analysisWindowSize: Int
    public var analysisHopSize: Int
    public var maximumKeyWindows: Int

    public init(
        minimumDurationSeconds: Double = 1.5,
        minimumTempoConfidence: Double = 0.18,
        minimumKeyConfidence: Double = 0.015,
        tempoRange: ClosedRange<Double> = 55...210,
        analysisWindowSize: Int = 2048,
        analysisHopSize: Int = 512,
        maximumKeyWindows: Int = 24
    ) {
        precondition(minimumDurationSeconds >= 0)
        precondition((0...1).contains(minimumTempoConfidence))
        precondition((0...1).contains(minimumKeyConfidence))
        precondition(tempoRange.lowerBound > 0 && tempoRange.upperBound >= tempoRange.lowerBound)
        precondition(analysisWindowSize >= 256)
        precondition(analysisHopSize > 0 && analysisHopSize <= analysisWindowSize)
        precondition(maximumKeyWindows > 0)
        self.minimumDurationSeconds = minimumDurationSeconds
        self.minimumTempoConfidence = minimumTempoConfidence
        self.minimumKeyConfidence = minimumKeyConfidence
        self.tempoRange = tempoRange
        self.analysisWindowSize = analysisWindowSize
        self.analysisHopSize = analysisHopSize
        self.maximumKeyWindows = maximumKeyWindows
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
        return AnalysisSnapshot(tempo: tempo, key: key, chords: [], sections: [])
    }
}
