import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private actor MemoryStore: ProcessingLifecycleStateStoring {
    var records: [ProjectID: DurableProcessingRecord] = [:]
    var failSaveCode: String?
    func load(projectID: ProjectID) async throws -> DurableProcessingRecord? { records[projectID] }
    func save(_ record: DurableProcessingRecord) async throws {
        if let code = failSaveCode { failSaveCode = nil; throw DomainFailure.processingFailed(code: code, retryable: true) }
        records[record.projectID] = record
    }
    func remove(projectID: ProjectID) async throws { records.removeValue(forKey: projectID) }
    func seed(_ record: DurableProcessingRecord) { records[record.projectID] = record }
    func failNextSave(_ code: String) { failSaveCode = code }
}

private actor RecordingProvider: SourceSeparationProviding {
    var cancelled: [ProcessingJobID] = []
    func start(_ request: SeparationRequest) async throws -> ProcessingJobID { ProcessingJobID() }
    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot { ProcessingSnapshot(jobID: jobID, phase: .separating, fractionComplete: 0.5, retryable: true) }
    func result(jobID: ProcessingJobID) async throws -> [StemArtifact] { [] }
    func cancel(jobID: ProcessingJobID) async { cancelled.append(jobID) }
    func cancelCount() -> Int { cancelled.count }
}

private actor ScriptedStableStarter: StableIdempotentSeparationStarting {
    enum Step: Sendable { case success(ProcessingJobID); case failure(DomainFailure) }
    var steps: [Step]
    var keys: [String] = []
    init(_ steps: [Step]) { self.steps = steps }
    func start(_ request: SeparationRequest, idempotencyKey: String) async throws -> ProcessingJobID {
        keys.append(idempotencyKey)
        guard !steps.isEmpty else { throw DomainFailure.providerUnavailable }
        switch steps.removeFirst() {
        case .success(let job): return job
        case .failure(let failure): throw failure
        }
    }
    func recordedKeys() -> [String] { keys }
}

private actor RecordingPersistence: ProjectPersisting {
    var snapshots: [ProcessingSnapshot] = []
    var failNextProcessing = false
    func createProject(source: LocalAudioAsset) async throws -> ProjectID { ProjectID() }
    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {
        if failNextProcessing { failNextProcessing = false; throw DomainFailure.processingFailed(code: "TEST_PERSISTENCE_DOWN", retryable: true) }
        snapshots.append(snapshot)
    }
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {}
    func failNext() { failNextProcessing = true }
    func count() -> Int { snapshots.count }
}

private actor RecordingOutput: ProcessingOutputTransacting {
    var rollbacks = 0
    var failRollback = false
    func begin(projectID: ProjectID, generationID: UUID) async throws {}
    func validateFinalArtifacts(_ artifacts: [StemArtifact], projectID: ProjectID) async throws {}
    func commit(projectID: ProjectID, generationID: UUID) async throws {}
    func rollback(projectID: ProjectID, generationID: UUID) async throws {
        rollbacks += 1
        if failRollback { failRollback = false; throw DomainFailure.insufficientStorage }
    }
    func failNextRollback() { failRollback = true }
    func rollbackCount() -> Int { rollbacks }
}

private func makeRequest(projectID: ProjectID) -> SeparationRequest {
    SeparationRequest(
        projectID: projectID,
        asset: LocalAudioAsset(id: AssetID(), relativePath: "imports/song.wav", mediaKind: .audio, durationSeconds: 180),
        requestedRoles: [.vocals, .drums],
        qualityProfile: "standard"
    )
}

private func makeRecord(projectID: ProjectID, generationID: UUID = UUID(), state: DurableProcessingState) -> DurableProcessingRecord {
    DurableProcessingRecord(
        projectID: projectID,
        request: makeRequest(projectID: projectID),
        generationID: generationID,
        jobID: nil,
        state: state,
        lastSnapshot: nil,
        retryCount: 0,
        retryable: true,
        stableErrorCode: state == .startAmbiguous ? "PROC_NETWORK_TIMEOUT" : nil
    )
}

