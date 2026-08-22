import Foundation

public enum PlaybackControlError: Error, Equatable, Sendable {
    case noProject(ProjectID)
    case noPlayableMedia(ProjectID)
    case duplicateStemID(StemID)
    case foreignStem(expected: ProjectID, actual: ProjectID)
    case nonFiniteValue
    case invalidVolume(Double)
    case invalidSeek(Double)
    case invalidLoop(start: Double, end: Double)
    case invalidStemTiming(StemID)
    case timelineOverflow
}

public struct PlaybackLoopRange: Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double

    public init(startSeconds: Double, endSeconds: Double) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }

    public var durationSeconds: Double { endSeconds - startSeconds }
}

public struct PlaybackTrackMix: Equatable, Sendable {
    public let stemID: StemID
    public let role: StemRole
    public var volume: Double
    public var muted: Bool
    public var soloed: Bool

    public init(
        stemID: StemID,
        role: StemRole,
        volume: Double = 1,
        muted: Bool = false,
        soloed: Bool = false
    ) {
        self.stemID = stemID
        self.role = role
        self.volume = volume
        self.muted = muted
        self.soloed = soloed
    }
}

public struct PlaybackProjectSnapshot: Equatable, Sendable {
    public let projectID: ProjectID
    public let hasSource: Bool
    public let stems: [StemArtifact]
    public let trackMixes: [PlaybackTrackMix]
    public let positionSeconds: Double
    public let durationSeconds: Double?
    public let loop: PlaybackLoopRange?
    public let isPlaying: Bool
    public let scheduleGeneration: UInt64
}

public struct StemSchedulePlan: Equatable, Sendable {
    public let stemID: StemID
    public let sourceStartFrame: Int64
    public let delayedStartSeconds: Double
    public let availableFrameCount: Int64
}

public enum PlaybackTimelinePlanner {
    public static func planStem(
        _ stem: StemArtifact,
        projectPositionSeconds: Double
    ) throws -> StemSchedulePlan {
        guard projectPositionSeconds.isFinite else {
            throw PlaybackControlError.nonFiniteValue
        }
        guard stem.sampleRate.isFinite,
              stem.sampleRate > 0,
              stem.startTimeSeconds.isFinite,
              stem.startTimeSeconds >= 0,
              stem.frameCount >= 0 else {
            throw PlaybackControlError.invalidStemTiming(stem.id)
        }

        let localSeconds = projectPositionSeconds - stem.startTimeSeconds
        if localSeconds <= 0 {
            return StemSchedulePlan(
                stemID: stem.id,
                sourceStartFrame: 0,
                delayedStartSeconds: -localSeconds,
                availableFrameCount: stem.frameCount
            )
        }

        let frameDouble = (localSeconds * stem.sampleRate).rounded(.down)
        guard frameDouble.isFinite, frameDouble <= Double(Int64.max) else {
            throw PlaybackControlError.timelineOverflow
        }
        let frame = min(Int64(frameDouble), stem.frameCount)
        return StemSchedulePlan(
            stemID: stem.id,
            sourceStartFrame: frame,
            delayedStartSeconds: 0,
            availableFrameCount: stem.frameCount - frame
        )
    }

    public static func effectiveGains(
        for mixes: [PlaybackTrackMix]
    ) -> [StemID: Double] {
        let soloActive = mixes.contains(where: { $0.soloed })
        var gains: [StemID: Double] = [:]
        gains.reserveCapacity(mixes.count)
        for mix in mixes {
            let audible = !mix.muted && (!soloActive || mix.soloed)
            gains[mix.stemID] = audible ? mix.volume : 0
        }
        return gains
    }

    public static func projectDuration(
        stems: [StemArtifact],
        sourceDurationSeconds: Double?
    ) throws -> Double? {
        var duration = sourceDurationSeconds
        if let duration, (!duration.isFinite || duration < 0) {
            throw PlaybackControlError.nonFiniteValue
        }
        for stem in stems {
            guard stem.startTimeSeconds.isFinite,
                  stem.startTimeSeconds >= 0,
                  stem.sampleRate.isFinite,
                  stem.sampleRate > 0 else {
                throw PlaybackControlError.invalidStemTiming(stem.id)
            }
            let end = stem.startTimeSeconds + stem.durationSeconds
            guard end.isFinite else { throw PlaybackControlError.timelineOverflow }
            duration = max(duration ?? 0, end)
        }
        return duration
    }
}

