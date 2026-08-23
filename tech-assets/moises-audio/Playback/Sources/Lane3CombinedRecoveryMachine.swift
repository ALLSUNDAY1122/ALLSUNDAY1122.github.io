import Foundation

public struct Lane3CombinedRecoveryMachine: Sendable {
    public private(set) var state: Lane3CombinedRecoveryState
    public private(set) var counters = Lane3CombinedRecoveryCounters()

    public init(stemCount: Int, playbackGeneration: UInt64 = 0, clickGeneration: UInt64 = 0) throws {
        self.state = try Lane3CombinedRecoveryState(
            stemCount: stemCount,
            playbackGeneration: playbackGeneration,
            clickGeneration: clickGeneration
        )
    }

    public mutating func apply(_ operation: Lane3CombinedRecoveryOperation) throws {
        switch operation {
        case .staleCompletion(let generation):
            counters.staleCompletionAttempts += 1
            if !acceptsCompletion(playbackGeneration: generation) {
                counters.staleCompletionRejected += 1
                return
            }
            counters.applied += 1
            return

        case .staleReplacement(let binding):
            counters.staleReplacementAttempts += 1
            if !acceptsReplacement(binding: binding) {
                counters.staleReplacementRejected += 1
                return
            }
            counters.applied += 1
            return

        case .recover(let resume):
            try recover(resume: resume)
            counters.applied += 1
            return

        default:
            break
        }

        guard !state.poisoned else {
            counters.rejected += 1
            throw Lane3CombinedRecoveryError.poisoned
        }

        let before = state
        do {
            switch operation {
            case .setGain(let stemIndex, let gain):
                guard state.gains.indices.contains(stemIndex) else {
                    throw Lane3CombinedRecoveryError.invalidStemIndex(stemIndex)
                }
                guard gain.isFinite, (0...1).contains(gain) else {
                    throw Lane3CombinedRecoveryError.invalidGain(gain)
                }
                state.gains[stemIndex] = gain

            case .setPitch(let semitones):
                guard semitones.isFinite, (-24...24).contains(semitones) else {
                    throw Lane3CombinedRecoveryError.invalidPitchSemitones(semitones)
                }
                state.pitchSemitones = semitones

            case .setTempo(let ratio):
                guard ratio.isFinite, (0.03125...32).contains(ratio) else {
                    throw Lane3CombinedRecoveryError.invalidTempoRatio(ratio)
                }
                state.tempoRatio = ratio
                try commitTransportDiscontinuity(.tempoChange)

            case .setMetronome(let enabled):
                state.metronomeEnabled = enabled
                try invalidateClickScheduleOnly()

            case .scheduleCountIn(let clicks):
                guard (1...32).contains(clicks) else {
                    throw Lane3CombinedRecoveryError.invalidCountInClicks(clicks)
                }
                state.pendingCountInClicks = clicks
                try invalidateClickScheduleOnly()

            case .consumeCountIn:
                state.pendingCountInClicks = nil

            case .seek(let position):
                guard position.isFinite, position >= 0 else {
                    throw Lane3CombinedRecoveryError.invalidSeekPosition(position)
                }
                state.positionSeconds = position
                try commitTransportDiscontinuity(.seek)

            case .setLoop(let start, let end):
                guard start.isFinite, end.isFinite, start >= 0, end > start else {
                    throw Lane3CombinedRecoveryError.invalidLoop(start: start, end: end)
                }
                state.loopStartSeconds = start
                state.loopEndSeconds = end
                if state.positionSeconds < start || state.positionSeconds >= end {
                    state.positionSeconds = start
                }
                try commitTransportDiscontinuity(.loopChange)

            case .clearLoop:
                state.loopStartSeconds = nil
                state.loopEndSeconds = nil
                try commitTransportDiscontinuity(.loopChange)

            case .play:
                guard !state.interrupted else { throw Lane3CombinedRecoveryError.playWhileInterrupted }
                state.playing = true
                try commitTransportDiscontinuity(.play)

            case .pause:
                state.playing = false
                try commitTransportDiscontinuity(.pause)

            case .interruptionBegan:
                state.interrupted = true
                state.playing = false
                try commitTransportDiscontinuity(.interruptionBegan)

            case .interruptionEnded(let resume):
                state.interrupted = false
                state.playing = resume
                try commitTransportDiscontinuity(.interruptionEnded)

            case .forceHalfInvalidationFailure:
                try beginHalfFailure()

            case .recover, .staleCompletion, .staleReplacement:
                break
            }
            try validateInvariants()
            counters.applied += 1
        } catch {
            if case Lane3CombinedRecoveryError.generationOverflow = error {
                counters.rejected += 1
                throw error
            }
            if case .forceHalfInvalidationFailure = operation {
                try validateInvariants()
                counters.applied += 1
                return
            }
            state = before
            counters.rejected += 1
            throw error
        }
    }

