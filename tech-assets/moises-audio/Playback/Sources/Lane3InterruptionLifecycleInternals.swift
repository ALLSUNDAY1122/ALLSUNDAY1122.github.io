import Foundation

extension Lane3InterruptionLifecycleGate {
    func blocked(kind: Lane3UnifiedTransportKind) -> Lane3InterruptionGuardedOutcome {
        let reason: Lane3InterruptionGateRejectionReason
        switch phase {
        case .endedRecoveryRequired: reason = .recoveryRequiredAfterInterruptionEnd
        case .active: reason = .interruptionActive
        case .poisoned: reason = .lifecycleRevisionOverflow
        default: reason = .lifecycleTransitionInFlight
        }
        return .rejectedBeforeTransport(kind: kind, reason: reason)
    }

    func allocateIntentOrderSerial() -> UInt64? {
        let (next, overflow) = intentOrderSerial.addingReportingOverflow(1)
        guard !overflow else { return nil }
        intentOrderSerial = next
        return next
    }

    func advanceLifecycleRevision() -> UInt64? {
        let (next, overflow) = lifecycleRevision.addingReportingOverflow(1)
        guard !overflow else { return nil }
        lifecycleRevision = next
        return next
    }

    func beginPlayingIntent(desiredPlaying: Bool) -> UInt64? {
        guard let serial = allocateIntentOrderSerial() else { return nil }
        pendingPlayingIntents[serial] = desiredPlaying
        return serial
    }

    func completePlayingIntent(
        serial: UInt64,
        desiredPlaying: Bool,
        outcome: Lane3UnifiedTransportOutcome
    ) {
        pendingPlayingIntents[serial] = nil
        if Self.executed(outcome) { commandedPlaying = desiredPlaying }
        resumeSatisfiedPlayingIntentWaiters()
    }

    func waitForPlayingIntents(before serial: UInt64) async {
        while pendingPlayingIntents.keys.contains(where: { $0 < serial }) {
            await withCheckedContinuation { continuation in
                playingIntentWaiters.append(PlayingIntentWaiter(
                    beforeSerial: serial,
                    continuation: continuation
                ))
            }
        }
    }

    func resumeSatisfiedPlayingIntentWaiters() {
        var retained: [PlayingIntentWaiter] = []
        for waiter in playingIntentWaiters {
            if pendingPlayingIntents.keys.contains(where: { $0 < waiter.beforeSerial }) {
                retained.append(waiter)
            } else {
                waiter.continuation.resume()
            }
        }
        playingIntentWaiters = retained
    }

    func recoverAuthorityIfNeeded() async -> Lane3UnifiedTransportOutcome? {
        let snapshot = await authority.snapshot()
        guard snapshot.recoveryBlocked else { return nil }
        return await authority.submitRecovery()
    }

    static func recoveryAttemptFailed(_ outcome: Lane3UnifiedTransportOutcome?) -> Bool {
        guard let outcome else { return false }
        return !executed(outcome)
    }

    static func executed(_ outcome: Lane3UnifiedTransportOutcome) -> Bool {
        if case .executed = outcome { return true }
        return false
    }

    static func boundarySafe(_ outcome: Lane3UnifiedTransportOutcome) -> Bool {
        switch outcome {
        case .executed:
            return true
        case let .failedAfterDispatch(receipt):
            return receipt.automaticRecovery.succeeded
        default:
            return false
        }
    }

    static func bestSafeGeneration(_ outcome: Lane3UnifiedTransportOutcome) -> UInt64? {
        switch outcome {
        case let .executed(receipt):
            return receipt.playbackGeneration
        case let .failedAfterDispatch(receipt):
            return receipt.automaticRecovery.succeeded
                ? receipt.automaticRecovery.playbackGeneration
                : receipt.playbackGeneration
        default:
            return nil
        }
    }
}
