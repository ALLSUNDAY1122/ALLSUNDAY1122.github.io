import Foundation

public protocol PracticeDSPClickScheduleInvalidating: Sendable {
    func invalidateSchedule(to generation: UInt64) throws
}

public enum PracticeDSPGenerationMutationKind: String, Codable, Sendable {
    case transportDiscontinuity
    case tempoChange
    case metronomeChange
    case countInSchedule
    case recovery
}

public enum PracticeDSPGenerationCoordinatorError: Error, Equatable, Sendable {
    case operationInFlight
    case operationSerialOverflow
    case operationCancelled
    case operationSuperseded
    case unsupportedPlaybackReason(String)
    case expectedTempoChangeToken(actual: String)
    case expectedRecoveryToken(actual: String)
    case coordinatorPoisoned
    case tempoChangeRequiresTempoMutation
    case recoveryRequiresRecoveryPath
    case clickGenerationDidNotAdvance(previous: UInt64, observed: UInt64)
    case dspMutationFailed(String)
    case clickInvalidationFailed(String)
    case recoveryFailed(String)
}

public struct PracticeDSPGenerationCoordinatorReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let operationSerial: UInt64
    public let mutationKind: PracticeDSPGenerationMutationKind
    public let playbackGeneration: UInt64?
    public let clickGeneration: UInt64
    public let reason: String?
    public let replacementBindingActive: Bool
    public let parityPromotionAllowed: Bool
}

public struct PracticeDSPGenerationCoordinatorSnapshot: Equatable, Sendable {
    public let dspState: PracticeDSPState
    public let activeBinding: PracticeDSPTransportGenerationBinding?
    public let isPoisoned: Bool
    public let operationSerial: UInt64
}

/// Lightweight gate-only snapshot that remains observable while this actor is re-entered at an
/// await inside a production mutation. It intentionally avoids awaiting the controller so HQ/tests
/// can prove that no overlapping operation acquires replacement authority mid-transaction.
public struct PracticeDSPGenerationAuthoritySnapshot: Equatable, Sendable {
    public let activeBinding: PracticeDSPTransportGenerationBinding?
    public let pendingPlaybackGeneration: UInt64?
    public let pendingReason: String?
    public let lastPlaybackGeneration: UInt64?
    public let lastClickGeneration: UInt64?
    public let isPoisoned: Bool
    public let operationSerial: UInt64
    public let operationInFlight: Bool
}

