import Foundation

public struct ProjectID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct AssetID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct ProcessingJobID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct StemID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct StemRole: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let vocals = StemRole(rawValue: "vocals")
    public static let drums = StemRole(rawValue: "drums")
    public static let bass = StemRole(rawValue: "bass")
    public static let other = StemRole(rawValue: "other")
    public static let instrumental = StemRole(rawValue: "instrumental")
}

public enum ImportedMediaKind: String, Codable, Sendable {
    case audio
    case videoWithAudio
}

/// Durable, app-owned asset identity. External picker/provider URLs never cross this boundary.
public struct LocalAudioAsset: Hashable, Codable, Sendable {
    public let id: AssetID
    public let relativePath: String
    public let mediaKind: ImportedMediaKind
    public let durationSeconds: Double?

    public init(id: AssetID, relativePath: String, mediaKind: ImportedMediaKind, durationSeconds: Double? = nil) {
        self.id = id
        self.relativePath = relativePath
        self.mediaKind = mediaKind
        self.durationSeconds = durationSeconds
    }
}

public struct StemArtifact: Hashable, Codable, Sendable {
    public let id: StemID
    public let projectID: ProjectID
    public let role: StemRole
    public let relativePath: String
    public let sampleRate: Double
    public let channels: Int
    public let frameCount: Int64
    public let startTimeSeconds: Double

    public init(
        id: StemID,
        projectID: ProjectID,
        role: StemRole,
        relativePath: String,
        sampleRate: Double,
        channels: Int,
        frameCount: Int64,
        startTimeSeconds: Double = 0
    ) {
        precondition(sampleRate > 0)
        precondition(channels > 0)
        precondition(frameCount >= 0)
        self.id = id
        self.projectID = projectID
        self.role = role
        self.relativePath = relativePath
        self.sampleRate = sampleRate
        self.channels = channels
        self.frameCount = frameCount
        self.startTimeSeconds = startTimeSeconds
    }

    public var durationSeconds: Double {
        Double(frameCount) / sampleRate
    }
}

public enum ProcessingPhase: String, Codable, Sendable {
    case queued
    case uploading
    case separating
    case finalizing
    case ready
    case cancelled
    case failed
}

public struct ProcessingSnapshot: Equatable, Codable, Sendable {
    public let jobID: ProcessingJobID
    public let phase: ProcessingPhase
    public let fractionComplete: Double?
    public let retryable: Bool
    public let stableErrorCode: String?

    public init(
        jobID: ProcessingJobID,
        phase: ProcessingPhase,
        fractionComplete: Double?,
        retryable: Bool = false,
        stableErrorCode: String? = nil
    ) {
        if let fractionComplete {
            precondition((0...1).contains(fractionComplete))
        }
        self.jobID = jobID
        self.phase = phase
        self.fractionComplete = fractionComplete
        self.retryable = retryable
        self.stableErrorCode = stableErrorCode
    }
}

public enum PlaybackReadiness: Equatable, Codable, Sendable {
    case sourceOnly
    case stemsPreparing
    case stemsReady([StemArtifact])
    case unavailable(stableErrorCode: String)
}

public struct TempoAnalysis: Equatable, Codable, Sendable {
    public let bpm: Double
    public let confidence: Double?
    public let beatTimesSeconds: [Double]
}

public struct MusicalKey: Equatable, Codable, Sendable {
    public let tonicPitchClass: Int
    public let mode: String
    public let confidence: Double?

    public init(tonicPitchClass: Int, mode: String, confidence: Double?) {
        precondition((0...11).contains(tonicPitchClass))
        self.tonicPitchClass = tonicPitchClass
        self.mode = mode
        self.confidence = confidence
    }
}

public struct ChordEvent: Equatable, Codable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let normalizedLabel: String
    public let confidence: Double?
}

public struct SongSection: Equatable, Codable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let structuralLabel: String
    public let functionalLabel: String?
    public let confidence: Double?
}

public struct AnalysisSnapshot: Equatable, Codable, Sendable {
    public let tempo: TempoAnalysis?
    public let key: MusicalKey?
    public let chords: [ChordEvent]
    public let sections: [SongSection]
}

public struct SeparationRequest: Hashable, Codable, Sendable {
    public let projectID: ProjectID
    public let asset: LocalAudioAsset
    public let requestedRoles: Set<StemRole>
    public let qualityProfile: String
}

public struct ExportRequest: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case separatedStems
        case customMix
    }

    public let projectID: ProjectID
    public let kind: Kind
    public let preferredContainer: String
}

public struct ExportArtifact: Hashable, Codable, Sendable {
    public let relativePath: String
    public let mediaType: String
}

public enum DomainFailure: Error, Equatable, Codable, Sendable {
    case accessDenied
    case providerUnavailable
    case networkUnavailable
    case networkTimeout
    case unsupportedMedia
    case protectedMedia
    case corruptMedia
    case noAudioTrack
    case insufficientStorage
    case cancelled
    case processingFailed(code: String, retryable: Bool)
    case exportFailed(code: String)
}

public protocol AudioImporting: Sendable {
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset
}

public enum ImportRequest: Hashable, Codable, Sendable {
    case appOwnedFile(relativePath: String)
    case directDownloadURL(URL)
}

public protocol SourceSeparationProviding: Sendable {
    func start(_ request: SeparationRequest) async throws -> ProcessingJobID
    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot
    func result(jobID: ProcessingJobID) async throws -> [StemArtifact]
    func cancel(jobID: ProcessingJobID) async
}

public protocol PlaybackPreparing: Sendable {
    func prepareSource(projectID: ProjectID, asset: LocalAudioAsset) async throws
    func replaceWithStems(projectID: ProjectID, stems: [StemArtifact]) async throws
}

public protocol MusicAnalyzing: Sendable {
    func analyze(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSnapshot
}

public protocol PracticeDSPConfiguring: Sendable {
    func setTempoRatio(_ ratio: Double, projectID: ProjectID) async throws
    func setPitchSemitones(_ semitones: Double, projectID: ProjectID) async throws
    func setMetronomeEnabled(_ enabled: Bool, projectID: ProjectID) async throws
    func scheduleCountIn(clicks: Int, projectID: ProjectID) async throws
}

public protocol ProjectPersisting: Sendable {
    func createProject(source: LocalAudioAsset) async throws -> ProjectID
    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws
}

public protocol AudioExporting: Sendable {
    func export(_ request: ExportRequest) async throws -> [ExportArtifact]
}
