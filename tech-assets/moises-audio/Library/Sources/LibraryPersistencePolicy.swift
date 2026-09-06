import Foundation

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public enum LibraryPersistenceFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case invalidSetlistName
    case projectNotFound(ProjectID)
    case setlistNotFound(SetlistID)
    case stemProjectMismatch(stemID: StemID, expected: ProjectID, actual: ProjectID)
    case duplicateStemID(StemID)
    case duplicateStemMixID(StemID)
    case assetIdentityConflict(AssetID)
    case corruptRecord(String)
}

public enum LibraryPathPolicy {
    public static func validate(relativePath: String) throws {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw LibraryPersistenceFailure.invalidRelativePath(relativePath)
        }

        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw LibraryPersistenceFailure.invalidRelativePath(relativePath)
        }
    }
}

public enum LibraryNamePolicy {
    public static func normalizedSetlistName(_ name: String) throws -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw LibraryPersistenceFailure.invalidSetlistName
        }
        return normalized
    }
}

public enum LibrarySnapshotPolicy {
    public static func validate(source: LocalAudioAsset) throws {
        try LibraryPathPolicy.validate(relativePath: source.relativePath)
        if let duration = source.durationSeconds, (!duration.isFinite || duration < 0) {
            throw LibraryPersistenceFailure.corruptRecord("source.durationSeconds")
        }
    }

    public static func validate(stems: [StemArtifact], projectID: ProjectID) throws {
        var ids = Set<StemID>()
        for stem in stems {
            guard stem.projectID == projectID else {
                throw LibraryPersistenceFailure.stemProjectMismatch(
                    stemID: stem.id,
                    expected: projectID,
                    actual: stem.projectID
                )
            }
            guard ids.insert(stem.id).inserted else {
                throw LibraryPersistenceFailure.duplicateStemID(stem.id)
            }
            try LibraryPathPolicy.validate(relativePath: stem.relativePath)
            guard stem.sampleRate.isFinite, stem.sampleRate > 0,
                  stem.channels > 0,
                  stem.frameCount >= 0,
                  stem.startTimeSeconds.isFinite,
                  stem.startTimeSeconds >= 0 else {
                throw LibraryPersistenceFailure.corruptRecord("stem.numericFields")
            }
        }
    }

    public static func validate(edits: ProjectUserEdits) throws {
        guard edits.schemaVersion > 0,
              edits.tempoRatio.isFinite,
              edits.tempoRatio > 0,
              edits.pitchSemitones.isFinite,
              edits.countInClicks >= 0 else {
            throw LibraryPersistenceFailure.corruptRecord("edits.scalarFields")
        }
        if let start = edits.loopStartSeconds, (!start.isFinite || start < 0) {
            throw LibraryPersistenceFailure.corruptRecord("edits.loopStartSeconds")
        }
        if let end = edits.loopEndSeconds, (!end.isFinite || end < 0) {
            throw LibraryPersistenceFailure.corruptRecord("edits.loopEndSeconds")
        }
        if let start = edits.loopStartSeconds,
           let end = edits.loopEndSeconds,
           end < start {
            throw LibraryPersistenceFailure.corruptRecord("edits.loopRange")
        }

        var stemIDs = Set<StemID>()
        for mix in edits.stemMix {
            guard stemIDs.insert(mix.stemID).inserted else {
                throw LibraryPersistenceFailure.duplicateStemMixID(mix.stemID)
            }
            guard mix.gain.isFinite, mix.gain >= 0 else {
                throw LibraryPersistenceFailure.corruptRecord("edits.stemMix.gain")
            }
        }
    }
}

public enum LibraryRecoveryPolicy {
    public static func plan(for processing: ProcessingSnapshot?) -> ProcessingRecoveryPlan {
        guard let processing else { return .none }
        switch processing.phase {
        case .queued, .uploading, .separating, .finalizing:
            return .resume(jobID: processing.jobID)
        case .ready:
            return .none
        case .cancelled:
            return .retryRequired(stableErrorCode: processing.stableErrorCode ?? "CANCELLED")
        case .failed:
            return .retryRequired(stableErrorCode: processing.stableErrorCode)
        }
    }
}
