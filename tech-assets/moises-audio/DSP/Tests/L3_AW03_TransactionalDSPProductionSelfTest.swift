import Foundation

private enum ProbeError: Error { case apply; case rollback; case snapshot }

private final class FlakyTransactionalDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    var tempo = 1.0
    var pitch = 0.0
    var applyCalls = 0
    var snapshotCalls = 0
    var failNextAfterTempo = false
    var failRollback = false
    var failSnapshot = false
    var silentlyIgnorePitch = false

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        snapshotCalls += 1
        if failSnapshot { throw ProbeError.snapshot }
        return PracticeDSPBackendSnapshot(
            tempoRatio: tempo,
            pitchSemitones: pitch
        )
    }

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        applyCalls += 1
        if failRollback && tempoRatio == 1 && pitchSemitones == 0 {
            throw ProbeError.rollback
        }
        tempo = tempoRatio
        if failNextAfterTempo {
            failNextAfterTempo = false
            throw ProbeError.apply
        }
        if !silentlyIgnorePitch {
            pitch = pitchSemitones
        }
    }
}

@main
struct L3AW03TransactionalDSPProductionSelfTest {
    static func main() async throws {
        try await testSuccessfulTransaction()
        try await testPartialFailureRollback()
        try await testSilentMismatchRollback()
        try await testRollbackFailurePoisonAndRecovery()
        try await testExternalDivergenceRecovery()
        try await testProductionControllerAtomicity()
        try await testGenerationOverflowDoesNotTouchBackend()
        print("L3-AW03 transactional DSP production self-test: PASS")
    }

    static func testSuccessfulTransaction() async throws {
        let backend = FlakyTransactionalDSPBackend()
        let gate = try PracticeDSPTransactionalApplicationGate(backend: backend)
        let candidate = PracticeDSPState(
            tempoRatio: 1.25,
            pitchSemitones: 2,
            scheduleGeneration: 1
        )
        _ = try await gate.apply(candidate)
        let committed = await gate.committedState()
        precondition(committed == candidate)
        precondition(backend.tempo == 1.25 && backend.pitch == 2)
    }

    static func testPartialFailureRollback() async throws {
        let backend = FlakyTransactionalDSPBackend()
        let gate = try PracticeDSPTransactionalApplicationGate(backend: backend)
        backend.failNextAfterTempo = true
        do {
            _ = try await gate.apply(
                PracticeDSPState(tempoRatio: 0.75, pitchSemitones: -3)
            )
            preconditionFailure("partial backend write must fail")
        } catch PracticeDSPTransactionError.backendRejectedRolledBack { }
        precondition(backend.tempo == 1 && backend.pitch == 0)
        let committed = await gate.committedState()
        precondition(committed == PracticeDSPState())
    }

    static func testSilentMismatchRollback() async throws {
        let backend = FlakyTransactionalDSPBackend()
        let gate = try PracticeDSPTransactionalApplicationGate(backend: backend)
        backend.silentlyIgnorePitch = true
        do {
            _ = try await gate.apply(
                PracticeDSPState(tempoRatio: 1.2, pitchSemitones: 4)
            )
            preconditionFailure("silent backend mismatch must fail")
        } catch PracticeDSPTransactionError.backendPostApplyMismatchRolledBack { }
        precondition(backend.tempo == 1 && backend.pitch == 0)
        let committed = await gate.committedState()
        precondition(committed == PracticeDSPState())
    }

    static func testRollbackFailurePoisonAndRecovery() async throws {
        let backend = FlakyTransactionalDSPBackend()
        let gate = try PracticeDSPTransactionalApplicationGate(backend: backend)
        backend.failNextAfterTempo = true
        backend.failRollback = true
        do {
            _ = try await gate.apply(
                PracticeDSPState(tempoRatio: 1.5, pitchSemitones: 3)
            )
            preconditionFailure("rollback failure must poison gate")
        } catch PracticeDSPTransactionError.backendRollbackFailed { }
        var requiresResync = await gate.requiresResynchronization()
        precondition(requiresResync)
        do {
            _ = try await gate.apply(
                PracticeDSPState(tempoRatio: 1.1, pitchSemitones: 1)
            )
            preconditionFailure("poisoned gate must reject normal apply")
        } catch PracticeDSPTransactionError.backendDesynchronized { }
        backend.failRollback = false
        _ = try await gate.recoverCommittedState()
        requiresResync = await gate.requiresResynchronization()
        precondition(!requiresResync)
        precondition(backend.tempo == 1 && backend.pitch == 0)
    }

    static func testExternalDivergenceRecovery() async throws {
        let backend = FlakyTransactionalDSPBackend()
        let gate = try PracticeDSPTransactionalApplicationGate(backend: backend)
        backend.tempo = 1.2
        do {
            _ = try await gate.apply(
                PracticeDSPState(tempoRatio: 1.1, pitchSemitones: 0)
            )
            preconditionFailure("external mutation must be detected")
        } catch PracticeDSPTransactionError.backendStateDiverged { }
        let requiresResync = await gate.requiresResynchronization()
        precondition(requiresResync)
        _ = try await gate.recoverCommittedState()
        precondition(backend.tempo == 1)
    }

    static func testProductionControllerAtomicity() async throws {
        let projectID = ProjectID()
        let backend = FlakyTransactionalDSPBackend()
        let controller = try PracticeDSPProductionController(
            projectID: projectID,
            backend: backend
        )

        try await controller.setTempoRatio(1.25, projectID: projectID)
        var state = try await controller.snapshot(projectID: projectID)
        precondition(state.tempoRatio == 1.25)
        precondition(state.scheduleGeneration == 1)

        try await controller.setPitchSemitones(2, projectID: projectID)
        state = try await controller.snapshot(projectID: projectID)
        precondition(state.pitchSemitones == 2)
        precondition(state.scheduleGeneration == 1, "pitch alone does not invalidate click timing")

        let backendCallsBeforeControlOnly = backend.applyCalls
        try await controller.setMetronomeEnabled(true, projectID: projectID)
        try await controller.scheduleCountIn(clicks: 4, projectID: projectID)
        state = try await controller.snapshot(projectID: projectID)
        precondition(state.scheduleGeneration == 3)
        precondition(state.pendingCountInClicks == 4)
        precondition(backend.applyCalls == backendCallsBeforeControlOnly)

        let beforeRejectedTempo = state
        backend.failNextAfterTempo = true
        do {
            try await controller.setTempoRatio(0.8, projectID: projectID)
            preconditionFailure("rejected tempo must not commit logical state")
        } catch PracticeDSPTransactionError.backendRejectedRolledBack { }
        let afterRejectedTempo = try await controller.snapshot(projectID: projectID)
        precondition(afterRejectedTempo == beforeRejectedTempo)

        let foreignProject = ProjectID()
        do {
            try await controller.setPitchSemitones(1, projectID: foreignProject)
            preconditionFailure("active-project coordinator must reject foreign project")
        } catch PracticeDSPTransactionError.projectMismatch { }
    }

    static func testGenerationOverflowDoesNotTouchBackend() async throws {
        let projectID = ProjectID()
        let backend = FlakyTransactionalDSPBackend()
        let controller = try PracticeDSPProductionController(
            projectID: projectID,
            backend: backend,
            initialState: PracticeDSPState(scheduleGeneration: UInt64.max)
        )
        do {
            try await controller.setTempoRatio(1.2, projectID: projectID)
            preconditionFailure("generation overflow must fail before backend write")
        } catch PracticeDSPConfigurationError.scheduleGenerationOverflow { }
        precondition(backend.applyCalls == 0)
    }
}
