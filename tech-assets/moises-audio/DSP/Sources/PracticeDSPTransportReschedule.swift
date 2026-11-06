import Foundation

public enum PracticeDSPTransportDiscontinuityReason: String, Codable, Sendable, CaseIterable {
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

public enum PracticeDSPTransportRescheduleError: Error, Equatable, Sendable {
    case poisoned
    case pendingIntentExists
    case noPendingIntent
    case intentMismatch
    case transactionSerialOverflow
    case playbackGenerationRegression(previous: UInt64, requested: UInt64)
    case playbackGenerationNotAdvanced(UInt64)
    case clickGenerationRegression(previous: UInt64, requested: UInt64)
    case clickGenerationNotAdvanced(UInt64)
    case staleBinding
    case recoveryDidNotAdvancePlayback(previous: UInt64, requested: UInt64)
    case recoveryDidNotAdvanceClick(previous: UInt64, requested: UInt64)
}

public struct PracticeDSPTransportInvalidationIntent: Equatable, Sendable {
    public let transactionSerial: UInt64
    public let playbackGeneration: UInt64
    public let reason: PracticeDSPTransportDiscontinuityReason

    public init(transactionSerial: UInt64, playbackGeneration: UInt64, reason: PracticeDSPTransportDiscontinuityReason) {
        self.transactionSerial = transactionSerial
        self.playbackGeneration = playbackGeneration
        self.reason = reason
    }
}

public struct PracticeDSPTransportGenerationBinding: Equatable, Sendable {
    public let playbackGeneration: UInt64
    public let clickGeneration: UInt64
    public let reason: PracticeDSPTransportDiscontinuityReason

    public init(playbackGeneration: UInt64, clickGeneration: UInt64, reason: PracticeDSPTransportDiscontinuityReason) {
        self.playbackGeneration = playbackGeneration
        self.clickGeneration = clickGeneration
        self.reason = reason
    }
}

public struct PracticeDSPTransportRescheduleGate: Equatable, Sendable {
    public private(set) var lastPlaybackGeneration: UInt64?
    public private(set) var lastClickGeneration: UInt64?
    public private(set) var activeBinding: PracticeDSPTransportGenerationBinding?
    public private(set) var pendingIntent: PracticeDSPTransportInvalidationIntent?
    public private(set) var isPoisoned: Bool
    public private(set) var transactionSerial: UInt64

    public init(
        lastPlaybackGeneration: UInt64? = nil,
        lastClickGeneration: UInt64? = nil,
        activeBinding: PracticeDSPTransportGenerationBinding? = nil,
        isPoisoned: Bool = false,
        transactionSerial: UInt64 = 0
    ) {
        self.lastPlaybackGeneration = lastPlaybackGeneration
        self.lastClickGeneration = lastClickGeneration
        self.activeBinding = activeBinding
        self.pendingIntent = nil
        self.isPoisoned = isPoisoned
        self.transactionSerial = transactionSerial
    }

    public mutating func begin(playbackGeneration: UInt64, reason: PracticeDSPTransportDiscontinuityReason) throws -> PracticeDSPTransportInvalidationIntent {
        guard !isPoisoned else { throw PracticeDSPTransportRescheduleError.poisoned }
        guard pendingIntent == nil else { throw PracticeDSPTransportRescheduleError.pendingIntentExists }
        try validatePlaybackAdvance(playbackGeneration)
        let (serial, overflow) = transactionSerial.addingReportingOverflow(1)
        guard !overflow else {
            isPoisoned = true
            activeBinding = nil
            throw PracticeDSPTransportRescheduleError.transactionSerialOverflow
        }
        transactionSerial = serial
        let intent = PracticeDSPTransportInvalidationIntent(transactionSerial: serial, playbackGeneration: playbackGeneration, reason: reason)
        pendingIntent = intent
        activeBinding = nil
        return intent
    }

    @discardableResult
    public mutating func commit(intent: PracticeDSPTransportInvalidationIntent, clickGeneration: UInt64) throws -> PracticeDSPTransportGenerationBinding {
        guard !isPoisoned else { throw PracticeDSPTransportRescheduleError.poisoned }
        guard let pendingIntent else { throw PracticeDSPTransportRescheduleError.noPendingIntent }
        guard pendingIntent == intent else { throw PracticeDSPTransportRescheduleError.intentMismatch }
        try validateClickAdvance(clickGeneration)
        let binding = PracticeDSPTransportGenerationBinding(playbackGeneration: intent.playbackGeneration, clickGeneration: clickGeneration, reason: intent.reason)
        lastPlaybackGeneration = intent.playbackGeneration
        lastClickGeneration = clickGeneration
        activeBinding = binding
        self.pendingIntent = nil
        return binding
    }

    public mutating func fail(intent: PracticeDSPTransportInvalidationIntent) throws {
        try fail(intent: intent, observedClickGeneration: nil)
    }

