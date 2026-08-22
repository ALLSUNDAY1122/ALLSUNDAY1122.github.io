import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private func failureCode(_ error: Error) -> String {
    guard let failure = error as? DomainFailure else { return "NON_DOMAIN_FAILURE" }
    switch failure {
    case .processingFailed(let code, _): return code
    case .cancelled: return "CANCELLED"
    default: return String(describing: failure)
    }
}

private actor MemoryLifecycleStore: ProcessingLifecycleStateStoring {
    private var records: [ProjectID: DurableProcessingRecord] = [:]

    func load(projectID: ProjectID) async throws -> DurableProcessingRecord? { records[projectID] }
    func save(_ record: DurableProcessingRecord) async throws { records[record.projectID] = record }
    func remove(projectID: ProjectID) async throws { records.removeValue(forKey: projectID) }
}

private actor MockOutputTransaction: ProcessingOutputTransacting {
    private var begins = 0
    private var commits = 0
    private var rollbacks = 0
    private var validations = 0

    func begin(projectID: ProjectID, generationID: UUID) async throws { begins += 1 }
    func validateFinalArtifacts(_ artifacts: [StemArtifact], projectID: ProjectID) async throws {
        validations += 1
        guard !artifacts.isEmpty, artifacts.allSatisfy({ $0.projectID == projectID }) else {
            throw DomainFailure.processingFailed(code: "TEST_INVALID_ARTIFACT", retryable: false)
        }
    }
    func commit(projectID: ProjectID, generationID: UUID) async throws { commits += 1 }
    func rollback(projectID: ProjectID, generationID: UUID) async throws { rollbacks += 1 }

    func counts() -> (Int, Int, Int, Int) { (begins, commits, rollbacks, validations) }
}

private actor MockProjectPersistence: ProjectPersisting {
    private var processing: [ProjectID: ProcessingSnapshot] = [:]
    private var stems: [ProjectID: [StemArtifact]] = [:]
    private var failRecordStemsOnce = false
    private var stemWrites = 0

    func createProject(source: LocalAudioAsset) async throws -> ProjectID { ProjectID() }
    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {
        processing[projectID] = snapshot
    }
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {
        stemWrites += 1
        if failRecordStemsOnce {
            failRecordStemsOnce = false
            throw DomainFailure.processingFailed(code: "TEST_DB_WRITE_FAILED", retryable: true)
        }
        self.stems[projectID] = stems
    }

    func failNextStemWrite() { failRecordStemsOnce = true }
    func stemWriteCount() -> Int { stemWrites }
    func savedStems(projectID: ProjectID) -> [StemArtifact]? { stems[projectID] }
}

private actor MockProvider: SourceSeparationProviding {
    private var startCountValue = 0
    private var resultCountValue = 0
    private var cancelCountValue = 0
    private var snapshots: [ProcessingSnapshot] = []
    private var resultArtifacts: [StemArtifact] = []
    private var startFailure: DomainFailure?
    private let jobID: ProcessingJobID

    init(jobID: ProcessingJobID = ProcessingJobID()) { self.jobID = jobID }

    func start(_ request: SeparationRequest) async throws -> ProcessingJobID {
        startCountValue += 1
        if let startFailure { throw startFailure }
        return jobID
    }

    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot {
        guard jobID == self.jobID else {
            throw DomainFailure.processingFailed(code: "TEST_JOB_MISMATCH", retryable: false)
        }
        if !snapshots.isEmpty { return snapshots.removeFirst() }
        return ProcessingSnapshot(jobID: jobID, phase: .separating, fractionComplete: 0.5, retryable: true)
    }

    func result(jobID: ProcessingJobID) async throws -> [StemArtifact] {
        resultCountValue += 1
        return resultArtifacts
    }

    func cancel(jobID: ProcessingJobID) async { cancelCountValue += 1 }

    func setSnapshots(_ values: [ProcessingSnapshot]) { snapshots = values }
    func setResult(_ values: [StemArtifact]) { resultArtifacts = values }
    func setStartFailure(_ value: DomainFailure?) { startFailure = value }
    func counts() -> (start: Int, result: Int, cancel: Int) {
        (startCountValue, resultCountValue, cancelCountValue)
    }
}

private func request(projectID: ProjectID, roles: Set<StemRole> = [.vocals, .drums]) -> SeparationRequest {
    SeparationRequest(
        projectID: projectID,
        asset: LocalAudioAsset(id: AssetID(), relativePath: "imports/song.wav", mediaKind: .audio, durationSeconds: 120),
        requestedRoles: roles,
        qualityProfile: "standard"
    )
}