private func testStableKeyDeterminism() {
    let generation = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let a = StableProcessingIdempotencyKey.value(generationID: generation)
    let b = StableProcessingIdempotencyKey.value(generationID: generation)
    let c = StableProcessingIdempotencyKey.value(generationID: UUID())
    check(a == "proc-11111111-2222-3333-4444-555555555555", "canonical key")
    check(a == b, "same generation must reuse same key")
    check(a != c, "different generation must rotate key")
}

private func testAmbiguousNetworkRetryUsesSameKeyAndRebinds() async throws {
    let project = ProjectID(), generation = UUID(), job = ProcessingJobID()
    let store = MemoryStore(); await store.seed(makeRecord(projectID: project, generationID: generation, state: .startAmbiguous))
    let provider = RecordingProvider()
    let stable = ScriptedStableStarter([.failure(.networkTimeout), .success(job)])
    let persistence = RecordingPersistence(), output = RecordingOutput()
    let resolver = ProcessingAmbiguousStartResolver(provider: provider, stableStarter: stable, stateStore: store, projectPersistence: persistence, outputTransaction: output)

    let first = try await resolver.resolve(projectID: project)
    check(first == .stillAmbiguous(stableErrorCode: "PROC_NETWORK_TIMEOUT"), "network loss stays ambiguous but safe")
    let middle = try await store.load(projectID: project)
    check(middle?.state == .startAmbiguous && middle?.jobID == nil && middle?.retryable == true, "durable ambiguity retained")

    let second = try await resolver.resolve(projectID: project)
    check(second == .rebound(jobID: job), "second call rebinds")
    let final = try await store.load(projectID: project)
    check(final?.state == .active && final?.jobID == job && final?.lastSnapshot?.phase == .queued, "active binding persisted")
    let keys = await stable.recordedKeys()
    check(keys.count == 2 && keys[0] == keys[1], "ambiguous retries must reuse exactly one key")
    let persistenceCount = await persistence.count()
    check(persistenceCount == 1, "queued snapshot persisted once after rebind")
}

private func testCancellationIntentSurvivesAmbiguousStart() async throws {
    let project = ProjectID(), generation = UUID(), job = ProcessingJobID()
    let store = MemoryStore(); await store.seed(makeRecord(projectID: project, generationID: generation, state: .cancellationRequested))
    let provider = RecordingProvider(), stable = ScriptedStableStarter([.success(job)])
    let persistence = RecordingPersistence(), output = RecordingOutput()
    let resolver = ProcessingAmbiguousStartResolver(provider: provider, stableStarter: stable, stateStore: store, projectPersistence: persistence, outputTransaction: output)

    let resolution = try await resolver.resolve(projectID: project)
    check(resolution == .cancellationCompleted(jobID: job), "rebound job must be cancelled")
    let final = try await store.load(projectID: project)
    check(final?.state == .cancelled && final?.jobID == job, "cancelled state bound to provider job")
    let cancelCount = await provider.cancelCount()
    let rollbackCount = await output.rollbackCount()
    let persistenceCount = await persistence.count()
    check(cancelCount == 1, "provider cancel called")
    check(rollbackCount == 1, "partial output rolled back")
    check(persistenceCount == 1, "cancel terminal snapshot persisted")
}

private func testDefinitiveAccessDeniedFailsClosed() async throws {
    let project = ProjectID(), generation = UUID()
    let store = MemoryStore(); await store.seed(makeRecord(projectID: project, generationID: generation, state: .startAmbiguous))
    let provider = RecordingProvider(), stable = ScriptedStableStarter([.failure(.accessDenied)])
    let persistence = RecordingPersistence(), output = RecordingOutput()
    let resolver = ProcessingAmbiguousStartResolver(provider: provider, stableStarter: stable, stateStore: store, projectPersistence: persistence, outputTransaction: output)
    do {
        _ = try await resolver.resolve(projectID: project)
        fatalError("access denied must fail")
    } catch DomainFailure.processingFailed(let code, let retryable) {
        check(code == "PROC_ACCESS_DENIED" && retryable == false, "definitive classification")
    }
    let final = try await store.load(projectID: project)
    check(final?.state == .failed && final?.retryable == false, "failed durable state")
    let rollbackCount = await output.rollbackCount()
    check(rollbackCount == 1, "output rolled back on definitive start failure")
}

