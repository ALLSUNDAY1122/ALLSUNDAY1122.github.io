import Foundation
public struct PracticeDSPBackendSnapshot: Equatable, Sendable {
    public let tempoRatio: Double
    public let pitchSemitones: Double
    public init(tempoRatio: Double, pitchSemitones: Double) {
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
    }
}
public protocol PracticeDSPTransactionalBackendApplying: PracticeDSPBackendApplying {
    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot
}
public enum PracticeDSPTransactionError: Error, Equatable, Sendable {
    case backendUnavailable
    case backendSnapshotFailed(String)
    case backendStateDiverged(expected: PracticeDSPBackendSnapshot, observed: PracticeDSPBackendSnapshot)
    case backendRejectedRolledBack(String)
    case backendPostApplySnapshotFailedRolledBack(String)
    case backendPostApplyMismatchRolledBack(expected: PracticeDSPBackendSnapshot, observed: PracticeDSPBackendSnapshot)
    case backendRollbackFailed(applyError: String, rollbackError: String)
    case backendDesynchronized
    case projectMismatch(expected: ProjectID, actual: ProjectID)
    case controlOnlyMutationChangedBackendState
    case transactionInFlight
}
public struct PracticeDSPBackendAlignmentTolerance: Equatable, Sendable {
    public let tempoRatio: Double
    public let pitchSemitones: Double
    public init(
        tempoRatio: Double = 0.000_1,
        pitchSemitones: Double = 0.001
    ) {
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
    }
}
public actor PracticeDSPTransactionalApplicationGate {
    private let capabilities: PracticeDSPCapabilities
    private let backend: (any PracticeDSPTransactionalBackendApplying)?
    private let alignmentTolerance: PracticeDSPBackendAlignmentTolerance
    private let pitchTransitionPolicy: PracticeDSPPitchTransitionPolicy
    private let pitchTransitionSleeper: any PracticeDSPPitchTransitionSleeping
    private var committed: PracticeDSPState
    private var desynchronized = false
    private var transactionInFlight = false
    private var lastPitchTransition: PracticeDSPPitchTransitionBackendReceipt?
    public init(
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        backend: (any PracticeDSPTransactionalBackendApplying)?,
        initialState: PracticeDSPState = PracticeDSPState(),
        alignmentTolerance: PracticeDSPBackendAlignmentTolerance = PracticeDSPBackendAlignmentTolerance(),
        pitchTransitionPolicy: PracticeDSPPitchTransitionPolicy = .provisionalAppleInteractive,
        pitchTransitionSleeper: any PracticeDSPPitchTransitionSleeping = PracticeDSPSystemPitchTransitionSleeper()
    ) throws {
        try PracticeDSPStateValidator.validate(initialState, capabilities: capabilities)
        self.capabilities = capabilities
        self.backend = backend
        self.committed = initialState
        self.alignmentTolerance = alignmentTolerance
        self.pitchTransitionPolicy = pitchTransitionPolicy
        self.pitchTransitionSleeper = pitchTransitionSleeper
    }
    @discardableResult
    public func apply(_ candidate: PracticeDSPState) async throws -> PracticeDSPState {
        try PracticeDSPStateValidator.validate(candidate, capabilities: capabilities)
        guard !transactionInFlight else { throw PracticeDSPTransactionError.transactionInFlight }
        guard !desynchronized else { throw PracticeDSPTransactionError.backendDesynchronized }
        guard let backend else { throw PracticeDSPTransactionError.backendUnavailable }
        let pitchChanged = candidate.pitchSemitones != committed.pitchSemitones
        let tempoPreserved = abs(candidate.tempoRatio - committed.tempoRatio) <= alignmentTolerance.tempoRatio
        if pitchChanged,
           tempoPreserved,
           let transitionBackend = backend as? any PracticeDSPPitchTransitionBackendApplying {
            transactionInFlight = true
            defer { transactionInFlight = false }
            return try await applyPitchTransition(
                candidate,
                backend: backend,
                transitionBackend: transitionBackend
            )
        }
        lastPitchTransition = nil
        return try applyImmediate(candidate, backend: backend)
    }
    @discardableResult
    public func commitControlOnly(_ candidate: PracticeDSPState) throws -> PracticeDSPState {
        try PracticeDSPStateValidator.validate(candidate, capabilities: capabilities)
        guard !transactionInFlight else { throw PracticeDSPTransactionError.transactionInFlight }
        guard !desynchronized else { throw PracticeDSPTransactionError.backendDesynchronized }
        guard aligned(
            backendSnapshot(for: candidate),
            backendSnapshot(for: committed)
        ) else {
            throw PracticeDSPTransactionError.controlOnlyMutationChangedBackendState
        }
        if let backend {
            let observed = try snapshot(backend)
            let expected = backendSnapshot(for: committed)
            guard aligned(observed, expected) else {
                desynchronized = true
                throw PracticeDSPTransactionError.backendStateDiverged(
                    expected: expected,
                    observed: observed
                )
            }
        }
        committed = candidate
        return candidate
    }
    @discardableResult
    public func recoverCommittedState() throws -> PracticeDSPState {
        guard !transactionInFlight else { throw PracticeDSPTransactionError.transactionInFlight }
        guard let backend else { throw PracticeDSPTransactionError.backendUnavailable }
        let expected = backendSnapshot(for: committed)
        do {
            try backend.apply(
                tempoRatio: expected.tempoRatio,
                pitchSemitones: expected.pitchSemitones
            )
            let observed = try backend.snapshotAppliedDSP()
            guard aligned(observed, expected) else {
                desynchronized = true
                throw PracticeDSPTransactionError.backendStateDiverged(
                    expected: expected,
                    observed: observed
                )
            }
        } catch let error as PracticeDSPTransactionError {
            desynchronized = true
            throw error
        } catch {
            desynchronized = true
            throw PracticeDSPTransactionError.backendRollbackFailed(
                applyError: "recovery",
                rollbackError: String(describing: error)
            )
        }
        desynchronized = false
        lastPitchTransition = nil
        return committed
    }
    public func committedState() -> PracticeDSPState { committed }
    public func requiresResynchronization() -> Bool { desynchronized }
    public func lastPitchTransitionReceipt() -> PracticeDSPPitchTransitionBackendReceipt? { lastPitchTransition }
    private func applyImmediate(
        _ candidate: PracticeDSPState,
        backend: any PracticeDSPTransactionalBackendApplying
    ) throws -> PracticeDSPState {
        let observedBefore = try snapshot(backend)
        let expectedBefore = backendSnapshot(for: committed)
        guard aligned(observedBefore, expectedBefore) else {
            desynchronized = true
            throw PracticeDSPTransactionError.backendStateDiverged(
                expected: expectedBefore,
                observed: observedBefore
            )
        }
        do {
            try backend.apply(
                tempoRatio: candidate.tempoRatio,
                pitchSemitones: candidate.pitchSemitones
            )
        } catch {
            let applyError = String(describing: error)
            try rollback(backend, to: observedBefore, applyError: applyError)
            throw PracticeDSPTransactionError.backendRejectedRolledBack(applyError)
        }
        let observedAfter: PracticeDSPBackendSnapshot
        do {
            observedAfter = try backend.snapshotAppliedDSP()
        } catch {
            let snapshotError = String(describing: error)
            try rollback(
                backend,
                to: observedBefore,
                applyError: "post-apply snapshot failed: \(snapshotError)"
            )
            throw PracticeDSPTransactionError.backendPostApplySnapshotFailedRolledBack(snapshotError)
        }
        let expectedAfter = backendSnapshot(for: candidate)
        guard aligned(observedAfter, expectedAfter) else {
            try rollback(backend, to: observedBefore, applyError: "post-apply state mismatch")
            throw PracticeDSPTransactionError.backendPostApplyMismatchRolledBack(
                expected: expectedAfter,
                observed: observedAfter
            )
        }
        committed = candidate
        return candidate
    }
    private func applyPitchTransition(
        _ candidate: PracticeDSPState,
        backend: any PracticeDSPTransactionalBackendApplying,
        transitionBackend: any PracticeDSPPitchTransitionBackendApplying
    ) async throws -> PracticeDSPState {
        let observedBefore = try snapshot(backend)
        let expectedBefore = backendSnapshot(for: committed)
        guard aligned(observedBefore, expectedBefore) else {
            desynchronized = true
            throw PracticeDSPTransactionError.backendStateDiverged(
                expected: expectedBefore,
                observed: observedBefore
            )
        }
        let receipt: PracticeDSPPitchTransitionBackendReceipt
        do {
            receipt = try transitionBackend.beginPitchTransition(
                tempoRatio: candidate.tempoRatio,
                fromPitchSemitones: committed.pitchSemitones,
                toPitchSemitones: candidate.pitchSemitones,
                policy: pitchTransitionPolicy
            )
        } catch {
            let applyError = "pitch transition begin: \(String(describing: error))"
            try rollbackPitchTransition(
                transitionBackend,
                to: observedBefore,
                applyError: applyError
            )
            throw PracticeDSPTransactionError.backendRejectedRolledBack(applyError)
        }
        guard receipt.schemaVersion == 1,
              receipt.evidenceScope == "LANE3_AW25_PITCH_TRANSITION_NON_PARITY",
              !receipt.parityPromotionAllowed,
              abs(receipt.fromSemitones - committed.pitchSemitones) <= alignmentTolerance.pitchSemitones,
              abs(receipt.toSemitones - candidate.pitchSemitones) <= alignmentTolerance.pitchSemitones else {
            let applyError = "invalid pitch transition receipt"
            try rollbackPitchTransition(transitionBackend, to: observedBefore, applyError: applyError)
            throw PracticeDSPTransactionError.backendRejectedRolledBack(applyError)
        }
        if receipt.mode == .scheduledRamp, receipt.recommendedBarrierNanoseconds > 0 {
            await pitchTransitionSleeper.sleepIgnoringCancellation(
                nanoseconds: receipt.recommendedBarrierNanoseconds
            )
            do {
                try transitionBackend.finalizePitchTransition(
                    tempoRatio: candidate.tempoRatio,
                    pitchSemitones: candidate.pitchSemitones
                )
            } catch {
                let applyError = "pitch transition finalize: \(String(describing: error))"
                try rollbackPitchTransition(transitionBackend, to: observedBefore, applyError: applyError)
                throw PracticeDSPTransactionError.backendRejectedRolledBack(applyError)
            }
        }
        let observedAfter: PracticeDSPBackendSnapshot
        do {
            observedAfter = try backend.snapshotAppliedDSP()
        } catch {
            let snapshotError = String(describing: error)
            try rollbackPitchTransition(
                transitionBackend,
                to: observedBefore,
                applyError: "pitch transition post-apply snapshot failed: \(snapshotError)"
            )
            throw PracticeDSPTransactionError.backendPostApplySnapshotFailedRolledBack(snapshotError)
        }
        let expectedAfter = backendSnapshot(for: candidate)
        guard aligned(observedAfter, expectedAfter) else {
            try rollbackPitchTransition(
                transitionBackend,
                to: observedBefore,
                applyError: "pitch transition post-apply state mismatch"
            )
            throw PracticeDSPTransactionError.backendPostApplyMismatchRolledBack(
                expected: expectedAfter,
                observed: observedAfter
            )
        }
        committed = candidate
        lastPitchTransition = receipt
        return candidate
    }
    private func snapshot(
        _ backend: any PracticeDSPTransactionalBackendApplying
    ) throws -> PracticeDSPBackendSnapshot {
        do { return try backend.snapshotAppliedDSP() }
        catch {
            throw PracticeDSPTransactionError.backendSnapshotFailed(String(describing: error))
        }
    }
    private func rollback(
        _ backend: any PracticeDSPTransactionalBackendApplying,
        to target: PracticeDSPBackendSnapshot,
        applyError: String
    ) throws {
        do {
            try backend.apply(
                tempoRatio: target.tempoRatio,
                pitchSemitones: target.pitchSemitones
            )
            let observed = try backend.snapshotAppliedDSP()
            guard aligned(observed, target) else {
                desynchronized = true
                throw PracticeDSPTransactionError.backendStateDiverged(expected: target, observed: observed)
            }
        } catch let error as PracticeDSPTransactionError {
            desynchronized = true
            throw PracticeDSPTransactionError.backendRollbackFailed(
                applyError: applyError,
                rollbackError: String(describing: error)
            )
        } catch {
            desynchronized = true
            throw PracticeDSPTransactionError.backendRollbackFailed(
                applyError: applyError,
                rollbackError: String(describing: error)
            )
        }
    }
    private func rollbackPitchTransition(
        _ backend: any PracticeDSPPitchTransitionBackendApplying,
        to target: PracticeDSPBackendSnapshot,
        applyError: String
    ) throws {
        do {
            try backend.cancelPitchTransition(
                tempoRatio: target.tempoRatio,
                pitchSemitones: target.pitchSemitones
            )
            let observed = try backend.snapshotAppliedDSP()
            guard aligned(observed, target) else {
                desynchronized = true
                throw PracticeDSPTransactionError.backendStateDiverged(expected: target, observed: observed)
            }
        } catch let error as PracticeDSPTransactionError {
            desynchronized = true
            throw PracticeDSPTransactionError.backendRollbackFailed(
                applyError: applyError,
                rollbackError: String(describing: error)
            )
        } catch {
            desynchronized = true
            throw PracticeDSPTransactionError.backendRollbackFailed(
                applyError: applyError,
                rollbackError: String(describing: error)
            )
        }
    }
    private func backendSnapshot(for state: PracticeDSPState) -> PracticeDSPBackendSnapshot {
        PracticeDSPBackendSnapshot(
            tempoRatio: state.tempoRatio,
            pitchSemitones: state.pitchSemitones
        )
    }
    private func aligned(_ lhs: PracticeDSPBackendSnapshot, _ rhs: PracticeDSPBackendSnapshot) -> Bool {
        lhs.tempoRatio.isFinite
            && lhs.pitchSemitones.isFinite
            && abs(lhs.tempoRatio - rhs.tempoRatio) <= alignmentTolerance.tempoRatio
            && abs(lhs.pitchSemitones - rhs.pitchSemitones) <= alignmentTolerance.pitchSemitones
    }
}
public actor PracticeDSPProductionController: PracticeDSPConfiguring {
    private let projectID: ProjectID
    private let capabilities: PracticeDSPCapabilities
    private let gate: PracticeDSPTransactionalApplicationGate
    private var state: PracticeDSPState
    private var lastPitchTransition: PracticeDSPPitchTransitionBackendReceipt?
    public init(
        projectID: ProjectID,
        backend: (any PracticeDSPTransactionalBackendApplying)?,
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        initialState: PracticeDSPState = PracticeDSPState(),
        pitchTransitionPolicy: PracticeDSPPitchTransitionPolicy = .provisionalAppleInteractive,
        pitchTransitionSleeper: any PracticeDSPPitchTransitionSleeping = PracticeDSPSystemPitchTransitionSleeper()
    ) throws {
        try PracticeDSPStateValidator.validate(initialState, capabilities: capabilities)
        self.projectID = projectID
        self.capabilities = capabilities
        self.state = initialState
        self.gate = try PracticeDSPTransactionalApplicationGate(
            capabilities: capabilities,
            backend: backend,
            initialState: initialState,
            pitchTransitionPolicy: pitchTransitionPolicy,
            pitchTransitionSleeper: pitchTransitionSleeper
        )
    }
    public func setTempoRatio(_ ratio: Double, projectID: ProjectID) async throws {
        try requireProject(projectID)
        var candidate = state
        candidate.tempoRatio = ratio
        candidate.scheduleGeneration = try PracticeDSPStateValidator.nextGeneration(after: candidate.scheduleGeneration)
        try PracticeDSPStateValidator.validate(candidate, capabilities: capabilities)
        _ = try await gate.apply(candidate)
        state = candidate
        lastPitchTransition = nil
    }
    public func setPitchSemitones(_ semitones: Double, projectID: ProjectID) async throws {
        try requireProject(projectID)
        var candidate = state
        candidate.pitchSemitones = semitones
        try PracticeDSPStateValidator.validate(candidate, capabilities: capabilities)
        _ = try await gate.apply(candidate)
        state = candidate
        lastPitchTransition = await gate.lastPitchTransitionReceipt()
    }
    public func setMetronomeEnabled(_ enabled: Bool, projectID: ProjectID) async throws {
        try requireProject(projectID)
        var candidate = state
        candidate.metronomeEnabled = enabled
        candidate.scheduleGeneration = try PracticeDSPStateValidator.nextGeneration(after: candidate.scheduleGeneration)
        _ = try await gate.commitControlOnly(candidate)
        state = candidate
        lastPitchTransition = nil
    }
    public func scheduleCountIn(clicks: Int, projectID: ProjectID) async throws {
        try requireProject(projectID)
        var candidate = state
        candidate.pendingCountInClicks = clicks
        candidate.scheduleGeneration = try PracticeDSPStateValidator.nextGeneration(after: candidate.scheduleGeneration)
        try PracticeDSPStateValidator.validate(candidate, capabilities: capabilities)
        _ = try await gate.commitControlOnly(candidate)
        state = candidate
        lastPitchTransition = nil
    }
    public func restoreState(_ restored: PracticeDSPState, projectID: ProjectID) async throws {
        try requireProject(projectID)
        let candidate = try PracticeDSPStateValidator.restored(restored, capabilities: capabilities)
        _ = try await gate.apply(candidate)
        state = candidate
        lastPitchTransition = nil
    }
    public func clearPendingCountIn(projectID: ProjectID) async throws {
        try requireProject(projectID)
        var candidate = state
        candidate.pendingCountInClicks = nil
        _ = try await gate.commitControlOnly(candidate)
        state = candidate
        lastPitchTransition = nil
    }
    @discardableResult
    public func invalidateScheduledClicks(projectID: ProjectID) async throws -> UInt64 {
        try requireProject(projectID)
        var candidate = state
        candidate.scheduleGeneration = try PracticeDSPStateValidator.nextGeneration(after: candidate.scheduleGeneration)
        _ = try await gate.commitControlOnly(candidate)
        state = candidate
        lastPitchTransition = nil
        return candidate.scheduleGeneration
    }
    public func snapshot(projectID: ProjectID) throws -> PracticeDSPState {
        try requireProject(projectID)
        return state
    }
    public func pitchTransitionReceipt(projectID: ProjectID) throws -> PracticeDSPPitchTransitionBackendReceipt? {
        try requireProject(projectID)
        return lastPitchTransition
    }
    public func recoverBackend(projectID: ProjectID) async throws {
        try requireProject(projectID)
        _ = try await gate.recoverCommittedState()
        lastPitchTransition = nil
    }
    public func requiresBackendResynchronization(projectID: ProjectID) async throws -> Bool {
        try requireProject(projectID)
        return await gate.requiresResynchronization()
    }
    private func requireProject(_ actual: ProjectID) throws {
        guard actual == projectID else {
            throw PracticeDSPTransactionError.projectMismatch(expected: projectID, actual: actual)
        }
    }
}
