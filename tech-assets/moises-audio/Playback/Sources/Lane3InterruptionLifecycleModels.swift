import Foundation

public enum Lane3InterruptionLifecyclePhase: String, Codable, Sendable {
    case idle
    case beginning
    case active
    case ending
    case endedRecoveryRequired
    case resuming
    case poisoned
}

public enum Lane3InterruptionGateRejectionReason: String, Codable, Sendable {
    case interruptionActive
    case lifecycleTransitionInFlight
    case noActiveInterruption
    case duplicateInterruptionBegan
    case recoveryRequiredAfterInterruptionEnd
    case episodeSerialOverflow
    case lifecycleRevisionOverflow
    case intentOrderSerialOverflow
}

public struct Lane3InterruptionLifecycleSnapshot: Equatable, Sendable {
    public let phase: Lane3InterruptionLifecyclePhase
    public let episodeSerial: UInt64
    public let lifecycleRevision: UInt64
    public let commandedPlaying: Bool
    public let resumeArmed: Bool
    public let pendingEndShouldResume: Bool
    public let lastBeginPlaybackGeneration: UInt64?
    public let lastEndPlaybackGeneration: UInt64?
    public let authorityRecoveryBlocked: Bool
}

public enum Lane3InterruptionGuardedOutcome: Equatable, Sendable {
    case transport(Lane3UnifiedTransportOutcome)
    case rejectedBeforeTransport(
        kind: Lane3UnifiedTransportKind,
        reason: Lane3InterruptionGateRejectionReason
    )
    case resumeSuppressedWithoutToken(episodeSerial: UInt64)
}

public struct Lane3InterruptionBeginReceipt: Equatable, Sendable {
    public let episodeSerial: UInt64
    public let lifecycleRevision: UInt64
    public let resumeArmed: Bool
    public let preBoundaryRecovery: Lane3UnifiedTransportOutcome?
    public let boundaryOutcome: Lane3UnifiedTransportOutcome?
    public let boundarySafe: Bool
    public let supersededByNewerLifecycleEvent: Bool
}

public enum Lane3InterruptionBeginResult: Equatable, Sendable {
    case began(Lane3InterruptionBeginReceipt)
    case rejected(reason: Lane3InterruptionGateRejectionReason)
}

public struct Lane3InterruptionEndReceipt: Equatable, Sendable {
    public let episodeSerial: UInt64
    public let lifecycleRevision: UInt64
    public let osShouldResume: Bool
    public let resumeWasArmed: Bool
    public let preBoundaryRecovery: Lane3UnifiedTransportOutcome?
    public let boundaryOutcome: Lane3UnifiedTransportOutcome?
    public let boundarySafe: Bool
    public let resumeOutcome: Lane3UnifiedTransportOutcome?
    public let compensatingPauseOutcome: Lane3UnifiedTransportOutcome?
    public let resumedPlayback: Bool
    public let supersededByNewerLifecycleEvent: Bool
    public let recoveryRequired: Bool
}

public enum Lane3InterruptionEndResult: Equatable, Sendable {
    case ended(Lane3InterruptionEndReceipt)
    case rejected(reason: Lane3InterruptionGateRejectionReason)
}