private func testProjectPersistenceFailureKeepsDurableJobBinding() async throws {
    let project = ProjectID(), generation = UUID(), job = ProcessingJobID()
    let store = MemoryStore(); await store.seed(makeRecord(projectID: project, generationID: generation, state: .startAmbiguous))
    let provider = RecordingProvider(), stable = ScriptedStableStarter([.success(job)])
    let persistence = RecordingPersistence(); await persistence.failNext()
    let output = RecordingOutput()
    let resolver = ProcessingAmbiguousStartResolver(provider: provider, stableStarter: stable, stateStore: store, projectPersistence: persistence, outputTransaction: output)
    do {
        _ = try await resolver.resolve(projectID: project)
        fatalError("persistence failure expected")
    } catch DomainFailure.processingFailed(let code, _) {
        check(code == "TEST_PERSISTENCE_DOWN", "injected persistence failure surfaced")
    }
    let final = try await store.load(projectID: project)
    check(final?.state == .active && final?.jobID == job, "durable binding must survive secondary persistence failure")
    let cancelCount = await provider.cancelCount()
    check(cancelCount == 0, "known provider job must not be cancelled")
}

private func testStateStoreFailureAfterProviderSuccessPreservesAmbiguity() async throws {
    let project = ProjectID(), generation = UUID(), job = ProcessingJobID()
    let store = MemoryStore(); await store.seed(makeRecord(projectID: project, generationID: generation, state: .startAmbiguous)); await store.failNextSave("TEST_STORAGE_WRITE")
    let provider = RecordingProvider(), stable = ScriptedStableStarter([.success(job)])
    let persistence = RecordingPersistence(), output = RecordingOutput()
    let resolver = ProcessingAmbiguousStartResolver(provider: provider, stableStarter: stable, stateStore: store, projectPersistence: persistence, outputTransaction: output)
    do {
        _ = try await resolver.resolve(projectID: project)
        fatalError("state store failure expected")
    } catch DomainFailure.processingFailed(let code, _) {
        check(code == "TEST_STORAGE_WRITE", "injected storage failure surfaced")
    }
    let persisted = try await store.load(projectID: project)
    check(persisted?.state == .startAmbiguous && persisted?.jobID == nil, "old durable ambiguity remains")
    let keys = await stable.recordedKeys()
    check(keys.count == 1, "provider was started exactly once")
}

private func testRollbackFailureDoesNotEraseCancelledBinding() async throws {
    let project = ProjectID(), generation = UUID(), job = ProcessingJobID()
    let store = MemoryStore(); await store.seed(makeRecord(projectID: project, generationID: generation, state: .cancellationRequested))
    let provider = RecordingProvider(), stable = ScriptedStableStarter([.success(job)])
    let persistence = RecordingPersistence(), output = RecordingOutput(); await output.failNextRollback()
    let resolver = ProcessingAmbiguousStartResolver(provider: provider, stableStarter: stable, stateStore: store, projectPersistence: persistence, outputTransaction: output)
    do {
        _ = try await resolver.resolve(projectID: project)
        fatalError("rollback failure expected")
    } catch DomainFailure.insufficientStorage {
        // injected storage pressure after durable cancelled state
    }
    let final = try await store.load(projectID: project)
    check(final?.state == .cancellationRequested && final?.jobID == job, "cleanup failure keeps recoverable cancel intent and job binding")
    let cancelCount = await provider.cancelCount()
    check(cancelCount == 1, "remote cancel still sent")
}

@main
private struct Main {
    static func main() async throws {
        testStableKeyDeterminism()
        try await testAmbiguousNetworkRetryUsesSameKeyAndRebinds()
        try await testCancellationIntentSurvivesAmbiguousStart()
        try await testDefinitiveAccessDeniedFailsClosed()
        try await testProjectPersistenceFailureKeepsDurableJobBinding()
        try await testStateStoreFailureAfterProviderSuccessPreservesAmbiguity()
        try await testRollbackFailureDoesNotEraseCancelledBinding()
        print("L1_M02_SELF_TEST_PASS scenarios=7")
    }
}