/// Project-scoped production coordinator for the generation rules shared by Playback transport and
/// PracticeDSP click scheduling. Playback must advance its own token first. This actor then advances
/// the DSP/click generation, flushes queued clicks, and only after both steps succeed publishes a
/// replacement binding. Any half-failure clears replacement authority and poisons the coordinator
/// until a newer Playback recovery token and a newer click generation are proven.
public actor PracticeDSPGenerationCoordinator {
    private let projectID: ProjectID
    private let controller: PracticeDSPProductionController
    private let clickInvalidator: any PracticeDSPClickScheduleInvalidating
    private var transportGate: PracticeDSPTransportRescheduleGate
    private var operationSerial: UInt64
    private var operationInFlight = false

    public init(
        projectID: ProjectID,
        controller: PracticeDSPProductionController,
        clickInvalidator: any PracticeDSPClickScheduleInvalidating,
        initialTransportGate: PracticeDSPTransportRescheduleGate = PracticeDSPTransportRescheduleGate(),
        initialOperationSerial: UInt64 = 0
    ) {
        self.projectID = projectID
        self.controller = controller
        self.clickInvalidator = clickInvalidator
        self.transportGate = initialTransportGate
        self.operationSerial = initialOperationSerial
    }

    @discardableResult
    public func bindTransportDiscontinuity(
        playbackToken: PlaybackTransportRescheduleToken
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        let serial = try beginPlaybackOperation(playbackToken: playbackToken)
        defer { operationInFlight = false }
        try rejectNormalOperationIfPoisoned(playbackToken: playbackToken)
        try rejectCancelledPlaybackOperation(playbackToken: playbackToken)
        guard playbackToken.reason != .tempoChange else {
            poisonIfPlaybackTokenAdvanced(playbackToken)
            throw PracticeDSPGenerationCoordinatorError.tempoChangeRequiresTempoMutation
        }
        guard playbackToken.reason != .recovery else {
            poisonIfPlaybackTokenAdvanced(playbackToken)
            throw PracticeDSPGenerationCoordinatorError.recoveryRequiresRecoveryPath
        }
        let reason = try dspReason(for: playbackToken.reason)
        let intent = try transportGate.begin(
            playbackGeneration: playbackToken.generation,
            reason: reason
        )
        try cancelPendingIntentIfNeeded(intent: intent, observedClickGeneration: nil)
        var observedClickGeneration: UInt64?
        do {
            let clickGeneration = try await controller.invalidateScheduledClicks(projectID: projectID)
            observedClickGeneration = clickGeneration
            try ensurePendingIntentCurrent(
                intent: intent,
                observedClickGeneration: clickGeneration
            )
            try cancelPendingIntentIfNeeded(
                intent: intent,
                observedClickGeneration: clickGeneration
            )
            do {
                try clickInvalidator.invalidateSchedule(to: clickGeneration)
            } catch {
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(String(describing: error))
            }
            try ensurePendingIntentCurrent(
                intent: intent,
                observedClickGeneration: clickGeneration
            )
            // Commit is the point of no return. Cancellation observed before this line leaves no
            // replacement binding and records every externally advanced generation as a floor.
            try cancelPendingIntentIfNeeded(
                intent: intent,
                observedClickGeneration: clickGeneration
            )
            let binding = try transportGate.commit(intent: intent, clickGeneration: clickGeneration)
            return receipt(
                serial: serial,
                kind: .transportDiscontinuity,
                binding: binding,
                clickGeneration: clickGeneration
            )
        } catch {
            try? transportGate.fail(intent: intent, observedClickGeneration: observedClickGeneration)
            throw wrappedMutationError(error)
        }
    }

    @discardableResult
    public func applyTempoRatio(
        _ ratio: Double,
        playbackToken: PlaybackTransportRescheduleToken
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        let serial = try beginPlaybackOperation(playbackToken: playbackToken)
        defer { operationInFlight = false }
        try rejectNormalOperationIfPoisoned(playbackToken: playbackToken)
        try rejectCancelledPlaybackOperation(playbackToken: playbackToken)
        guard playbackToken.reason == .tempoChange else {
            poisonIfPlaybackTokenAdvanced(playbackToken)
            throw PracticeDSPGenerationCoordinatorError.expectedTempoChangeToken(
                actual: playbackToken.reason.rawValue
            )
        }
        let intent = try transportGate.begin(
            playbackGeneration: playbackToken.generation,
            reason: .tempoChange
        )
        try cancelPendingIntentIfNeeded(intent: intent, observedClickGeneration: nil)
        var observedClickGeneration: UInt64?
        do {
            try await controller.setTempoRatio(ratio, projectID: projectID)
            let state = try await controller.snapshot(projectID: projectID)
            observedClickGeneration = state.scheduleGeneration
            try ensurePendingIntentCurrent(
                intent: intent,
                observedClickGeneration: state.scheduleGeneration
            )
            try cancelPendingIntentIfNeeded(
                intent: intent,
                observedClickGeneration: state.scheduleGeneration
            )
            do {
                try clickInvalidator.invalidateSchedule(to: state.scheduleGeneration)
            } catch {
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(String(describing: error))
            }
            try ensurePendingIntentCurrent(
                intent: intent,
                observedClickGeneration: state.scheduleGeneration
            )
            try cancelPendingIntentIfNeeded(
                intent: intent,
                observedClickGeneration: state.scheduleGeneration
            )
            let binding = try transportGate.commit(
                intent: intent,
                clickGeneration: state.scheduleGeneration
            )
            return receipt(
                serial: serial,
                kind: .tempoChange,
                binding: binding,
                clickGeneration: state.scheduleGeneration
            )
        } catch {
            if observedClickGeneration == nil,
               let state = try? await controller.snapshot(projectID: projectID) {
                observedClickGeneration = state.scheduleGeneration
            }
            try? transportGate.fail(intent: intent, observedClickGeneration: observedClickGeneration)
            throw wrappedMutationError(error)
        }
    }

    @discardableResult
    public func setMetronomeEnabled(
        _ enabled: Bool
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        try await performClickOnlyMutation(kind: .metronomeChange) {
            try await controller.setMetronomeEnabled(enabled, projectID: projectID)
        }
    }

    @discardableResult
    public func scheduleCountIn(
        clicks: Int
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        try await performClickOnlyMutation(kind: .countInSchedule) {
            try await controller.scheduleCountIn(clicks: clicks, projectID: projectID)
        }
    }

    @discardableResult
    public func recover(
        playbackToken: PlaybackTransportRescheduleToken
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        let serial = try beginPlaybackOperation(playbackToken: playbackToken)
        defer { operationInFlight = false }
        guard playbackToken.reason == .recovery else {
            poisonIfPlaybackTokenAdvanced(playbackToken)
            throw PracticeDSPGenerationCoordinatorError.expectedRecoveryToken(
                actual: playbackToken.reason.rawValue
            )
        }
        try poisonRecoveryIfCancelled(
            playbackToken: playbackToken,
            observedClickGeneration: nil
        )
        var observedClickGeneration: UInt64?
        do {
            try await controller.recoverBackend(projectID: projectID)
            try ensureRecoveryNotSuperseded(
                playbackToken: playbackToken,
                observedClickGeneration: nil
            )
            try poisonRecoveryIfCancelled(
                playbackToken: playbackToken,
                observedClickGeneration: nil
            )
            let clickGeneration = try await controller.invalidateScheduledClicks(projectID: projectID)
            observedClickGeneration = clickGeneration
            try ensureRecoveryNotSuperseded(
                playbackToken: playbackToken,
                observedClickGeneration: clickGeneration
            )
            try poisonRecoveryIfCancelled(
                playbackToken: playbackToken,
                observedClickGeneration: clickGeneration
            )
            do {
                try clickInvalidator.invalidateSchedule(to: clickGeneration)
            } catch {
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(String(describing: error))
            }
            try ensureRecoveryNotSuperseded(
                playbackToken: playbackToken,
                observedClickGeneration: clickGeneration
            )
            try poisonRecoveryIfCancelled(
                playbackToken: playbackToken,
                observedClickGeneration: clickGeneration
            )
            let binding = try transportGate.recover(
                playbackGeneration: playbackToken.generation,
                clickGeneration: clickGeneration,
                reason: .recovery
            )
            return receipt(
                serial: serial,
                kind: .recovery,
                binding: binding,
                clickGeneration: clickGeneration
            )
        } catch {
            transportGate.poisonObservedGenerations(
                playbackGeneration: playbackToken.generation,
                clickGeneration: observedClickGeneration
            )
            if let coordinatorError = error as? PracticeDSPGenerationCoordinatorError {
                throw coordinatorError
            }
            if error is CancellationError {
                throw PracticeDSPGenerationCoordinatorError.operationCancelled
            }
            throw PracticeDSPGenerationCoordinatorError.recoveryFailed(String(describing: error))
        }
    }

    public func validateReplacement(
        binding: PracticeDSPTransportGenerationBinding
    ) throws {
        try transportGate.validateReplacement(binding: binding)
    }

    public func snapshot() async throws -> PracticeDSPGenerationCoordinatorSnapshot {
        let state = try await controller.snapshot(projectID: projectID)
        return PracticeDSPGenerationCoordinatorSnapshot(
            dspState: state,
            activeBinding: transportGate.activeBinding,
            isPoisoned: transportGate.isPoisoned,
            operationSerial: operationSerial
        )
    }

    public func authoritySnapshot() -> PracticeDSPGenerationAuthoritySnapshot {
        PracticeDSPGenerationAuthoritySnapshot(
            activeBinding: transportGate.activeBinding,
            pendingPlaybackGeneration: transportGate.pendingIntent?.playbackGeneration,
            pendingReason: transportGate.pendingIntent?.reason.rawValue,
            lastPlaybackGeneration: transportGate.lastPlaybackGeneration,
            lastClickGeneration: transportGate.lastClickGeneration,
            isPoisoned: transportGate.isPoisoned,
            operationSerial: operationSerial,
            operationInFlight: operationInFlight
        )
    }

    private func performClickOnlyMutation(
        kind: PracticeDSPGenerationMutationKind,
        mutation: () async throws -> Void
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        let serial = try beginOperation()
        defer { operationInFlight = false }
        guard !transportGate.isPoisoned else {
            throw PracticeDSPGenerationCoordinatorError.coordinatorPoisoned
        }
        try rejectClickOnlyIfCancelled()
        let before = try await controller.snapshot(projectID: projectID)
        try rejectClickOnlyIfSuperseded(observedClickGeneration: nil)
        try rejectClickOnlyIfCancelled()
        do {
            try await mutation()
            let after = try await controller.snapshot(projectID: projectID)
            guard after.scheduleGeneration > before.scheduleGeneration else {
                transportGate.poisonObservedGenerations(
                    clickGeneration: after.scheduleGeneration
                )
                throw PracticeDSPGenerationCoordinatorError.clickGenerationDidNotAdvance(
                    previous: before.scheduleGeneration,
                    observed: after.scheduleGeneration
                )
            }
            try rejectClickOnlyIfSuperseded(
                observedClickGeneration: after.scheduleGeneration
            )
            try poisonClickOnlyIfCancelled(clickGeneration: after.scheduleGeneration)

            // Revoke the old transport+click replacement authority before touching the click node.
            // If click-node invalidation fails or cancellation wins before the node is touched, no
            // stale combined binding can become current again.
            try transportGate.revokeReplacementAuthorityAfterClickOnlyInvalidation(
                clickGeneration: after.scheduleGeneration
            )
            try poisonClickOnlyIfCancelled(clickGeneration: after.scheduleGeneration)
            do {
                try clickInvalidator.invalidateSchedule(to: after.scheduleGeneration)
            } catch {
                transportGate.poisonObservedGenerations(
                    clickGeneration: after.scheduleGeneration
                )
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(
                    String(describing: error)
                )
            }
            // Successful click invalidation is this mutation's commit point. Cancellation that
            // arrives after it must not disguise an already-complete control mutation as aborted.
            return PracticeDSPGenerationCoordinatorReceipt(
                schemaVersion: 1,
                evidenceScope: "LANE3_PRODUCTION_COMBINED_GENERATION_NON_PARITY",
                operationSerial: serial,
                mutationKind: kind,
                playbackGeneration: nil,
                clickGeneration: after.scheduleGeneration,
                reason: nil,
                replacementBindingActive: false,
                parityPromotionAllowed: false
            )
        } catch {
            if error is CancellationError {
                throw PracticeDSPGenerationCoordinatorError.operationCancelled
            }
            if (try? await controller.requiresBackendResynchronization(projectID: projectID)) == true {
                transportGate.poisonObservedGenerations()
            }
            if let coordinatorError = error as? PracticeDSPGenerationCoordinatorError {
                throw coordinatorError
            }
            throw PracticeDSPGenerationCoordinatorError.dspMutationFailed(
                String(describing: error)
            )
        }
    }

    /// Token-bearing entry points cannot simply reject an overlapping call. Playback has already
    /// advanced before coordinator dispatch, so a genuinely newer overlapping token supersedes the
    /// in-flight authority and must poison the gate. The first task will observe that poison after
    /// its await and fail instead of committing a stale replacement binding.
    private func beginPlaybackOperation(
        playbackToken: PlaybackTransportRescheduleToken
    ) throws -> UInt64 {
        guard !operationInFlight else {
            poisonIfPlaybackTokenAdvanced(playbackToken)
            throw PracticeDSPGenerationCoordinatorError.operationInFlight
        }
        do {
            return try beginOperation()
        } catch {
            if let coordinatorError = error as? PracticeDSPGenerationCoordinatorError,
               coordinatorError == .operationSerialOverflow {
                transportGate.poisonObservedGenerations(
                    playbackGeneration: playbackToken.generation
                )
            }
            throw error
        }
    }

    private func beginOperation() throws -> UInt64 {
        guard !operationInFlight else {
            throw PracticeDSPGenerationCoordinatorError.operationInFlight
        }
        let (next, overflow) = operationSerial.addingReportingOverflow(1)
        guard !overflow else {
            transportGate.poisonObservedGenerations()
            throw PracticeDSPGenerationCoordinatorError.operationSerialOverflow
        }
        operationSerial = next
        operationInFlight = true
        return next
    }

    /// Playback advances its fence before calling this coordinator. If a newer token reaches a
    /// poisoned coordinator, that generation has already become externally observable and must be
    /// retained as a recovery floor even though the requested normal operation cannot proceed.
    private func rejectNormalOperationIfPoisoned(
        playbackToken: PlaybackTransportRescheduleToken
    ) throws {
        guard transportGate.isPoisoned else { return }
        transportGate.poisonObservedGenerations(
            playbackGeneration: playbackToken.generation
        )
        throw PracticeDSPGenerationCoordinatorError.coordinatorPoisoned
    }

    /// A token sent through the wrong coordinator entry point still represents an already-advanced
    /// Playback fence. Compare it with both the committed floor and any pending in-flight token so a
    /// stale/replayed token cannot poison a newer transaction, while a genuinely newer token always
    /// revokes the old authority.
    private func poisonIfPlaybackTokenAdvanced(
        _ playbackToken: PlaybackTransportRescheduleToken
    ) {
        var latestObserved = transportGate.lastPlaybackGeneration
        if let pending = transportGate.pendingIntent?.playbackGeneration {
            if let current = latestObserved {
                latestObserved = max(current, pending)
            } else {
                latestObserved = pending
            }
        }
        if let latestObserved {
            guard playbackToken.generation > latestObserved else { return }
        }
        transportGate.poisonObservedGenerations(
            playbackGeneration: playbackToken.generation
        )
    }

    /// Cancellation before a transport/tempo commit cannot be treated as if Playback never moved:
    /// the token generation is already externally visible. Preserve it as a recovery floor and
    /// revoke any older combined authority. Stale/replayed cancelled tokens leave current authority
    /// intact because they do not represent a newly advanced Playback fence.
    private func rejectCancelledPlaybackOperation(
        playbackToken: PlaybackTransportRescheduleToken
    ) throws {
        guard Task.isCancelled else { return }
        poisonIfPlaybackTokenAdvanced(playbackToken)
        throw PracticeDSPGenerationCoordinatorError.operationCancelled
    }

    private func ensurePendingIntentCurrent(
        intent: PracticeDSPTransportInvalidationIntent,
        observedClickGeneration: UInt64?
    ) throws {
        guard !transportGate.isPoisoned,
              transportGate.pendingIntent == intent else {
            transportGate.poisonObservedGenerations(
                playbackGeneration: intent.playbackGeneration,
                clickGeneration: observedClickGeneration
            )
            throw PracticeDSPGenerationCoordinatorError.operationSuperseded
        }
    }

    private func cancelPendingIntentIfNeeded(
        intent: PracticeDSPTransportInvalidationIntent,
        observedClickGeneration: UInt64?
    ) throws {
        guard Task.isCancelled else { return }
        try? transportGate.fail(
            intent: intent,
            observedClickGeneration: observedClickGeneration
        )
        throw PracticeDSPGenerationCoordinatorError.operationCancelled
    }

    /// Click-only work has no newly advanced Playback token. Before its controller mutation starts,
    /// cancellation can therefore leave the current binding intact. Once the click generation has
    /// advanced, cancellation must poison that generation and revoke replacement authority because
    /// the old click queue may no longer match logical state.
    private func rejectClickOnlyIfCancelled() throws {
        guard !Task.isCancelled else {
            throw PracticeDSPGenerationCoordinatorError.operationCancelled
        }
    }

    /// A newer overlapping Playback token may poison this gate while click-only work is suspended in
    /// its controller actor. The click-only task must then stop and, if its generation already moved,
    /// retain that click generation as a recovery floor rather than trying to revoke/replace against
    /// the superseding Playback state.
    private func rejectClickOnlyIfSuperseded(
        observedClickGeneration: UInt64?
    ) throws {
        guard transportGate.isPoisoned else { return }
        transportGate.poisonObservedGenerations(
            clickGeneration: observedClickGeneration
        )
        throw PracticeDSPGenerationCoordinatorError.operationSuperseded
    }

    private func poisonClickOnlyIfCancelled(
        clickGeneration: UInt64
    ) throws {
        guard Task.isCancelled else { return }
        transportGate.poisonObservedGenerations(
            clickGeneration: clickGeneration
        )
        throw PracticeDSPGenerationCoordinatorError.operationCancelled
    }

    private func ensureRecoveryNotSuperseded(
        playbackToken: PlaybackTransportRescheduleToken,
        observedClickGeneration: UInt64?
    ) throws {
        if let lastPlaybackGeneration = transportGate.lastPlaybackGeneration,
           lastPlaybackGeneration > playbackToken.generation {
            transportGate.poisonObservedGenerations(
                playbackGeneration: playbackToken.generation,
                clickGeneration: observedClickGeneration
            )
            throw PracticeDSPGenerationCoordinatorError.operationSuperseded
        }
    }

    private func poisonRecoveryIfCancelled(
        playbackToken: PlaybackTransportRescheduleToken,
        observedClickGeneration: UInt64?
    ) throws {
        guard Task.isCancelled else { return }
        transportGate.poisonObservedGenerations(
            playbackGeneration: playbackToken.generation,
            clickGeneration: observedClickGeneration
        )
        throw PracticeDSPGenerationCoordinatorError.operationCancelled
    }

    private func dspReason(
        for reason: PlaybackTransportDiscontinuityReason
    ) throws -> PracticeDSPTransportDiscontinuityReason {
        guard let mapped = PracticeDSPTransportDiscontinuityReason(rawValue: reason.rawValue) else {
            throw PracticeDSPGenerationCoordinatorError.unsupportedPlaybackReason(reason.rawValue)
        }
        return mapped
    }

    private func receipt(
        serial: UInt64,
        kind: PracticeDSPGenerationMutationKind,
        binding: PracticeDSPTransportGenerationBinding,
        clickGeneration: UInt64
    ) -> PracticeDSPGenerationCoordinatorReceipt {
        PracticeDSPGenerationCoordinatorReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_PRODUCTION_COMBINED_GENERATION_NON_PARITY",
            operationSerial: serial,
            mutationKind: kind,
            playbackGeneration: binding.playbackGeneration,
            clickGeneration: clickGeneration,
            reason: binding.reason.rawValue,
            replacementBindingActive: true,
            parityPromotionAllowed: false
        )
    }

    private func wrappedMutationError(_ error: Error) -> PracticeDSPGenerationCoordinatorError {
        if let coordinatorError = error as? PracticeDSPGenerationCoordinatorError {
            return coordinatorError
        }
        if error is CancellationError {
            return .operationCancelled
        }
        if error is PracticeDSPTransportRescheduleError {
            return .dspMutationFailed(String(describing: error))
        }
        let description = String(describing: error)
        if description.contains("Click") || description.contains("click") {
            return .clickInvalidationFailed(description)
        }
        return .dspMutationFailed(description)
    }
}

