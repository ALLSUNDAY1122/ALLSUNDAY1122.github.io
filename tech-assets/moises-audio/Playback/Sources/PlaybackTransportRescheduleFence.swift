import Foundation

public enum PlaybackTransportDiscontinuityReason: String, Codable, Sendable, CaseIterable {
    case mediaLoad
    case mediaReplacement
    case play
    case pause
    case seek
    case loopChange
    case tempoChange
    case interruptionBegan
    case interruptionEnded
    case recovery
}

public enum PlaybackTransportRescheduleError: Error, Equatable, Sendable {
    case generationOverflow
    case poisoned(activeGeneration: UInt64)
    case staleToken(activeGeneration: UInt64, tokenGeneration: UInt64)
}

public struct PlaybackTransportRescheduleToken: Equatable, Sendable {
    public let generation: UInt64
    public let reason: PlaybackTransportDiscontinuityReason

    public init(generation: UInt64, reason: PlaybackTransportDiscontinuityReason) {
        self.generation = generation
        self.reason = reason
    }
}

/// Portable generation fence for transport scheduling. Invalidation is intentionally performed
/// before old nodes/queues are stopped so any completion callback emitted by stop/pause is already
/// stale when it re-enters the owning actor. Generation overflow fails closed instead of wrapping.
public struct PlaybackTransportRescheduleFence: Equatable, Sendable {
    public private(set) var activeGeneration: UInt64
    public private(set) var lastReason: PlaybackTransportDiscontinuityReason?
    public private(set) var isPoisoned: Bool

    public init(
        activeGeneration: UInt64 = 0,
        lastReason: PlaybackTransportDiscontinuityReason? = nil,
        isPoisoned: Bool = false
    ) {
        self.activeGeneration = activeGeneration
        self.lastReason = lastReason
        self.isPoisoned = isPoisoned
    }

    @discardableResult
    public mutating func invalidate(
        for reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        guard !isPoisoned else {
            throw PlaybackTransportRescheduleError.poisoned(
                activeGeneration: activeGeneration
            )
        }
        let (next, overflow) = activeGeneration.addingReportingOverflow(1)
        guard !overflow else {
            isPoisoned = true
            lastReason = reason
            throw PlaybackTransportRescheduleError.generationOverflow
        }
        activeGeneration = next
        lastReason = reason
        return PlaybackTransportRescheduleToken(
            generation: next,
            reason: reason
        )
    }

    /// Used only by nonthrowing transport APIs such as `pause`. A nil result means the fence has
    /// failed closed; all completion tokens are rejected until the owner replaces/recreates it.
    @discardableResult
    public mutating func invalidateNonThrowing(
        for reason: PlaybackTransportDiscontinuityReason
    ) -> PlaybackTransportRescheduleToken? {
        do {
            return try invalidate(for: reason)
        } catch {
            isPoisoned = true
            lastReason = reason
            return nil
        }
    }

    public func acceptsCompletion(
        token: PlaybackTransportRescheduleToken
    ) -> Bool {
        !isPoisoned && token.generation == activeGeneration
    }

    public func validateCurrent(
        token: PlaybackTransportRescheduleToken
    ) throws {
        guard !isPoisoned else {
            throw PlaybackTransportRescheduleError.poisoned(
                activeGeneration: activeGeneration
            )
        }
        guard token.generation == activeGeneration else {
            throw PlaybackTransportRescheduleError.staleToken(
                activeGeneration: activeGeneration,
                tokenGeneration: token.generation
            )
        }
    }

    public var currentToken: PlaybackTransportRescheduleToken? {
        guard !isPoisoned, let lastReason else { return nil }
        return PlaybackTransportRescheduleToken(
            generation: activeGeneration,
            reason: lastReason
        )
    }
}

