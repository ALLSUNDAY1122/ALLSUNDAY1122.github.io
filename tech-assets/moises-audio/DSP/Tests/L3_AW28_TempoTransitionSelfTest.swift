import Foundation

private enum AW28FakeError: Error { case begin, finalize, cancel }

private final class AW28FakeTempoBackend: PracticeDSPTempoTransitionBackendApplying, @unchecked Sendable {
    enum Mode { case normal, fallback, forgedReceipt, forgedCancelFail, beginFail, finalizeFail, postFinalizeMismatch }
    private let lock = NSLock()
    private var applied = PracticeDSPBackendSnapshot(tempoRatio: 1, pitchSemitones: 0)
    private var mode: Mode = .normal
    private(set) var beginCount = 0
    private(set) var finalizeCount = 0
    private(set) var cancelCount = 0

    func configure(_ mode: Mode) { lock.lock(); self.mode = mode; lock.unlock() }
    func current() -> PracticeDSPBackendSnapshot { lock.lock(); defer { lock.unlock() }; return applied }

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        applied = .init(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot { current() }

    func beginTempoTransition(
        fromTempoRatio: Double,
        toTempoRatio: Double,
        pitchSemitones: Double,
        policy: PracticeDSPTempoTransitionPolicy
    ) throws -> PracticeDSPTempoTransitionBackendReceipt {
        lock.lock(); beginCount += 1; let selected = mode; lock.unlock()
        if selected == .beginFail { throw AW28FakeError.begin }
        if selected == .forgedReceipt || selected == .forgedCancelFail {
            return .init(
                mode: .scheduledRamp,
                fallbackReason: nil,
                fromRatio: fromTempoRatio + 0.1,
                toRatio: toTempoRatio,
                sampleRate: 48_000,
                rampDurationFrames: 100,
                recommendedBarrierNanoseconds: 1
            )
        }
        if selected == .fallback {
            try apply(tempoRatio: toTempoRatio, pitchSemitones: pitchSemitones)
            return .immediateFallback(
                reason: .backendTransitionUnsupported,
                fromRatio: fromTempoRatio,
                toRatio: toTempoRatio,
                sampleRate: 0
            )
        }
        return .init(plan: try PracticeDSPTempoTransitionPlanner.makePlan(
            fromRatio: fromTempoRatio,
            toRatio: toTempoRatio,
            sampleRate: 48_000,
            policy: policy
        ))
    }

    func finalizeTempoTransition(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); finalizeCount += 1; let selected = mode; lock.unlock()
        if selected == .finalizeFail { throw AW28FakeError.finalize }
        try apply(
            tempoRatio: selected == .postFinalizeMismatch ? tempoRatio + 0.2 : tempoRatio,
            pitchSemitones: pitchSemitones
        )
    }

    func cancelTempoTransition(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); cancelCount += 1; let selected = mode; lock.unlock()
        if selected == .forgedCancelFail { throw AW28FakeError.cancel }
        try apply(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)
    }
}

private final class AW28PlainBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private var applied = PracticeDSPBackendSnapshot(tempoRatio: 1, pitchSemitones: 0)
    func apply(tempoRatio: Double, pitchSemitones: Double) throws { applied = .init(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones) }
    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot { applied }
}

private struct AW28NoOpTempoSleeper: PracticeDSPTempoTransitionSleeping {
    func sleepIgnoringCancellation(nanoseconds: UInt64) async {}
}

private actor AW28ManualTempoSleeper: PracticeDSPTempoTransitionSleeping {
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        entered = true
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() { releaseContinuation?.resume(); releaseContinuation = nil }
}