public protocol PlaybackBackendDriving: Sendable {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws
    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws
    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws
    func play(projectID: ProjectID) async throws
    func pause(projectID: ProjectID) async
    func currentPositionSeconds(projectID: ProjectID) async -> Double?
}

/// Owns per-project transport/mixer state while keeping AVAudioEngine details behind a backend.
/// It implements the HQ PlaybackPreparing contract without requiring Shared changes.
public actor MultiTrackPlaybackController: PlaybackPreparing {
    private struct ProjectState: Sendable {
        var source: LocalAudioAsset?
        var stems: [StemArtifact] = []
        var mixes: [StemID: PlaybackTrackMix] = [:]
        var positionSeconds: Double = 0
        var loop: PlaybackLoopRange?
        var isPlaying = false
        var scheduleGeneration: UInt64 = 0
    }

    private let backend: any PlaybackBackendDriving
    private var projects: [ProjectID: ProjectState] = [:]

    public init(backend: any PlaybackBackendDriving) {
        self.backend = backend
    }

    public func prepareSource(
        projectID: ProjectID,
        asset: LocalAudioAsset
    ) async throws {
        try await backend.loadSource(projectID: projectID, asset: asset)
        var state = projects[projectID] ?? ProjectState()
        state.source = asset
        state.stems = []
        state.mixes = [:]
        state.positionSeconds = 0
        state.loop = nil
        state.isPlaying = false
        state.scheduleGeneration &+= 1
        projects[projectID] = state
    }

    /// Preserves the current source-playback clock when separation finishes, then swaps to stems.
    public func replaceWithStems(
        projectID: ProjectID,
        stems: [StemArtifact]
    ) async throws {
        var state = projects[projectID] ?? ProjectState()
        guard !stems.isEmpty else {
            throw PlaybackControlError.noPlayableMedia(projectID)
        }

        var seen = Set<StemID>()
        for stem in stems {
            guard stem.projectID == projectID else {
                throw PlaybackControlError.foreignStem(
                    expected: projectID,
                    actual: stem.projectID
                )
            }
            guard seen.insert(stem.id).inserted else {
                throw PlaybackControlError.duplicateStemID(stem.id)
            }
            _ = try PlaybackTimelinePlanner.planStem(
                stem,
                projectPositionSeconds: state.positionSeconds
            )
        }

        if state.isPlaying,
           let current = await backend.currentPositionSeconds(projectID: projectID),
           current.isFinite,
           current >= 0 {
            state.positionSeconds = current
        }

        state.stems = stems
        state.mixes = Dictionary(uniqueKeysWithValues: stems.map { stem in
            let existing = state.mixes[stem.id] ?? PlaybackTrackMix(
                stemID: stem.id,
                role: stem.role
            )
            return (stem.id, existing)
        })
        state.scheduleGeneration &+= 1

        try await backend.loadStems(
            projectID: projectID,
            stems: stems,
            positionSeconds: state.positionSeconds,
            resume: state.isPlaying,
            loop: state.loop
        )
        try await backend.setEffectiveGains(
            projectID: projectID,
            gains: PlaybackTimelinePlanner.effectiveGains(
                for: Array(state.mixes.values)
            )
        )
        projects[projectID] = state
    }

    public func setVolume(
        _ volume: Double,
        stemID: StemID,
        projectID: ProjectID
    ) async throws {
        guard volume.isFinite else {
            throw PlaybackControlError.nonFiniteValue
        }
        guard (0...1).contains(volume) else {
            throw PlaybackControlError.invalidVolume(volume)
        }
        var state = try requireProject(projectID)
        guard var mix = state.mixes[stemID] else {
            throw PlaybackControlError.noPlayableMedia(projectID)
        }
        mix.volume = volume
        state.mixes[stemID] = mix
        try await applyMix(&state, projectID: projectID)
    }

    public func setMuted(
        _ muted: Bool,
        stemID: StemID,
        projectID: ProjectID
    ) async throws {
        var state = try requireProject(projectID)
        guard var mix = state.mixes[stemID] else {
            throw PlaybackControlError.noPlayableMedia(projectID)
        }
        mix.muted = muted
        state.mixes[stemID] = mix
        try await applyMix(&state, projectID: projectID)
    }

    public func setSoloed(
        _ soloed: Bool,
        stemID: StemID,
        projectID: ProjectID
    ) async throws {
        var state = try requireProject(projectID)
        guard var mix = state.mixes[stemID] else {
            throw PlaybackControlError.noPlayableMedia(projectID)
        }
        mix.soloed = soloed
        state.mixes[stemID] = mix
        try await applyMix(&state, projectID: projectID)
    }

    public func seek(
        to positionSeconds: Double,
        projectID: ProjectID
    ) async throws {
        guard positionSeconds.isFinite, positionSeconds >= 0 else {
            throw PlaybackControlError.invalidSeek(positionSeconds)
        }
        var state = try requireProject(projectID)
        let duration = try PlaybackTimelinePlanner.projectDuration(
            stems: state.stems,
            sourceDurationSeconds: state.source?.durationSeconds
        )
        if let duration, positionSeconds > duration {
            throw PlaybackControlError.invalidSeek(positionSeconds)
        }
        state.positionSeconds = positionSeconds
        state.scheduleGeneration &+= 1
        try await backend.seek(
            projectID: projectID,
            to: positionSeconds,
            resume: state.isPlaying,
            loop: state.loop
        )
        projects[projectID] = state
    }

    public func setLoop(
        startSeconds: Double,
        endSeconds: Double,
        projectID: ProjectID
    ) async throws {
        guard startSeconds.isFinite,
              endSeconds.isFinite,
              startSeconds >= 0,
              endSeconds > startSeconds else {
            throw PlaybackControlError.invalidLoop(
                start: startSeconds,
                end: endSeconds
            )
        }
        var state = try requireProject(projectID)
        if let duration = try PlaybackTimelinePlanner.projectDuration(
            stems: state.stems,
            sourceDurationSeconds: state.source?.durationSeconds
        ), endSeconds > duration {
            throw PlaybackControlError.invalidLoop(
                start: startSeconds,
                end: endSeconds
            )
        }
        let loop = PlaybackLoopRange(
            startSeconds: startSeconds,
            endSeconds: endSeconds
        )
        state.loop = loop
        state.scheduleGeneration &+= 1
        try await backend.setLoop(projectID: projectID, loop: loop)
        projects[projectID] = state
    }

    public func clearLoop(projectID: ProjectID) async throws {
        var state = try requireProject(projectID)
        state.loop = nil
        state.scheduleGeneration &+= 1
        try await backend.setLoop(projectID: projectID, loop: nil)
        projects[projectID] = state
    }

    public func play(projectID: ProjectID) async throws {
        var state = try requireProject(projectID)
        guard state.source != nil || !state.stems.isEmpty else {
            throw PlaybackControlError.noPlayableMedia(projectID)
        }
        try await backend.play(projectID: projectID)
        state.isPlaying = true
        projects[projectID] = state
    }

    public func pause(projectID: ProjectID) async throws {
        var state = try requireProject(projectID)
        if let current = await backend.currentPositionSeconds(projectID: projectID),
           current.isFinite,
           current >= 0 {
            state.positionSeconds = current
        }
        await backend.pause(projectID: projectID)
        state.isPlaying = false
        projects[projectID] = state
    }

    public func snapshot(
        projectID: ProjectID
    ) async throws -> PlaybackProjectSnapshot {
        var state = try requireProject(projectID)
        if state.isPlaying,
           let current = await backend.currentPositionSeconds(projectID: projectID),
           current.isFinite,
           current >= 0 {
            state.positionSeconds = current
            projects[projectID] = state
        }
        let duration = try PlaybackTimelinePlanner.projectDuration(
            stems: state.stems,
            sourceDurationSeconds: state.source?.durationSeconds
        )
        return PlaybackProjectSnapshot(
            projectID: projectID,
            hasSource: state.source != nil,
            stems: state.stems,
            trackMixes: state.mixes.values.sorted { lhs, rhs in
                if lhs.role.rawValue == rhs.role.rawValue {
                    return lhs.stemID.rawValue.uuidString < rhs.stemID.rawValue.uuidString
                }
                return lhs.role.rawValue < rhs.role.rawValue
            },
            positionSeconds: state.positionSeconds,
            durationSeconds: duration,
            loop: state.loop,
            isPlaying: state.isPlaying,
            scheduleGeneration: state.scheduleGeneration
        )
    }

    private func requireProject(
        _ projectID: ProjectID
    ) throws -> ProjectState {
        guard let state = projects[projectID] else {
            throw PlaybackControlError.noProject(projectID)
        }
        return state
    }

    private func applyMix(
        _ state: inout ProjectState,
        projectID: ProjectID
    ) async throws {
        try await backend.setEffectiveGains(
            projectID: projectID,
            gains: PlaybackTimelinePlanner.effectiveGains(
                for: Array(state.mixes.values)
            )
        )
        projects[projectID] = state
    }
}