#if canImport(AVFAudio)
import AVFAudio
extension AppleSampleAccurateClickExecutor: PracticeDSPClickScheduleInvalidating {}
#endif

public enum PracticeDSPSerializedCountInDisposition: String, Codable, Sendable {
    case consumedAcceptedSchedule
    case discardedAndInvalidated
}

public enum PracticeDSPSerializedCountInError: Error, Equatable, Sendable {
    case noPendingCountIn
    case staleAuthorization(
        expectedGeneration: UInt64,
        observedGeneration: UInt64,
        expectedClicks: Int,
        observedClicks: Int?
    )
    case consumeGenerationChanged(expected: UInt64, observed: UInt64)
    case consumeDidNotClearPending(observedClicks: Int?)
    case discardGenerationDidNotAdvance(previous: UInt64, observed: UInt64)
    case discardDidNotClearPending(observedClicks: Int?)
}

public struct PracticeDSPSerializedCountInReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let operationSerial: UInt64
    public let disposition: PracticeDSPSerializedCountInDisposition
    public let previousClickGeneration: UInt64
    public let committedClickGeneration: UInt64
    public let acceptedSchedulePreserved: Bool
    public let parityPromotionAllowed: Bool
}

public extension PracticeDSPGenerationCoordinator {
    /// Consumes only the raw one-shot pending state after the click executor has already accepted the
    /// replacement count-in schedule. The click generation deliberately does NOT advance here: an
    /// advance plus node invalidation would erase the accepted count-in that this commit confirms.
    /// Exact generation + click-count matching makes duplicate and stale authorization fail closed.
    @discardableResult
    func consumeScheduledCountIn(
        expectedClickGeneration: UInt64,
        expectedClicks: Int
    ) async throws -> PracticeDSPSerializedCountInReceipt {
        let serial = try beginOperation()
        defer { operationInFlight = false }
        guard !transportGate.isPoisoned else {
            throw PracticeDSPGenerationCoordinatorError.coordinatorPoisoned
        }
        try rejectClickOnlyIfCancelled()

        let before = try await controller.snapshot(projectID: projectID)
        try rejectClickOnlyIfSuperseded(observedClickGeneration: nil)
        try rejectClickOnlyIfCancelled()
        guard let pending = before.pendingCountInClicks else {
            throw PracticeDSPSerializedCountInError.noPendingCountIn
        }
        guard before.scheduleGeneration == expectedClickGeneration,
              pending == expectedClicks else {
            throw PracticeDSPSerializedCountInError.staleAuthorization(
                expectedGeneration: expectedClickGeneration,
                observedGeneration: before.scheduleGeneration,
                expectedClicks: expectedClicks,
                observedClicks: before.pendingCountInClicks
            )
        }

        do {
            // Point of no return for a schedule that the executor already accepted. Once this clear
            // commits, Task cancellation must not re-arm the one-shot count-in.
            try await controller.clearPendingCountIn(projectID: projectID)
            let after = try await controller.snapshot(projectID: projectID)

            if transportGate.isPoisoned {
                try flushAcceptedCountInFailClosed(observedClickGeneration: after.scheduleGeneration)
                throw PracticeDSPGenerationCoordinatorError.operationSuperseded
            }
            guard after.scheduleGeneration == expectedClickGeneration else {
                let observed = after.scheduleGeneration
                try flushAcceptedCountInFailClosed(observedClickGeneration: observed)
                throw PracticeDSPSerializedCountInError.consumeGenerationChanged(
                    expected: expectedClickGeneration,
                    observed: observed
                )
            }
            guard after.pendingCountInClicks == nil else {
                try flushAcceptedCountInFailClosed(observedClickGeneration: after.scheduleGeneration)
                throw PracticeDSPSerializedCountInError.consumeDidNotClearPending(
                    observedClicks: after.pendingCountInClicks
                )
            }

            return PracticeDSPSerializedCountInReceipt(
                schemaVersion: 1,
                evidenceScope: "LANE3_SERIALIZED_COUNTIN_CONSUME_DISCARD_NON_PARITY",
                operationSerial: serial,
                disposition: .consumedAcceptedSchedule,
                previousClickGeneration: before.scheduleGeneration,
                committedClickGeneration: after.scheduleGeneration,
                acceptedSchedulePreserved: true,
                parityPromotionAllowed: false
            )
        } catch {
            if let serialized = error as? PracticeDSPSerializedCountInError {
                throw serialized
            }
            if let coordinatorError = error as? PracticeDSPGenerationCoordinatorError {
                throw coordinatorError
            }
            if error is CancellationError {
                throw PracticeDSPGenerationCoordinatorError.operationCancelled
            }
            if (try? await controller.requiresBackendResynchronization(projectID: projectID)) == true {
                transportGate.poisonObservedGenerations()
            }
            throw PracticeDSPGenerationCoordinatorError.dspMutationFailed(String(describing: error))
        }
    }