    public func acceptsCompletion(playbackGeneration: UInt64) -> Bool {
        !state.poisoned && playbackGeneration == state.playbackGeneration
    }

    public func acceptsReplacement(binding: Lane3CombinedRecoveryBinding?) -> Bool {
        guard !state.poisoned, let binding, let active = state.binding else { return false }
        return binding == active
            && binding.playbackGeneration == state.playbackGeneration
            && binding.clickGeneration == state.clickGeneration
    }

    public func validateInvariants() throws {
        guard state.gains.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw Lane3CombinedRecoveryError.invalidGain(.nan)
        }
        guard state.tempoRatio.isFinite, (0.03125...32).contains(state.tempoRatio) else {
            throw Lane3CombinedRecoveryError.invalidTempoRatio(state.tempoRatio)
        }
        guard state.pitchSemitones.isFinite, (-24...24).contains(state.pitchSemitones) else {
            throw Lane3CombinedRecoveryError.invalidPitchSemitones(state.pitchSemitones)
        }
        if let clicks = state.pendingCountInClicks, !(1...32).contains(clicks) {
            throw Lane3CombinedRecoveryError.invalidCountInClicks(clicks)
        }
        if let start = state.loopStartSeconds, let end = state.loopEndSeconds {
            guard start.isFinite, end.isFinite, start >= 0, end > start else {
                throw Lane3CombinedRecoveryError.invalidLoop(start: start, end: end)
            }
        } else if state.loopStartSeconds != nil || state.loopEndSeconds != nil {
            throw Lane3CombinedRecoveryError.invalidLoop(
                start: state.loopStartSeconds ?? .nan,
                end: state.loopEndSeconds ?? .nan
            )
        }
        if state.interrupted && state.playing {
            throw Lane3CombinedRecoveryError.playWhileInterrupted
        }
        if state.poisoned {
            guard state.binding == nil else { throw Lane3CombinedRecoveryError.poisoned }
        } else if let binding = state.binding {
            guard binding.playbackGeneration == state.playbackGeneration,
                  binding.clickGeneration == state.clickGeneration else {
                throw Lane3CombinedRecoveryError.poisoned
            }
        }
    }

    private mutating func nextPlaybackGeneration() throws -> UInt64 {
        let (next, overflow) = state.playbackGeneration.addingReportingOverflow(1)
        guard !overflow else {
            state.poisoned = true
            state.binding = nil
            throw Lane3CombinedRecoveryError.generationOverflow
        }
        state.playbackGeneration = next
        return next
    }

    private mutating func nextClickGeneration() throws -> UInt64 {
        let (next, overflow) = state.clickGeneration.addingReportingOverflow(1)
        guard !overflow else {
            state.poisoned = true
            state.binding = nil
            throw Lane3CombinedRecoveryError.generationOverflow
        }
        state.clickGeneration = next
        return next
    }

    private mutating func commitTransportDiscontinuity(_ reason: Lane3CombinedRecoveryDiscontinuityReason) throws {
        let playback = try nextPlaybackGeneration()
        state.binding = nil
        let click = try nextClickGeneration()
        state.binding = Lane3CombinedRecoveryBinding(
            playbackGeneration: playback,
            clickGeneration: click,
            reason: reason
        )
        counters.transportInvalidations += 1
    }

    private mutating func invalidateClickScheduleOnly() throws {
        _ = try nextClickGeneration()
        state.binding = nil
        counters.clickOnlyInvalidations += 1
    }

    private mutating func beginHalfFailure() throws {
        _ = try nextPlaybackGeneration()
        state.binding = nil
        state.poisoned = true
        counters.forcedHalfFailures += 1
    }

    private mutating func recover(resume: Bool) throws {
        let playback = try nextPlaybackGeneration()
        let click = try nextClickGeneration()
        state.interrupted = false
        state.playing = resume
        state.poisoned = false
        state.binding = Lane3CombinedRecoveryBinding(
            playbackGeneration: playback,
            clickGeneration: click,
            reason: .recovery
        )
        counters.recoveries += 1
        counters.transportInvalidations += 1
        try validateInvariants()
    }
}