@main
struct L3AW28TempoTransitionSelfTest {
    static func main() async throws {
        let policy = PracticeDSPTempoTransitionPolicy.provisionalAppleInteractive
        let immediate = try PracticeDSPTempoTransitionPlanner.makePlan(fromRatio: 1, toRatio: 1.005, sampleRate: 48_000, policy: policy)
        precondition(immediate.mode == .immediate && immediate.rampDurationFrames == 0)
        let down = try PracticeDSPTempoTransitionPlanner.makePlan(fromRatio: 1, toRatio: 0.5, sampleRate: 48_000, policy: policy)
        let up = try PracticeDSPTempoTransitionPlanner.makePlan(fromRatio: 0.5, toRatio: 1, sampleRate: 48_000, policy: policy)
        precondition(down.mode == .scheduledRamp && up.mode == .scheduledRamp)
        precondition(down.rampDurationFrames == up.rampDurationFrames)
        precondition(down.rampDurationFrames > 0 && down.rampDurationFrames <= 4_096)
        do { _ = try PracticeDSPTempoTransitionPlanner.makePlan(fromRatio: 0, toRatio: 1, sampleRate: 48_000); preconditionFailure() }
        catch PracticeDSPTempoTransitionPlanningError.invalidTempoRatio { }
        do { _ = try PracticeDSPTempoTransitionPlanner.makePlan(fromRatio: 1, toRatio: 2, sampleRate: .nan); preconditionFailure() }
        catch PracticeDSPTempoTransitionPlanningError.invalidSampleRate { }

        let blockingBackend = AW28FakeTempoBackend()
        let manualSleeper = AW28ManualTempoSleeper()
        let blockingGate = try PracticeDSPTransactionalApplicationGate(
            backend: blockingBackend,
            tempoTransitionPolicy: policy,
            tempoTransitionSleeper: manualSleeper
        )
        var candidate = PracticeDSPState(); candidate.tempoRatio = 0.5; candidate.scheduleGeneration = 1
        let task = Task { try await blockingGate.apply(candidate) }
        await manualSleeper.waitUntilEntered()
        var control = PracticeDSPState(); control.metronomeEnabled = true; control.scheduleGeneration = 1
        do { _ = try await blockingGate.commitControlOnly(control); preconditionFailure("expected transactionInFlight") }
        catch PracticeDSPTransactionError.transactionInFlight { }
        var competing = PracticeDSPState(); competing.tempoRatio = 1.25; competing.scheduleGeneration = 1
        do { _ = try await blockingGate.apply(competing); preconditionFailure("expected transactionInFlight") }
        catch PracticeDSPTransactionError.transactionInFlight { }
        await manualSleeper.release()
        let committed = try await task.value
        precondition(committed.tempoRatio == 0.5 && committed.scheduleGeneration == 1)
        let rampReceipt = await blockingGate.lastTempoTransitionReceipt()
        precondition(rampReceipt?.mode == .scheduledRamp)

        let fallbackBackend = AW28FakeTempoBackend(); fallbackBackend.configure(.fallback)
        let fallbackGate = try PracticeDSPTransactionalApplicationGate(backend: fallbackBackend, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        _ = try await fallbackGate.apply(candidate)
        let fallbackReceipt = await fallbackGate.lastTempoTransitionReceipt()
        precondition(fallbackReceipt?.mode == .immediateFallback && fallbackReceipt?.fallbackReason == .backendTransitionUnsupported)

        let forgedBackend = AW28FakeTempoBackend(); forgedBackend.configure(.forgedReceipt)
        let forgedGate = try PracticeDSPTransactionalApplicationGate(backend: forgedBackend, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        do { _ = try await forgedGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendRejectedRolledBack { }
        precondition(forgedBackend.current() == .init(tempoRatio: 1, pitchSemitones: 0))

        let finalizeBackend = AW28FakeTempoBackend(); finalizeBackend.configure(.finalizeFail)
        let finalizeGate = try PracticeDSPTransactionalApplicationGate(backend: finalizeBackend, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        do { _ = try await finalizeGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendRejectedRolledBack { }
        precondition(finalizeBackend.current() == .init(tempoRatio: 1, pitchSemitones: 0))
        let finalizeNeedsRecovery = await finalizeGate.requiresResynchronization(); precondition(!finalizeNeedsRecovery)

        let mismatchBackend = AW28FakeTempoBackend(); mismatchBackend.configure(.postFinalizeMismatch)
        let mismatchGate = try PracticeDSPTransactionalApplicationGate(backend: mismatchBackend, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        do { _ = try await mismatchGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendPostApplyMismatchRolledBack { }
        precondition(mismatchBackend.current() == .init(tempoRatio: 1, pitchSemitones: 0))

        let poisonBackend = AW28FakeTempoBackend(); poisonBackend.configure(.forgedCancelFail)
        let poisonGate = try PracticeDSPTransactionalApplicationGate(backend: poisonBackend, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        do { _ = try await poisonGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendRollbackFailed { }
        let poisoned = await poisonGate.requiresResynchronization(); precondition(poisoned)
        do { _ = try await poisonGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendDesynchronized { }

        let collector = Lane3DSPRuntimeTelemetryCollector()
        let telemetryNative = Lane3DSPTelemetryTransactionalBackend(backend: AW28FakeTempoBackend(), collector: collector)
        let telemetryNativeGate = try PracticeDSPTransactionalApplicationGate(backend: telemetryNative, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        _ = try await telemetryNativeGate.apply(candidate)
        let telemetryNativeReceipt = await telemetryNativeGate.lastTempoTransitionReceipt()
        precondition(telemetryNativeReceipt?.mode == .scheduledRamp)

        let telemetryPlain = Lane3DSPTelemetryTransactionalBackend(backend: AW28PlainBackend(), collector: collector)
        let telemetryFallbackGate = try PracticeDSPTransactionalApplicationGate(backend: telemetryPlain, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        _ = try await telemetryFallbackGate.apply(candidate)
        let telemetryFallbackReceipt = await telemetryFallbackGate.lastTempoTransitionReceipt()
        precondition(telemetryFallbackReceipt?.mode == .immediateFallback)
        precondition(telemetryFallbackReceipt?.fallbackReason == .backendTransitionUnsupported)

        let controllerBackend = AW28FakeTempoBackend()
        let project = ProjectID()
        let controller = try PracticeDSPProductionController(projectID: project, backend: controllerBackend, tempoTransitionSleeper: AW28NoOpTempoSleeper())
        let before = try await controller.snapshot(projectID: project)
        try await controller.setTempoRatio(0.5, projectID: project)
        let after = try await controller.snapshot(projectID: project)
        let controllerReceipt = try await controller.tempoTransitionReceipt(projectID: project)
        precondition(after.scheduleGeneration == before.scheduleGeneration + 1)
        precondition(after.tempoRatio == 0.5)
        precondition(after.pitchSemitones == before.pitchSemitones)
        precondition(controllerReceipt?.mode == .scheduledRamp)
        try await controller.setTempoRatio(0.5, projectID: project)
        let sameValue = try await controller.snapshot(projectID: project)
        let sameValueReceipt = try await controller.tempoTransitionReceipt(projectID: project)
        precondition(sameValue.scheduleGeneration == after.scheduleGeneration + 1)
        precondition(sameValueReceipt == nil)

        print("L3-AW28 tempo transition self-test PASS rampFrames=\(down.rampDurationFrames) reentrancy=blocked rollback=covered telemetryTransitionPreserved=true generationIncrementPreserved=true")
    }
}
