import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private actor A39MemoryStore: ProcessingLifecycleStateStoring {
    private var records: [ProjectID: DurableProcessingRecord] = [:]

    func load(projectID: ProjectID) async throws -> DurableProcessingRecord? { records[projectID] }
    func save(_ record: DurableProcessingRecord) async throws { records[record.projectID] = record }
    func remove(projectID: ProjectID) async throws { records.removeValue(forKey: projectID) }
    func seed(_ record: DurableProcessingRecord) { records[record.projectID] = record }
}

private actor A39Lifecycle: ProcessingLifecycleRelaunchRecovering {
    private var recoverCalls = 0
    private var previewCalls = 0
    private let recoveryResult: ProcessingRecoveryAction

    init(recoveryResult: ProcessingRecoveryAction) {
        self.recoveryResult = recoveryResult
    }

    func recoverAfterRelaunch(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        recoverCalls += 1
        return recoveryResult
    }

    func recoveryAction(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        previewCalls += 1
        return recoveryResult
    }

    func counts() -> (recover: Int, preview: Int) { (recoverCalls, previewCalls) }
}

private actor A39Resolver: ProcessingAmbiguousStartResolving {
    private var outcomes: [AmbiguousStartResolution]
    private var callCount = 0

    init(_ outcomes: [AmbiguousStartResolution]) { self.outcomes = outcomes }

    func resolve(projectID: ProjectID) async throws -> AmbiguousStartResolution {
        callCount += 1
        guard !outcomes.isEmpty else { return .notNeeded }
        return outcomes.removeFirst()
    }

    func calls() -> Int { callCount }
}

private func request(projectID: ProjectID) -> SeparationRequest {
    SeparationRequest(
        projectID: projectID,
        asset: LocalAudioAsset(
            id: AssetID(),
            relativePath: "imports/a39.wav",
            mediaKind: .audio,
            durationSeconds: 120
        ),
        requestedRoles: [.vocals, .drums],
        qualityProfile: "standard"
    )
}

private func record(
    projectID: ProjectID,
    state: DurableProcessingState,
    jobID: ProcessingJobID? = nil
) -> DurableProcessingRecord {
    DurableProcessingRecord(
        projectID: projectID,
        request: request(projectID: projectID),
        generationID: UUID(),
        jobID: jobID,
        state: state,
        lastSnapshot: nil,
        retryCount: 0,
        retryable: true,
        stableErrorCode: state == .cancellationRequested ? "PROC_CANCEL_REQUESTED_DURING_START" : nil
    )
}

private func testCancelDuringStartWithoutStableResolverFailsClosed() async throws {
    let project = ProjectID()
    let store = A39MemoryStore()
    await store.seed(record(projectID: project, state: .cancellationRequested))
    let lifecycle = A39Lifecycle(recoveryResult: .reconnect(jobID: ProcessingJobID()))
    let recovery = ProcessingCrashSafeRelaunchRecovery(lifecycle: lifecycle, stateStore: store)

    let action = try await recovery.recover(projectID: project)
    check(action == .ambiguousStart, "unbound cancel-start must surface ambiguity")
    let calls = await lifecycle.counts()
    check(calls.recover == 0, "generic lifecycle path must not receive an unbound cancellation")
}

private func testStillAmbiguousDoesNotDelegateToGenericLifecycle() async throws {
    let project = ProjectID()
    let store = A39MemoryStore()
    await store.seed(record(projectID: project, state: .starting))
    let lifecycle = A39Lifecycle(recoveryResult: .reconnect(jobID: ProcessingJobID()))
    let resolver = A39Resolver([.stillAmbiguous(stableErrorCode: "PROC_NETWORK_TIMEOUT")])
    let recovery = ProcessingCrashSafeRelaunchRecovery(
        lifecycle: lifecycle,
        stateStore: store,
        ambiguousStartResolver: resolver
    )

    let action = try await recovery.recover(projectID: project)
    check(action == .ambiguousStart, "network ambiguity remains fail-closed")
    let resolverCalls = await resolver.calls()
    let lifecycleCalls = await lifecycle.counts()
    check(resolverCalls == 1, "resolver called exactly once")
    check(lifecycleCalls.recover == 0, "no generic reconnect without durable binding")
}

