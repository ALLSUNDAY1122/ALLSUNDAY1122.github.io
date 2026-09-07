import Foundation

public enum Lane3GenerationDifferentialOracleError: Error, Equatable, Sendable {
    case generationOverflow
    case operationSerialOverflow
    case invalidTempoRatio(Double)
    case invalidCountInClicks(Int)
    case productionMismatch(String)
}

public struct Lane3GenerationDifferentialOracleState: Equatable, Sendable {
    public var playbackGeneration: UInt64
    public var clickGeneration: UInt64
    public var tempoRatio: Double
    public var metronomeEnabled: Bool
    public var pendingCountInClicks: Int?
    public var activeBinding: PracticeDSPTransportGenerationBinding?
    public var poisoned: Bool
    public var operationSerial: UInt64

    public init(
        playbackGeneration: UInt64 = 0,
        clickGeneration: UInt64 = 0,
        tempoRatio: Double = 1,
        metronomeEnabled: Bool = false,
        pendingCountInClicks: Int? = nil,
        activeBinding: PracticeDSPTransportGenerationBinding? = nil,
        poisoned: Bool = false,
        operationSerial: UInt64 = 0
    ) {
        self.playbackGeneration = playbackGeneration
        self.clickGeneration = clickGeneration
        self.tempoRatio = tempoRatio
        self.metronomeEnabled = metronomeEnabled
        self.pendingCountInClicks = pendingCountInClicks
        self.activeBinding = activeBinding
        self.poisoned = poisoned
        self.operationSerial = operationSerial
    }
}

/// Independent AW11-derived oracle for AW12 production generation semantics.
/// It predicts the state transitions that must be visible after each coordinator call without
/// consulting the production result. The fuzz harness feeds identical operations to this oracle and
/// `PracticeDSPGenerationCoordinator`, then compares the complete generation/control snapshot.
/// Passing this oracle is portable correctness evidence only; it does not prove device timing,
/// click/pop freedom, audible DSP quality, or Moises parity.
public struct Lane3GenerationDifferentialOracle: Sendable {
    public private(set) var state: Lane3GenerationDifferentialOracleState

    public init(state: Lane3GenerationDifferentialOracleState = Lane3GenerationDifferentialOracleState()) {
        self.state = state
    }

