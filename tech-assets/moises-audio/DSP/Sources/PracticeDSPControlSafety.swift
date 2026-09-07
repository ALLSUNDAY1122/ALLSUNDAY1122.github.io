import Foundation

public protocol PracticeDSPBackendApplying: Sendable {
    func apply(tempoRatio: Double, pitchSemitones: Double) throws
}

public enum PracticeDSPApplicationError: Error, Equatable, Sendable {
    case backendUnavailable
    case backendRejected(String)
}

public enum PracticeDSPStateValidator {
    public static func validate(
        _ state: PracticeDSPState,
        capabilities: PracticeDSPCapabilities
    ) throws {
        guard state.tempoRatio.isFinite else {
            throw PracticeDSPConfigurationError.nonFiniteTempoRatio
        }
        guard capabilities.tempoRatioRange.contains(state.tempoRatio) else {
            throw PracticeDSPConfigurationError.tempoRatioOutOfBackendRange(state.tempoRatio)
        }
        guard state.pitchSemitones.isFinite else {
            throw PracticeDSPConfigurationError.nonFinitePitch
        }
        guard capabilities.pitchSemitoneRange.contains(state.pitchSemitones) else {
            throw PracticeDSPConfigurationError.pitchOutOfBackendRange(state.pitchSemitones)
        }
        if let clicks = state.pendingCountInClicks,
           !capabilities.countInClickRange.contains(clicks) {
            throw PracticeDSPConfigurationError.countInOutOfBackendRange(clicks)
        }
    }

    /// Restored state is validated atomically and receives a fresh generation token so any
    /// persisted pre-interruption click schedule cannot be mistaken for a currently active one.
    public static func restored(
        _ state: PracticeDSPState,
        capabilities: PracticeDSPCapabilities
    ) throws -> PracticeDSPState {
        try validate(state, capabilities: capabilities)
        var restored = state
        restored.scheduleGeneration = try nextGeneration(after: state.scheduleGeneration)
        return restored
    }

    public static func nextGeneration(after current: UInt64) throws -> UInt64 {
        let (next, overflow) = current.addingReportingOverflow(1)
        guard !overflow else {
            throw PracticeDSPConfigurationError.scheduleGenerationOverflow
        }
        return next
    }
}

/// Fail-closed bridge between validated portable settings and an optional Apple/backend node.
/// The last-applied snapshot is committed only after the backend accepts both tempo and pitch.
public actor PracticeDSPApplicationGate {
    private let capabilities: PracticeDSPCapabilities
    private let backend: (any PracticeDSPBackendApplying)?
    private var lastApplied: PracticeDSPState

    public init(
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        backend: (any PracticeDSPBackendApplying)?,
        initialState: PracticeDSPState = PracticeDSPState()
    ) throws {
        try PracticeDSPStateValidator.validate(initialState, capabilities: capabilities)
        self.capabilities = capabilities
        self.backend = backend
        self.lastApplied = initialState
    }

    @discardableResult
    public func apply(_ candidate: PracticeDSPState) throws -> PracticeDSPState {
        try PracticeDSPStateValidator.validate(candidate, capabilities: capabilities)
        guard let backend else {
            throw PracticeDSPApplicationError.backendUnavailable
        }
        do {
            try backend.apply(
                tempoRatio: candidate.tempoRatio,
                pitchSemitones: candidate.pitchSemitones
            )
        } catch {
            throw PracticeDSPApplicationError.backendRejected(String(describing: error))
        }
        lastApplied = candidate
        return candidate
    }

    public func lastAppliedState() -> PracticeDSPState {
        lastApplied
    }
}