    /// Records generations that became externally visible before a failed two-phase invalidation.
    /// This prevents recovery from reusing the failed Playback token or an already-advanced click
    /// generation and mirrors AW11's fail-closed partial-advance semantics.
    public mutating func fail(
        intent: PracticeDSPTransportInvalidationIntent,
        observedClickGeneration: UInt64?
    ) throws {
        guard let pendingIntent else { throw PracticeDSPTransportRescheduleError.noPendingIntent }
        guard pendingIntent == intent else { throw PracticeDSPTransportRescheduleError.intentMismatch }
        poisonObservedGenerations(
            playbackGeneration: intent.playbackGeneration,
            clickGeneration: observedClickGeneration
        )
    }

    /// Click-only controls (metronome/count-in) can advance the click generation without a Playback
    /// discontinuity. Once that happens, any combined replacement binding to the older click queue
    /// must be revoked before the click node is touched.
    public mutating func revokeReplacementAuthorityAfterClickOnlyInvalidation(
        clickGeneration: UInt64
    ) throws {
        guard !isPoisoned else { throw PracticeDSPTransportRescheduleError.poisoned }
        guard pendingIntent == nil else { throw PracticeDSPTransportRescheduleError.pendingIntentExists }
        try validateClickAdvance(clickGeneration)
        lastClickGeneration = clickGeneration
        activeBinding = nil
    }

    /// Fail-closed bookkeeping for partial failures and failed recovery attempts. Generations only
    /// move forward; stale values never reduce the recovery floor.
    public mutating func poisonObservedGenerations(
        playbackGeneration: UInt64? = nil,
        clickGeneration: UInt64? = nil
    ) {
        if let playbackGeneration {
            if let previous = lastPlaybackGeneration {
                lastPlaybackGeneration = max(previous, playbackGeneration)
            } else {
                lastPlaybackGeneration = playbackGeneration
            }
        }
        if let clickGeneration {
            if let previous = lastClickGeneration {
                lastClickGeneration = max(previous, clickGeneration)
            } else {
                lastClickGeneration = clickGeneration
            }
        }
        pendingIntent = nil
        activeBinding = nil
        isPoisoned = true
    }

    @discardableResult
    public mutating func recover(
        playbackGeneration: UInt64,
        clickGeneration: UInt64,
        reason: PracticeDSPTransportDiscontinuityReason = .recovery
    ) throws -> PracticeDSPTransportGenerationBinding {
        guard isPoisoned else {
            let intent = try begin(playbackGeneration: playbackGeneration, reason: reason)
            return try commit(intent: intent, clickGeneration: clickGeneration)
        }
        if let previous = lastPlaybackGeneration, playbackGeneration <= previous {
            throw PracticeDSPTransportRescheduleError.recoveryDidNotAdvancePlayback(previous: previous, requested: playbackGeneration)
        }
        if let previous = lastClickGeneration, clickGeneration <= previous {
            throw PracticeDSPTransportRescheduleError.recoveryDidNotAdvanceClick(previous: previous, requested: clickGeneration)
        }
        let binding = PracticeDSPTransportGenerationBinding(playbackGeneration: playbackGeneration, clickGeneration: clickGeneration, reason: reason)
        lastPlaybackGeneration = playbackGeneration
        lastClickGeneration = clickGeneration
        activeBinding = binding
        pendingIntent = nil
        isPoisoned = false
        return binding
    }

    public func validateReplacement(binding: PracticeDSPTransportGenerationBinding) throws {
        guard !isPoisoned, pendingIntent == nil, activeBinding == binding else {
            throw PracticeDSPTransportRescheduleError.staleBinding
        }
    }

    public func acceptsPlaybackGeneration(_ generation: UInt64) -> Bool {
        !isPoisoned && pendingIntent == nil && activeBinding?.playbackGeneration == generation
    }

    public func acceptsClickGeneration(_ generation: UInt64) -> Bool {
        !isPoisoned && pendingIntent == nil && activeBinding?.clickGeneration == generation
    }

    private func validatePlaybackAdvance(_ requested: UInt64) throws {
        guard let previous = lastPlaybackGeneration else { return }
        if requested < previous {
            throw PracticeDSPTransportRescheduleError.playbackGenerationRegression(previous: previous, requested: requested)
        }
        guard requested > previous else {
            throw PracticeDSPTransportRescheduleError.playbackGenerationNotAdvanced(requested)
        }
    }

    private func validateClickAdvance(_ requested: UInt64) throws {
        guard let previous = lastClickGeneration else { return }
        if requested < previous {
            throw PracticeDSPTransportRescheduleError.clickGenerationRegression(previous: previous, requested: requested)
        }
        guard requested > previous else {
            throw PracticeDSPTransportRescheduleError.clickGenerationNotAdvanced(requested)
        }
    }
}

#if canImport(AVFAudio)
public extension AppleSampleAccurateClickExecutor {
    func invalidateForTransport(
        clickGeneration: UInt64
    ) throws {
        try invalidateSchedule(to: clickGeneration)
    }
}
#endif
