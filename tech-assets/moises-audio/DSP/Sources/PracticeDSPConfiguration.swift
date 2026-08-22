import Foundation

public struct PracticeDSPCapabilities: Equatable, Sendable {
    public let tempoRatioRange: ClosedRange<Double>
    public let pitchSemitoneRange: ClosedRange<Double>
    public let countInClickRange: ClosedRange<Int>

    public init(
        tempoRatioRange: ClosedRange<Double> = 0.03125...32.0,
        pitchSemitoneRange: ClosedRange<Double> = -24.0...24.0,
        countInClickRange: ClosedRange<Int> = 1...32
    ) {
        self.tempoRatioRange = tempoRatioRange
        self.pitchSemitoneRange = pitchSemitoneRange
        self.countInClickRange = countInClickRange
    }

    public static let appleTimePitchBaseline = PracticeDSPCapabilities()
}

public struct PracticeDSPState: Equatable, Sendable {
    public var tempoRatio: Double
    public var pitchSemitones: Double
    public var metronomeEnabled: Bool
    public var pendingCountInClicks: Int?
    public var scheduleGeneration: UInt64

    public init(
        tempoRatio: Double = 1.0,
        pitchSemitones: Double = 0.0,
        metronomeEnabled: Bool = false,
        pendingCountInClicks: Int? = nil,
        scheduleGeneration: UInt64 = 0
    ) {
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
        self.metronomeEnabled = metronomeEnabled
        self.pendingCountInClicks = pendingCountInClicks
        self.scheduleGeneration = scheduleGeneration
    }
}

public enum PracticeDSPConfigurationError: Error, Equatable, Sendable {
    case nonFiniteTempoRatio
    case tempoRatioOutOfBackendRange(Double)
    case nonFinitePitch
    case pitchOutOfBackendRange(Double)
    case countInOutOfBackendRange(Int)
}

public enum PracticeDSPMath {
    public static func cents(forSemitones semitones: Double) -> Double {
        semitones * 100.0
    }

    public static func outputDurationSeconds(sourceDurationSeconds: Double, tempoRatio: Double) -> Double {
        sourceDurationSeconds / tempoRatio
    }
}

/// Configuration owner for the DSP logical resource.
/// Playback remains responsible for transport/engine ownership; this actor stores validated
/// project-scoped practice settings and a generation token used to invalidate stale schedules.
public actor PracticeDSPController: PracticeDSPConfiguring {
    private let capabilities: PracticeDSPCapabilities
    private var states: [ProjectID: PracticeDSPState] = [:]

    public init(capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline) {
        self.capabilities = capabilities
    }

    public func setTempoRatio(_ ratio: Double, projectID: ProjectID) async throws {
        guard ratio.isFinite else { throw PracticeDSPConfigurationError.nonFiniteTempoRatio }
        guard capabilities.tempoRatioRange.contains(ratio) else {
            throw PracticeDSPConfigurationError.tempoRatioOutOfBackendRange(ratio)
        }
        var state = states[projectID] ?? PracticeDSPState()
        state.tempoRatio = ratio
        state.scheduleGeneration &+= 1
        states[projectID] = state
    }

    public func setPitchSemitones(_ semitones: Double, projectID: ProjectID) async throws {
        guard semitones.isFinite else { throw PracticeDSPConfigurationError.nonFinitePitch }
        guard capabilities.pitchSemitoneRange.contains(semitones) else {
            throw PracticeDSPConfigurationError.pitchOutOfBackendRange(semitones)
        }
        var state = states[projectID] ?? PracticeDSPState()
        state.pitchSemitones = semitones
        states[projectID] = state
    }

    public func setMetronomeEnabled(_ enabled: Bool, projectID: ProjectID) async throws {
        var state = states[projectID] ?? PracticeDSPState()
        state.metronomeEnabled = enabled
        state.scheduleGeneration &+= 1
        states[projectID] = state
    }

    public func scheduleCountIn(clicks: Int, projectID: ProjectID) async throws {
        guard capabilities.countInClickRange.contains(clicks) else {
            throw PracticeDSPConfigurationError.countInOutOfBackendRange(clicks)
        }
        var state = states[projectID] ?? PracticeDSPState()
        state.pendingCountInClicks = clicks
        state.scheduleGeneration &+= 1
        states[projectID] = state
    }

    public func snapshot(projectID: ProjectID) -> PracticeDSPState {
        states[projectID] ?? PracticeDSPState()
    }

    /// Called by the WP3 playback integration after a count-in has been consumed.
    public func clearPendingCountIn(projectID: ProjectID) {
        var state = states[projectID] ?? PracticeDSPState()
        state.pendingCountInClicks = nil
        states[projectID] = state
    }

    /// Explicit invalidation hook for seek/loop/transport discontinuities.
    public func invalidateScheduledClicks(projectID: ProjectID) -> UInt64 {
        var state = states[projectID] ?? PracticeDSPState()
        state.scheduleGeneration &+= 1
        states[projectID] = state
        return state.scheduleGeneration
    }
}
