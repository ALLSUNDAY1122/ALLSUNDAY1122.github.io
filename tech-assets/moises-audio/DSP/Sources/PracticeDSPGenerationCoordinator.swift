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
        let serial = try beginOperation()
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
            try cancelPendingIntentIfNeeded(
                intent: intent,
                observedClickGeneration: clickGeneration
            )
            do {
                try clickInvalidator.invalidateSchedule(to: clickGeneration)
            } catch {
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(String(describing: error))
            }
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
        let serial = try beginOperation()
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
            try cancelPendingIntentIfNeeded(
                intent: intent,
                observedClickGeneration: state.scheduleGeneration
            )
            do {
                try clickInvalidator.invalidateSchedule(to: state.scheduleGeneration)
            } catch {
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(String(describing: error))
            }
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
        let serial = try beginOperation()
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
            try poisonRecoveryIfCancelled(
                playbackToken: playbackToken,
                observedClickGeneration: nil
            )
            let clickGeneration = try await controller.invalidateScheduledClicks(projectID: projectID)
            observedClickGeneration = clickGeneration
            try poisonRecoveryIfCancelled(
                playbackToken: playbackToken,
                observedClickGeneration: clickGeneration
            )
            do {
                try clickInvalidator.invalidateSchedule(to: clickGeneration)
            } catch {
                throw PracticeDSPGenerationCoordinatorError.clickInvalidationFailed(String(describing: error))
            }
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
    /// Playback fence. A genuinely newer token therefore revokes the old combined replacement
    /// authority and poisons the gate. Stale/replayed tokens do not destroy a valid current binding.
    private func poisonIfPlaybackTokenAdvanced(
        _ playbackToken: PlaybackTransportRescheduleToken
    ) {
        if let previous = transportGate.lastPlaybackGeneration {
            guard playbackToken.generation > previous else { return }
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

    private func poisonClickOnlyIfCancelled(
        clickGeneration: UInt64
    ) throws {
        guard Task.isCancelled else { return }
        transportGate.poisonObservedGenerations(
            clickGeneration: clickGeneration
        )
        throw PracticeDSPGenerationCoordinatorError.operationCancelled
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