    /// Interruption/cancellation boundary API. It snapshots the current pending count-in under the
    /// coordinator's operation fence, then clears the raw pending state, advances click generation,
    /// revokes combined replacement authority and invalidates the Apple/portable click queue.
    /// Returns nil when there is no raw pending count-in to discard.
    @discardableResult
    func discardCurrentCountIn() async throws -> PracticeDSPSerializedCountInReceipt? {
        let serial = try beginOperation()
        defer { operationInFlight = false }
        guard !transportGate.isPoisoned else {
            throw PracticeDSPGenerationCoordinatorError.coordinatorPoisoned
        }
        try rejectClickOnlyIfCancelled()

        let before = try await controller.snapshot(projectID: projectID)
        try rejectClickOnlyIfSuperseded(observedClickGeneration: nil)
        try rejectClickOnlyIfCancelled()
        guard before.pendingCountInClicks != nil else { return nil }
        return try await discardCountInAfterSnapshot(before: before, serial: serial)
    }

    /// Exact-authority variant used by race tests and callers that must prove they are discarding the
    /// same one-shot arm rather than a newer replacement arm.
    @discardableResult
    func discardCountIn(
        expectedClickGeneration: UInt64,
        expectedClicks: Int
    ) async throws -> PracticeDSPSerializedCountInReceipt {
        let serial = try beginOperation()
        defer { operationInFlight = false }
        guard !transportGate.isPoisoned else {
            throw PracticeDSPGenerationCoordinatorError.coordinatorPoisoned
        }
        try rejectClickOnlyIfCancelled()

        let before = try await controller.snapshot(projectID: projectID)
        try rejectClickOnlyIfSuperseded(observedClickGeneration: nil)
        try rejectClickOnlyIfCancelled()
        guard let pending = before.pendingCountInClicks else {
            throw PracticeDSPSerializedCountInError.noPendingCountIn
        }
        guard before.scheduleGeneration == expectedClickGeneration,
              pending == expectedClicks else {
            throw PracticeDSPSerializedCountInError.staleAuthorization(
                expectedGeneration: expectedClickGeneration,
                observedGeneration: before.scheduleGeneration,
                expectedClicks: expectedClicks,
                observedClicks: before.pendingCountInClicks
            )
        }
        return try await discardCountInAfterSnapshot(before: before, serial: serial)
    }