private func testSuccessfulRebindReturnsCanonicalLifecycleDecision() async throws {
    let project = ProjectID(), job = ProcessingJobID()
    let store = A39MemoryStore()
    await store.seed(record(projectID: project, state: .startAmbiguous))
    let lifecycle = A39Lifecycle(recoveryResult: .reconnect(jobID: job))
    let resolver = A39Resolver([.rebound(jobID: job)])
    let recovery = ProcessingCrashSafeRelaunchRecovery(
        lifecycle: lifecycle,
        stateStore: store,
        ambiguousStartResolver: resolver
    )

    let action = try await recovery.recover(projectID: project)
    check(action == .reconnect(jobID: job), "rebound must hand control back to canonical lifecycle")
    let lifecycleCalls = await lifecycle.counts()
    check(lifecycleCalls.recover == 1, "canonical lifecycle called after successful rebind")
}

private func testRecoveredCancellationDelegatesTerminalState() async throws {
    let project = ProjectID(), job = ProcessingJobID()
    let store = A39MemoryStore()
    await store.seed(record(projectID: project, state: .cancellationRequested))
    let lifecycle = A39Lifecycle(recoveryResult: .retryRequired(stableErrorCode: "PROC_CANCELLED_AFTER_IDEMPOTENT_REBIND"))
    let resolver = A39Resolver([.cancellationCompleted(jobID: job)])
    let recovery = ProcessingCrashSafeRelaunchRecovery(
        lifecycle: lifecycle,
        stateStore: store,
        ambiguousStartResolver: resolver
    )

    let action = try await recovery.recover(projectID: project)
    check(
        action == .retryRequired(stableErrorCode: "PROC_CANCELLED_AFTER_IDEMPOTENT_REBIND"),
        "rebound cancellation terminal state must remain canonical"
    )
}

private func testBoundCancellationBypassesAmbiguousResolver() async throws {
    let project = ProjectID(), job = ProcessingJobID()
    let store = A39MemoryStore()
    await store.seed(record(projectID: project, state: .cancellationRequested, jobID: job))
    let lifecycle = A39Lifecycle(recoveryResult: .reconnect(jobID: job))
    let resolver = A39Resolver([.notNeeded])
    let recovery = ProcessingCrashSafeRelaunchRecovery(
        lifecycle: lifecycle,
        stateStore: store,
        ambiguousStartResolver: resolver
    )

    let action = try await recovery.recover(projectID: project)
    check(action == .reconnect(jobID: job), "bound cancellation uses normal reconnect path")
    let resolverCalls = await resolver.calls()
    check(resolverCalls == 0, "resolver must not replay a known job binding")
}

private func testPreviewIsNonMutatingAndSurfacesAmbiguity() async throws {
    let project = ProjectID()
    let store = A39MemoryStore()
    await store.seed(record(projectID: project, state: .cancellationRequested))
    let lifecycle = A39Lifecycle(recoveryResult: .none)
    let resolver = A39Resolver([.notNeeded])
    let recovery = ProcessingCrashSafeRelaunchRecovery(
        lifecycle: lifecycle,
        stateStore: store,
        ambiguousStartResolver: resolver
    )

    let action = try await recovery.recoveryAction(projectID: project)
    check(action == .ambiguousStart, "preview exposes ambiguity before a missing-binding failure")
    let resolverCalls = await resolver.calls()
    let lifecycleCalls = await lifecycle.counts()
    check(resolverCalls == 0, "preview must never invoke remote start resolution")
    check(lifecycleCalls.preview == 0, "preview must not enter generic missing-binding path")
}

private func testMissingStateIsNoop() async throws {
    let project = ProjectID()
    let store = A39MemoryStore()
    let lifecycle = A39Lifecycle(recoveryResult: .reconnect(jobID: ProcessingJobID()))
    let recovery = ProcessingCrashSafeRelaunchRecovery(lifecycle: lifecycle, stateStore: store)
    let action = try await recovery.recover(projectID: project)
    check(action == .none, "missing durable state is a no-op")
}

@main
private struct Main {
    static func main() async throws {
        try await testCancelDuringStartWithoutStableResolverFailsClosed()
        try await testStillAmbiguousDoesNotDelegateToGenericLifecycle()
        try await testSuccessfulRebindReturnsCanonicalLifecycleDecision()
        try await testRecoveredCancellationDelegatesTerminalState()
        try await testBoundCancellationBypassesAmbiguousResolver()
        try await testPreviewIsNonMutatingAndSurfacesAmbiguity()
        try await testMissingStateIsNoop()
        print("L1_A39_SELF_TEST_PASS scenarios=7")
    }
}