/// Decorator for the real Playback backend. It creates the externally observable schedule token
/// before delegating every transport discontinuity. Therefore a backend failure cannot accidentally
/// make an older click/audio replacement current again. HQ integration can use the `*AndReturnToken`
/// methods to bind PracticeDSP invalidation to the exact Playback discontinuity without changing the
/// frozen Shared/App protocol.
public actor RescheduleFencedPlaybackBackend: PlaybackBackendDriving {
    private let backend: any PlaybackBackendDriving
    private var fences: [ProjectID: PlaybackTransportRescheduleFence] = [:]

    public init(backend: any PlaybackBackendDriving) {
        self.backend = backend
    }

    @discardableResult
    public func loadSourceAndReturnToken(
        projectID: ProjectID,
        asset: LocalAudioAsset
    ) async throws -> PlaybackTransportRescheduleToken {
        let token = try begin(projectID: projectID, reason: .mediaLoad)
        try await backend.loadSource(projectID: projectID, asset: asset)
        return token
    }

    public func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {
        _ = try await loadSourceAndReturnToken(projectID: projectID, asset: asset)
    }

    @discardableResult
    public func loadStemsAndReturnToken(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws -> PlaybackTransportRescheduleToken {
        let token = try begin(projectID: projectID, reason: .mediaReplacement)
        try await backend.loadStems(
            projectID: projectID,
            stems: stems,
            positionSeconds: positionSeconds,
            resume: resume,
            loop: loop
        )
        return token
    }

    public func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        _ = try await loadStemsAndReturnToken(
            projectID: projectID,
            stems: stems,
            positionSeconds: positionSeconds,
            resume: resume,
            loop: loop
        )
    }

    public func setEffectiveGains(
        projectID: ProjectID,
        gains: [StemID: Double]
    ) async throws {
        try await backend.setEffectiveGains(projectID: projectID, gains: gains)
    }

    @discardableResult
    public func seekAndReturnToken(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws -> PlaybackTransportRescheduleToken {
        let token = try begin(projectID: projectID, reason: .seek)
        try await backend.seek(
            projectID: projectID,
            to: positionSeconds,
            resume: resume,
            loop: loop
        )
        return token
    }

    public func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        _ = try await seekAndReturnToken(
            projectID: projectID,
            to: positionSeconds,
            resume: resume,
            loop: loop
        )
    }

    @discardableResult
    public func setLoopAndReturnToken(
        projectID: ProjectID,
        loop: PlaybackLoopRange?
    ) async throws -> PlaybackTransportRescheduleToken {
        let token = try begin(projectID: projectID, reason: .loopChange)
        try await backend.setLoop(projectID: projectID, loop: loop)
        return token
    }

    public func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        _ = try await setLoopAndReturnToken(projectID: projectID, loop: loop)
    }

    @discardableResult
    public func playAndReturnToken(
        projectID: ProjectID
    ) async throws -> PlaybackTransportRescheduleToken {
        let token = try begin(projectID: projectID, reason: .play)
        try await backend.play(projectID: projectID)
        return token
    }

    public func play(projectID: ProjectID) async throws {
        _ = try await playAndReturnToken(projectID: projectID)
    }

    /// The protocol requires pause to be nonthrowing. The token is advanced first; on UInt64
    /// exhaustion the project fence becomes poisoned and no old token is accepted.
    @discardableResult
    public func pauseAndReturnToken(
        projectID: ProjectID
    ) async -> PlaybackTransportRescheduleToken? {
        let token = beginNonThrowing(projectID: projectID, reason: .pause)
        await backend.pause(projectID: projectID)
        return token
    }

    public func pause(projectID: ProjectID) async {
        _ = await pauseAndReturnToken(projectID: projectID)
    }

    public func currentPositionSeconds(projectID: ProjectID) async -> Double? {
        await backend.currentPositionSeconds(projectID: projectID)
    }

    /// Tempo/interruption/recovery can invalidate external schedules before HQ performs the
    /// corresponding backend reschedule. This intentionally does not mutate frozen Shared/App.
    @discardableResult
    public func invalidateExternalDiscontinuity(
        projectID: ProjectID,
        reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        switch reason {
        case .tempoChange, .interruptionBegan, .interruptionEnded, .recovery:
            return try begin(projectID: projectID, reason: reason)
        default:
            return try begin(projectID: projectID, reason: reason)
        }
    }

    public func rescheduleTokenSnapshot(
        projectID: ProjectID
    ) -> PlaybackTransportRescheduleToken? {
        fences[projectID]?.currentToken
    }

    public func acceptsCompletion(
        projectID: ProjectID,
        token: PlaybackTransportRescheduleToken
    ) -> Bool {
        (fences[projectID] ?? PlaybackTransportRescheduleFence())
            .acceptsCompletion(token: token)
    }

    private func begin(
        projectID: ProjectID,
        reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        var fence = fences[projectID] ?? PlaybackTransportRescheduleFence()
        let token = try fence.invalidate(for: reason)
        fences[projectID] = fence
        return token
    }

    private func beginNonThrowing(
        projectID: ProjectID,
        reason: PlaybackTransportDiscontinuityReason
    ) -> PlaybackTransportRescheduleToken? {
        var fence = fences[projectID] ?? PlaybackTransportRescheduleFence()
        let token = fence.invalidateNonThrowing(for: reason)
        fences[projectID] = fence
        return token
    }
}