private func artifacts(projectID: ProjectID, roles: [StemRole]) -> [StemArtifact] {
    roles.map { role in
        StemArtifact(
            id: StemID(),
            projectID: projectID,
            role: role,
            relativePath: "separation-stems/\(projectID.rawValue.uuidString)/\(role.rawValue).wav",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 44_100 * 10
        )
    }
}

private func testStartIsLocallyIdempotent() async throws {
    let projectID = ProjectID()
    let provider = MockProvider()
    let persistence = MockProjectPersistence()
    let store = MemoryLifecycleStore()
    let output = MockOutputTransaction()
    let coordinator = ProcessingLifecycleCoordinator(
        provider: provider,
        projectPersistence: persistence,
        stateStore: store,
        outputTransaction: output
    )
    let req = request(projectID: projectID)
    let first = try await coordinator.startOrReconnect(req)
    let second = try await coordinator.startOrReconnect(req)
    require(first == second, "same request must reconnect to same job")
    require(await provider.counts().start == 1, "provider.start must run exactly once")
}

private func testProgressRegressionRejected() async throws {
    let projectID = ProjectID()
    let provider = MockProvider()
    let persistence = MockProjectPersistence()
    let store = MemoryLifecycleStore()
    let output = MockOutputTransaction()
    let coordinator = ProcessingLifecycleCoordinator(provider: provider, projectPersistence: persistence, stateStore: store, outputTransaction: output)
    let req = request(projectID: projectID)
    let jobID = try await coordinator.startOrReconnect(req)
    await provider.setSnapshots([
        ProcessingSnapshot(jobID: jobID, phase: .separating, fractionComplete: 0.6, retryable: true),
        ProcessingSnapshot(jobID: jobID, phase: .separating, fractionComplete: 0.5, retryable: true)
    ])
    _ = try await coordinator.poll(projectID: projectID)
    do {
        _ = try await coordinator.poll(projectID: projectID)
        fatalError("progress regression must fail")
    } catch {
        require(failureCode(error) == "PROC_PROGRESS_REGRESSION", "unexpected regression error")
    }
}

private func testCancelRollsBackAfterProviderConfirmation() async throws {
    let projectID = ProjectID()
    let provider = MockProvider()
    let persistence = MockProjectPersistence()
    let store = MemoryLifecycleStore()
    let output = MockOutputTransaction()
    let coordinator = ProcessingLifecycleCoordinator(provider: provider, projectPersistence: persistence, stateStore: store, outputTransaction: output)
    let req = request(projectID: projectID)
    let jobID = try await coordinator.startOrReconnect(req)
    await provider.setSnapshots([
        ProcessingSnapshot(jobID: jobID, phase: .cancelled, fractionComplete: 0.4, retryable: true, stableErrorCode: "USER_CANCEL")
    ])
    try await coordinator.requestCancel(projectID: projectID)
    let terminal = try await coordinator.poll(projectID: projectID)
    require(terminal.phase == .cancelled, "cancel must become terminal")
    let counts = await output.counts()
    require(counts.2 == 1, "cancelled job must rollback output transaction")
    require(await provider.counts().cancel == 1, "provider cancel must be sent once")
}

private func testAmbiguousStartRequiresExplicitRetry() async throws {
    let projectID = ProjectID()
    let provider = MockProvider()
    await provider.setStartFailure(.networkTimeout)
    let persistence = MockProjectPersistence()
    let store = MemoryLifecycleStore()
    let output = MockOutputTransaction()
    let coordinator = ProcessingLifecycleCoordinator(provider: provider, projectPersistence: persistence, stateStore: store, outputTransaction: output)
    let req = request(projectID: projectID)

    do {
        _ = try await coordinator.startOrReconnect(req)
        fatalError("network timeout start must fail")
    } catch {
        require(failureCode(error) == "PROC_NETWORK_TIMEOUT", "unexpected ambiguous-start code")
    }
    require(try await coordinator.recoveryAction(projectID: projectID) == .ambiguousStart, "ambiguous start must survive relaunch")

    do {
        _ = try await coordinator.retry(req)
        fatalError("ambiguous start must not auto retry")
    } catch {
        require(failureCode(error) == "PROC_AMBIGUOUS_RETRY_REQUIRES_CONFIRMATION", "retry confirmation gate missing")
    }

    await provider.setStartFailure(nil)
    _ = try await coordinator.retry(req, allowPotentialDuplicateStart: true)
    require(await provider.counts().start == 2, "explicit retry should create exactly one new start attempt")
}

