import Foundation

private enum AW25FakeError: Error { case begin, finalize, cancel }

private final class AW25FakeTransitionBackend: PracticeDSPPitchTransitionBackendApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var tempo: Double = 1
    private var pitch: Double = 0
    private var pendingPitch: Double?
    var beginShouldFail = false
    var finalizeShouldFail = false
    var cancelShouldFail = false
    var mismatchOnFinalize = false
    var beginCount = 0
    var finalizeCount = 0
    var cancelCount = 0

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        tempo = tempoRatio; pitch = pitchSemitones; pendingPitch = nil
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        lock.lock(); defer { lock.unlock() }
        return .init(tempoRatio: tempo, pitchSemitones: pitch)
    }

    func beginPitchTransition(tempoRatio: Double, fromPitchSemitones: Double, toPitchSemitones: Double, policy: PracticeDSPPitchTransitionPolicy) throws -> PracticeDSPPitchTransitionBackendReceipt {
        lock.lock(); defer { lock.unlock() }
        beginCount += 1
        if beginShouldFail { throw AW25FakeError.begin }
        let plan = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: fromPitchSemitones, toSemitones: toPitchSemitones, sampleRate: 48_000, policy: policy)
        tempo = tempoRatio
        if plan.mode == .immediate { pitch = toPitchSemitones }
        else { pendingPitch = toPitchSemitones }
        return .init(plan: plan)
    }

    func finalizePitchTransition(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        finalizeCount += 1
        if finalizeShouldFail { throw AW25FakeError.finalize }
        tempo = tempoRatio
        pitch = mismatchOnFinalize ? pitchSemitones + 1 : pitchSemitones
        pendingPitch = nil
    }

    func cancelPitchTransition(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        cancelCount += 1
        if cancelShouldFail { throw AW25FakeError.cancel }
        tempo = tempoRatio; pitch = pitchSemitones; pendingPitch = nil
    }
}

private final class AW25PlainBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private var tempo: Double = 1
    private var pitch: Double = 0
    func apply(tempoRatio: Double, pitchSemitones: Double) throws { tempo = tempoRatio; pitch = pitchSemitones }
    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot { .init(tempoRatio: tempo, pitchSemitones: pitch) }
}

private struct AW25NoOpSleeper: PracticeDSPPitchTransitionSleeping {
    func sleepIgnoringCancellation(nanoseconds: UInt64) async {}
}

private actor AW25ManualSleeper: PracticeDSPPitchTransitionSleeping {
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        entered = true
        let w = waiters; waiters.removeAll()
        for waiter in w { waiter.resume() }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() { releaseContinuation?.resume(); releaseContinuation = nil }
}