    @discardableResult
    public mutating func successfulTransport(
        reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        try advanceSerial()
        let playback = try advancePlayback()
        let click = try advanceClick()
        let mapped = try mappedReason(reason)
        state.activeBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: playback,
            clickGeneration: click,
            reason: mapped
        )
        state.poisoned = false
        return PlaybackTransportRescheduleToken(generation: playback, reason: reason)
    }

    @discardableResult
    public mutating func successfulTempo(
        _ ratio: Double
    ) throws -> PlaybackTransportRescheduleToken {
        guard ratio.isFinite, (0.03125...32).contains(ratio) else {
            throw Lane3GenerationDifferentialOracleError.invalidTempoRatio(ratio)
        }
        try advanceSerial()
        let playback = try advancePlayback()
        let click = try advanceClick()
        state.tempoRatio = ratio
        state.activeBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: playback,
            clickGeneration: click,
            reason: .tempoChange
        )
        state.poisoned = false
        return PlaybackTransportRescheduleToken(generation: playback, reason: .tempoChange)
    }

    public mutating func successfulMetronome(_ enabled: Bool) throws {
        try advanceSerial()
        _ = try advanceClick()
        state.metronomeEnabled = enabled
        state.activeBinding = nil
    }

    public mutating func successfulCountIn(_ clicks: Int) throws {
        guard (1...32).contains(clicks) else {
            throw Lane3GenerationDifferentialOracleError.invalidCountInClicks(clicks)
        }
        try advanceSerial()
        _ = try advanceClick()
        state.pendingCountInClicks = clicks
        state.activeBinding = nil
    }

    public mutating func failedTransportAfterClickAdvance(
        reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        try advanceSerial()
        let playback = try advancePlayback()
        _ = try advanceClick()
        state.activeBinding = nil
        state.poisoned = true
        return PlaybackTransportRescheduleToken(generation: playback, reason: reason)
    }

    public mutating func failedMetronomeAfterClickAdvance(_ enabled: Bool) throws {
        try advanceSerial()
        _ = try advanceClick()
        state.metronomeEnabled = enabled
        state.activeBinding = nil
        state.poisoned = true
    }

    public mutating func failedCountInAfterClickAdvance(_ clicks: Int) throws {
        guard (1...32).contains(clicks) else {
            throw Lane3GenerationDifferentialOracleError.invalidCountInClicks(clicks)
        }
        try advanceSerial()
        _ = try advanceClick()
        state.pendingCountInClicks = clicks
        state.activeBinding = nil
        state.poisoned = true
    }

    /// Models an invalid tempo value after Playback already advanced its external fence.
    /// DSP validation fails before click generation advances, but the Playback generation becomes a
    /// recovery floor and old replacement authority is revoked.
    @discardableResult
    public mutating func failedInvalidTempo(
        _ ratio: Double
    ) throws -> PlaybackTransportRescheduleToken {
        guard !ratio.isFinite || !(0.03125...32).contains(ratio) else {
            throw Lane3GenerationDifferentialOracleError.invalidTempoRatio(ratio)
        }
        try advanceSerial()
        let playback = try advancePlayback()
        state.activeBinding = nil
        state.poisoned = true
        return PlaybackTransportRescheduleToken(generation: playback, reason: .tempoChange)
    }

    /// A new Playback token sent through the wrong coordinator entry point is already externally
    /// visible. The safe production behavior is therefore to record it as the new recovery floor,
    /// revoke any old binding, and poison. Replayed/stale wrong-route tokens are modeled separately.
    @discardableResult
    public mutating func rejectedNewPlaybackWrongRoute(
        reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        try advanceSerial()
        let playback = try advancePlayback()
        state.activeBinding = nil
        state.poisoned = true
        return PlaybackTransportRescheduleToken(generation: playback, reason: reason)
    }

    /// A normal transport call made while already poisoned can still arrive after Playback advanced.
    /// That generation must become the recovery floor even though the coordinator rejects the call.
    @discardableResult
    public mutating func rejectedNewPlaybackWhilePoisoned(
        reason: PlaybackTransportDiscontinuityReason
    ) throws -> PlaybackTransportRescheduleToken {
        precondition(state.poisoned)
        try advanceSerial()
        let playback = try advancePlayback()
        state.activeBinding = nil
        return PlaybackTransportRescheduleToken(generation: playback, reason: reason)
    }

    public mutating func rejectedStalePlaybackCall() throws {
        try advanceSerial()
    }

    public mutating func rejectedInvalidCountIn(_ clicks: Int) throws {
        guard !(1...32).contains(clicks) else {
            throw Lane3GenerationDifferentialOracleError.invalidCountInClicks(clicks)
        }
        try advanceSerial()
    }

    /// Recovery using the current failed/rejected Playback generation is rejected only after the
    /// production controller has advanced click generation, so both floors must be retained.
    public mutating func failedRecoveryUsingCurrentPlaybackGeneration() throws {
        precondition(state.poisoned)
        try advanceSerial()
        _ = try advanceClick()
        state.activeBinding = nil
    }

    @discardableResult
    public mutating func successfulRecovery() throws -> PlaybackTransportRescheduleToken {
        try advanceSerial()
        let playback = try advancePlayback()
        let click = try advanceClick()
        state.activeBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: playback,
            clickGeneration: click,
            reason: .recovery
        )
        state.poisoned = false
        return PlaybackTransportRescheduleToken(generation: playback, reason: .recovery)
    }

    public func validate(
        production: PracticeDSPGenerationCoordinatorSnapshot,
        tempoTolerance: Double = 0.000_000_1
    ) throws {
        guard production.operationSerial == state.operationSerial else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "operationSerial expected=\(state.operationSerial) actual=\(production.operationSerial)"
            )
        }
        guard production.dspState.scheduleGeneration == state.clickGeneration else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "clickGeneration expected=\(state.clickGeneration) actual=\(production.dspState.scheduleGeneration)"
            )
        }
        guard production.isPoisoned == state.poisoned else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "poison expected=\(state.poisoned) actual=\(production.isPoisoned)"
            )
        }
        guard production.activeBinding == state.activeBinding else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch("binding mismatch")
        }
        guard production.dspState.tempoRatio.isFinite,
              abs(production.dspState.tempoRatio - state.tempoRatio) <= tempoTolerance else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "tempo expected=\(state.tempoRatio) actual=\(production.dspState.tempoRatio)"
            )
        }
        guard production.dspState.metronomeEnabled == state.metronomeEnabled else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "metronome expected=\(state.metronomeEnabled) actual=\(production.dspState.metronomeEnabled)"
            )
        }
        guard production.dspState.pendingCountInClicks == state.pendingCountInClicks else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "countIn expected=\(String(describing: state.pendingCountInClicks)) actual=\(String(describing: production.dspState.pendingCountInClicks))"
            )
        }
    }

    private mutating func advanceSerial() throws {
        let (next, overflow) = state.operationSerial.addingReportingOverflow(1)
        guard !overflow else { throw Lane3GenerationDifferentialOracleError.operationSerialOverflow }
        state.operationSerial = next
    }

    private mutating func advancePlayback() throws -> UInt64 {
        let (next, overflow) = state.playbackGeneration.addingReportingOverflow(1)
        guard !overflow else { throw Lane3GenerationDifferentialOracleError.generationOverflow }
        state.playbackGeneration = next
        return next
    }

    private mutating func advanceClick() throws -> UInt64 {
        let (next, overflow) = state.clickGeneration.addingReportingOverflow(1)
        guard !overflow else { throw Lane3GenerationDifferentialOracleError.generationOverflow }
        state.clickGeneration = next
        return next
    }

    private func mappedReason(
        _ reason: PlaybackTransportDiscontinuityReason
    ) throws -> PracticeDSPTransportDiscontinuityReason {
        guard let mapped = PracticeDSPTransportDiscontinuityReason(rawValue: reason.rawValue) else {
            throw Lane3GenerationDifferentialOracleError.productionMismatch(
                "unmapped reason \(reason.rawValue)"
            )
        }
        return mapped
    }
}