private func testResultPersistenceResumesWithoutRefetch() async throws {
    let projectID = ProjectID()
    let provider = MockProvider()
    let persistence = MockProjectPersistence()
    let store = MemoryLifecycleStore()
    let output = MockOutputTransaction()
    let coordinator = ProcessingLifecycleCoordinator(provider: provider, projectPersistence: persistence, stateStore: store, outputTransaction: output)
    let req = request(projectID: projectID)
    let jobID = try await coordinator.startOrReconnect(req)
    let stems = artifacts(projectID: projectID, roles: [.vocals, .drums])
    await provider.setResult(stems)
    await provider.setSnapshots([
        ProcessingSnapshot(jobID: jobID, phase: .ready, fractionComplete: 1, retryable: false)
    ])
    await persistence.failNextStemWrite()

    do {
        _ = try await coordinator.finish(projectID: projectID)
        fatalError("first DB write is expected to fail")
    } catch {
        require(failureCode(error) == "TEST_DB_WRITE_FAILED", "unexpected staged persistence failure")
    }
    require(try await store.load(projectID: projectID)?.state == .resultStaged, "failed DB write must preserve resultStaged")
    require(await provider.counts().result == 1, "provider result should have been fetched once")

    let relaunched = ProcessingLifecycleCoordinator(provider: provider, projectPersistence: persistence, stateStore: store, outputTransaction: output)
    _ = try await relaunched.recoverAfterRelaunch(projectID: projectID)
    require(try await store.load(projectID: projectID)?.state == .completed, "relaunch must finish staged result")
    require(await provider.counts().result == 1, "relaunch must not refetch already staged result")
    require(await persistence.stemWriteCount() == 2, "idempotent DB write should be retried once")
    require(await persistence.savedStems(projectID: projectID)?.count == 2, "stems must be persisted")
}

private func testFileRollbackRestoresPreviousStemSet() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("moi-proc-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let projectID = ProjectID()
    let generationID = UUID()
    let final = root.appendingPathComponent("separation-stems/\(projectID.rawValue.uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: final, withIntermediateDirectories: true)
    let vocals = final.appendingPathComponent("vocals.wav")
    try Data("OLD".utf8).write(to: vocals)

    let transaction = FileProcessingOutputTransaction(appDataRoot: root)
    try await transaction.begin(projectID: projectID, generationID: generationID)
    try Data("NEW".utf8).write(to: vocals)
    try Data("PARTIAL".utf8).write(to: final.appendingPathComponent("drums.wav"))
    try await transaction.rollback(projectID: projectID, generationID: generationID)

    require(String(data: try Data(contentsOf: vocals), encoding: .utf8) == "OLD", "rollback must restore previous stem bytes")
    require(!FileManager.default.fileExists(atPath: final.appendingPathComponent("drums.wav").path), "partial new stem must be removed")
}

private func testInterruptedBackupPreparationNeverDeletesLiveStems() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("moi-proc-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let projectID = ProjectID()
    let generationID = UUID()
    let final = root.appendingPathComponent("separation-stems/\(projectID.rawValue.uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: final, withIntermediateDirectories: true)
    let vocals = final.appendingPathComponent("vocals.wav")
    try Data("LIVE".utf8).write(to: vocals)

    let partial = root
        .appendingPathComponent("processing-backups/\(projectID.rawValue.uuidString)/\(generationID.uuidString)/previous", isDirectory: true)
    try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
    try Data("PARTIAL_BACKUP".utf8).write(to: partial.appendingPathComponent("vocals.wav"))

    let transaction = FileProcessingOutputTransaction(appDataRoot: root)
    try await transaction.rollback(projectID: projectID, generationID: generationID)
    require(String(data: try Data(contentsOf: vocals), encoding: .utf8) == "LIVE", "markerless partial backup must not replace live outputs")
}

@main
private struct MOIProc001SelfTest {
    static func main() async throws {
        try await testStartIsLocallyIdempotent()
        try await testProgressRegressionRejected()
        try await testCancelRollsBackAfterProviderConfirmation()
        try await testAmbiguousStartRequiresExplicitRetry()
        try await testResultPersistenceResumesWithoutRefetch()
        try await testFileRollbackRestoresPreviousStemSet()
        try await testInterruptedBackupPreparationNeverDeletesLiveStems()
        print("MOI_PROC_001_SELF_TEST_PASS")
    }
}