    private func discardCountInAfterSnapshot(
        before: PracticeDSPState,
        serial: UInt64
    ) async throws -> PracticeDSPSerializedCountInReceipt {
        var mutationStarted = false
        var observedGeneration = before.scheduleGeneration
        do {
            mutationStarted = true
            try await controller.clearPendingCountIn(projectID: projectID)
            observedGeneration = try await controller.invalidateScheduledClicks(projectID: projectID)
            let after = try await controller.snapshot(projectID: projectID)
            observedGeneration = after.scheduleGeneration

            guard after.pendingCountInClicks == nil else {
                throw PracticeDSPSerializedCountInError.discardDidNotClearPending(
                    observedClicks: after.pendingCountInClicks
                )
            }
            guard after.scheduleGeneration > before.scheduleGeneration else {
                throw PracticeDSPSerializedCountInError.discardGenerationDidNotAdvance(
                    previous: before.scheduleGeneration,
                    observed: after.scheduleGeneration
                )
            }

            if transportGate.isPoisoned {
                transportGate.poisonObservedGenerations(clickGeneration: after.scheduleGeneration)
                try invalidateClickQueueFailClosed(to: after.scheduleGeneration)
                throw PracticeDSPGenerationCoordinatorError.operationSuperseded
            }

            do {
                try transportGate.revokeReplacementAuthorityAfterClickOnlyInvalidation(
                    clickGeneration: after.scheduleGeneration
                )
            } catch {
                transportGate.poisonObservedGenerations(clickGeneration: after.scheduleGeneration)
                try invalidateClickQueueFailClosed(to: after.scheduleGeneration)
                throw error
            }

            // Node invalidation is the discard commit point. Cancellation after mutation began does
            // not skip this flush; leaving an old accepted count-in queued would be less safe.
            try invalidateClickQueueFailClosed(to: after.scheduleGeneration)
            return PracticeDSPSerializedCountInReceipt(
                schemaVersion: 1,
                evidenceScope: "LANE3_SERIALIZED_COUNTIN_CONSUME_DISCARD_NON_PARITY",
                operationSerial: serial,
                disposition: .discardedAndInvalidated,
                previousClickGeneration: before.scheduleGeneration,
                committedClickGeneration: after.scheduleGeneration,
                acceptedSchedulePreserved: false,
                parityPromotionAllowed: false
            )
        } catch {
            if mutationStarted {
                if let snapshot = try? await controller.snapshot(projectID: projectID) {
                    observedGeneration = snapshot.scheduleGeneration
                }
                transportGate.poisonObservedGenerations(clickGeneration: observedGeneration)
                do {
                    // Equal-generation invalidation is intentionally allowed by the click execution
                    // state, so generation-overflow can still flush the stale queue fail closed.
                    try invalidateClickQueueFailClosed(to: observedGeneration)
                } catch {
                    throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(
                        String(describing: error)
                    )
                }
            }
            if let serialized = error as? PracticeDSPSerializedCountInError {
                throw serialized
            }
            if let coordinatorError = error as? PracticeDSPGenerationCoordinatorError {
                throw coordinatorError
            }
            if error is CancellationError {
                throw PracticeDSPGenerationCoordinatorError.operationCancelled
            }
            throw PracticeDSPGenerationCoordinatorError.dspMutationFailed(String(describing: error))
        }
    }

    private func flushAcceptedCountInFailClosed(
        observedClickGeneration: UInt64
    ) throws {
        transportGate.poisonObservedGenerations(clickGeneration: observedClickGeneration)
        try invalidateClickQueueFailClosed(to: observedClickGeneration)
    }

    private func invalidateClickQueueFailClosed(to generation: UInt64) throws {
        do {
            try clickInvalidator.invalidateSchedule(to: generation)
        } catch {
            transportGate.poisonObservedGenerations(clickGeneration: generation)
            throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(
                String(describing: error)
            )
        }
    }
}