@main
struct L3AW25PitchTransitionSelfTest {
    static func main() async throws {
        let policy = PracticeDSPPitchTransitionPolicy.provisionalAppleInteractive
        let immediate = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: 0, toSemitones: 0.2, sampleRate: 48_000, policy: policy)
        precondition(immediate.mode == .immediate && immediate.rampDurationFrames == 0)
        let one = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: 0, toSemitones: 1, sampleRate: 48_000, policy: policy)
        precondition(one.mode == .scheduledRamp && one.rampDurationFrames == 384 && one.recommendedBarrierNanoseconds == 12_000_000)
        let six = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: 0, toSemitones: 6, sampleRate: 48_000, policy: policy)
        precondition(six.rampDurationFrames == 576 && six.recommendedBarrierNanoseconds == 16_000_000)
        let twelve = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: 0, toSemitones: 12, sampleRate: 48_000, policy: policy)
        precondition(twelve.rampDurationFrames == 1_152 && twelve.recommendedBarrierNanoseconds == 28_000_000)
        let capped = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: -24, toSemitones: 24, sampleRate: 192_000, policy: policy)
        precondition(capped.rampDurationFrames == 4_096)
        do { _ = try PracticeDSPPitchTransitionPlanner.makePlan(fromSemitones: 0, toSemitones: 1, sampleRate: .nan); preconditionFailure() }
        catch PracticeDSPPitchTransitionPlanningError.invalidSampleRate { }

        let backend = AW25FakeTransitionBackend()
        let gate = try PracticeDSPTransactionalApplicationGate(backend: backend, pitchTransitionPolicy: policy, pitchTransitionSleeper: AW25NoOpSleeper())
        var candidate = PracticeDSPState(); candidate.pitchSemitones = 6
        let committed = try await gate.apply(candidate)
        precondition(committed.pitchSemitones == 6)
        let receipt = await gate.lastPitchTransitionReceipt()
        precondition(receipt?.mode == .scheduledRamp && receipt?.toSemitones == 6 && receipt?.parityPromotionAllowed == false)

        let blockingBackend = AW25FakeTransitionBackend()
        let manualSleeper = AW25ManualSleeper()
        let blockingGate = try PracticeDSPTransactionalApplicationGate(backend: blockingBackend, pitchTransitionPolicy: policy, pitchTransitionSleeper: manualSleeper)
        var blockedCandidate = PracticeDSPState(); blockedCandidate.pitchSemitones = 12
        let transitionTask = Task { try await blockingGate.apply(blockedCandidate) }
        await manualSleeper.waitUntilEntered()
        var controlOnly = PracticeDSPState(); controlOnly.metronomeEnabled = true; controlOnly.scheduleGeneration = 1
        do { _ = try await blockingGate.commitControlOnly(controlOnly); preconditionFailure("expected transactionInFlight") }
        catch PracticeDSPTransactionError.transactionInFlight { }
        catch { preconditionFailure("unexpected error: \(error)") }
        await manualSleeper.release()
        let blockedResult = try await transitionTask.value
        precondition(blockedResult.pitchSemitones == 12)

        let beginFailureBackend = AW25FakeTransitionBackend(); beginFailureBackend.beginShouldFail = true
        let beginFailureGate = try PracticeDSPTransactionalApplicationGate(backend: beginFailureBackend, pitchTransitionSleeper: AW25NoOpSleeper())
        do { _ = try await beginFailureGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendRejectedRolledBack { }
        precondition(beginFailureBackend.cancelCount == 1)
        let beginNeedsRecovery = await beginFailureGate.requiresResynchronization(); precondition(!beginNeedsRecovery)

        let finalizeFailureBackend = AW25FakeTransitionBackend(); finalizeFailureBackend.finalizeShouldFail = true
        let finalizeFailureGate = try PracticeDSPTransactionalApplicationGate(backend: finalizeFailureBackend, pitchTransitionSleeper: AW25NoOpSleeper())
        do { _ = try await finalizeFailureGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendRejectedRolledBack { }
        precondition(finalizeFailureBackend.cancelCount == 1)
        let finalizeSnapshot = try finalizeFailureBackend.snapshotAppliedDSP(); precondition(finalizeSnapshot.pitchSemitones == 0)

        let mismatchBackend = AW25FakeTransitionBackend(); mismatchBackend.mismatchOnFinalize = true
        let mismatchGate = try PracticeDSPTransactionalApplicationGate(backend: mismatchBackend, pitchTransitionSleeper: AW25NoOpSleeper())
        do { _ = try await mismatchGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendPostApplyMismatchRolledBack { }
        precondition(mismatchBackend.cancelCount == 1)
        let mismatchSnapshot = try mismatchBackend.snapshotAppliedDSP(); precondition(mismatchSnapshot.pitchSemitones == 0)

        let poisonBackend = AW25FakeTransitionBackend(); poisonBackend.beginShouldFail = true; poisonBackend.cancelShouldFail = true
        let poisonGate = try PracticeDSPTransactionalApplicationGate(backend: poisonBackend, pitchTransitionSleeper: AW25NoOpSleeper())
        do { _ = try await poisonGate.apply(candidate); preconditionFailure() }
        catch PracticeDSPTransactionError.backendRollbackFailed { }
        let poisonNeedsRecovery = await poisonGate.requiresResynchronization(); precondition(poisonNeedsRecovery)

        let collector = Lane3DSPRuntimeTelemetryCollector()
        let wrappedNative = AW25FakeTransitionBackend()
        let telemetryWrapped = Lane3DSPTelemetryTransactionalBackend(backend: wrappedNative, collector: collector)
        let wrappedGate = try PracticeDSPTransactionalApplicationGate(backend: telemetryWrapped, pitchTransitionSleeper: AW25NoOpSleeper())
        _ = try await wrappedGate.apply(candidate)
        let wrappedReceipt = await wrappedGate.lastPitchTransitionReceipt()
        precondition(wrappedReceipt?.mode == .scheduledRamp)

        let plainWrapped = Lane3DSPTelemetryTransactionalBackend(backend: AW25PlainBackend(), collector: collector)
        let fallbackGate = try PracticeDSPTransactionalApplicationGate(backend: plainWrapped, pitchTransitionSleeper: AW25NoOpSleeper())
        _ = try await fallbackGate.apply(candidate)
        let fallbackReceipt = await fallbackGate.lastPitchTransitionReceipt()
        precondition(fallbackReceipt?.mode == .immediateFallback)
        precondition(fallbackReceipt?.fallbackReason == .backendTransitionUnsupported)

        let controllerBackend = AW25FakeTransitionBackend()
        let project = ProjectID()
        let controller = try PracticeDSPProductionController(projectID: project, backend: controllerBackend, pitchTransitionSleeper: AW25NoOpSleeper())
        let before = try await controller.snapshot(projectID: project)
        try await controller.setPitchSemitones(-7, projectID: project)
        let after = try await controller.snapshot(projectID: project)
        let controllerReceipt = try await controller.pitchTransitionReceipt(projectID: project)
        precondition(after.pitchSemitones == -7)
        precondition(after.tempoRatio == before.tempoRatio)
        precondition(after.scheduleGeneration == before.scheduleGeneration)
        precondition(controllerReceipt?.mode == .scheduledRamp)

        print("L3-AW25 pitch transition self-test PASS ramps=5 reentrancy=blocked failures=rolledBack telemetryTransitionPreserved=true generationPreserved=true")
    }
}
