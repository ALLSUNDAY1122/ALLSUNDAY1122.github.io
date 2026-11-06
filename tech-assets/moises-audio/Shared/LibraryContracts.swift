import Foundation

public struct SetlistID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct SetlistEntryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct StemMixEdit: Hashable, Codable, Sendable {
    public let stemID: StemID
    public let gain: Double
    public let isMuted: Bool
    public let isSoloed: Bool

    public init(stemID: StemID, gain: Double, isMuted: Bool, isSoloed: Bool) {
        precondition(gain.isFinite && gain >= 0)
        self.stemID = stemID
        self.gain = gain
        self.isMuted = isMuted
        self.isSoloed = isSoloed
    }
}

public struct ProjectUserEdits: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let tempoRatio: Double
    public let pitchSemitones: Double
    public let metronomeEnabled: Bool
    public let countInClicks: Int
    public let loopStartSeconds: Double?
    public let loopEndSeconds: Double?
    public let stemMix: [StemMixEdit]

    public init(
        schemaVersion: Int,
        tempoRatio: Double,
        pitchSemitones: Double,
        metronomeEnabled: Bool,
        countInClicks: Int,
        loopStartSeconds: Double?,
        loopEndSeconds: Double?,
        stemMix: [StemMixEdit]
    ) {
        precondition(schemaVersion > 0)
        precondition(tempoRatio.isFinite && tempoRatio > 0)
        precondition(pitchSemitones.isFinite)
        precondition(countInClicks >= 0)
        if let loopStartSeconds { precondition(loopStartSeconds.isFinite && loopStartSeconds >= 0) }
        if let loopEndSeconds { precondition(loopEndSeconds.isFinite && loopEndSeconds >= 0) }
        if let loopStartSeconds, let loopEndSeconds { precondition(loopEndSeconds >= loopStartSeconds) }
        self.schemaVersion = schemaVersion
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
        self.metronomeEnabled = metronomeEnabled
        self.countInClicks = countInClicks
        self.loopStartSeconds = loopStartSeconds
        self.loopEndSeconds = loopEndSeconds
        self.stemMix = stemMix
    }
}

public struct PersistedProjectSnapshot: Hashable, Codable, Sendable {
    public let projectID: ProjectID
    public let source: LocalAudioAsset
    public let processing: ProcessingSnapshot?
    public let stems: [StemArtifact]
    public let edits: ProjectUserEdits?

    public init(
        projectID: ProjectID,
        source: LocalAudioAsset,
        processing: ProcessingSnapshot?,
        stems: [StemArtifact],
        edits: ProjectUserEdits?
    ) {
        self.projectID = projectID
        self.source = source
        self.processing = processing
        self.stems = stems
        self.edits = edits
    }
}

public struct SetlistEntry: Hashable, Codable, Sendable {
    public let id: SetlistEntryID
    public let projectID: ProjectID
    public let position: Int

    public init(id: SetlistEntryID, projectID: ProjectID, position: Int) {
        precondition(position >= 0)
        self.id = id
        self.projectID = projectID
        self.position = position
    }
}

public struct SetlistSnapshot: Hashable, Codable, Sendable {
    public let id: SetlistID
    public let name: String
    public let entries: [SetlistEntry]

    public init(id: SetlistID, name: String, entries: [SetlistEntry]) {
        self.id = id
        self.name = name
        self.entries = entries.sorted { $0.position < $1.position }
    }
}

public enum ProcessingRecoveryPlan: Hashable, Codable, Sendable {
    case none
    case resume(jobID: ProcessingJobID)
    case retryRequired(stableErrorCode: String?)
}

/// Extended library contract. It inherits the already-used write-side ProjectPersisting
/// protocol rather than adding requirements to it, so existing App/test conformers do not break.
public protocol ProjectLibraryPersisting: ProjectPersisting {
    func listProjects() async throws -> [PersistedProjectSnapshot]
    func loadProject(projectID: ProjectID) async throws -> PersistedProjectSnapshot?

    func saveUserEdits(projectID: ProjectID, edits: ProjectUserEdits) async throws

    func createSetlist(name: String) async throws -> SetlistID
    func renameSetlist(setlistID: SetlistID, name: String) async throws
    func listSetlists() async throws -> [SetlistSnapshot]
    func replaceSetlistEntries(setlistID: SetlistID, orderedProjectIDs: [ProjectID]) async throws
    func deleteSetlist(setlistID: SetlistID) async throws

    /// Implementations must use tombstone/file-cleanup semantics internally and be idempotent.
    func deleteProject(projectID: ProjectID) async throws

    /// Returns whether an interrupted processing job can resume or must be retried.
    func recoveryPlan(projectID: ProjectID) async throws -> ProcessingRecoveryPlan
}
