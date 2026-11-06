import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
private func failureCode(_ error: Error) -> String {
    guard let failure = error as? DomainFailure else { return "NON_DOMAIN_FAILURE" }
    switch failure { case .processingFailed(let code, _): return code; case .cancelled: return "CANCELLED"; default: return String(describing: failure) }
}
private actor MemoryLifecycleStore: ProcessingLifecycleStateStoring {
    private var records: [ProjectID: DurableProcessingRecord] = [:]
    func load(projectID: ProjectID) async throws -> DurableProcessingRecord? { records[projectID] }
    func save(_ record: DurableProcessingRecord) async throws { records[record.projectID] = record }
    func remove(projectID: ProjectID) async throws { records.removeValue(forKey: projectID) }
}
private actor MockOutputTransaction: ProcessingOutputTransacting {
    private var begins=0, commits=0, rollbacks=0, validations=0
    func begin(projectID: ProjectID, generationID: UUID) async throws { begins += 1 }
    func validateFinalArtifacts(_ artifacts:[StemArtifact], projectID:ProjectID) async throws { validations += 1; guard !artifacts.isEmpty, artifacts.allSatisfy({$0.projectID==projectID}) else { throw DomainFailure.processingFailed(code:"TEST_INVALID_ARTIFACT",retryable:false) } }
    func commit(projectID:ProjectID,generationID:UUID) async throws { commits += 1 }
    func rollback(projectID:ProjectID,generationID:UUID) async throws { rollbacks += 1 }
    func counts() -> (Int,Int,Int,Int) { (begins,commits,rollbacks,validations) }
}
private actor MockProjectPersistence: ProjectPersisting {
    private var stems:[ProjectID:[StemArtifact]] = [:]; private var failRecordStemsOnce=false; private var stemWrites=0
    func createProject(source:LocalAudioAsset) async throws -> ProjectID { ProjectID() }
    func recordProcessing(projectID:ProjectID,snapshot:ProcessingSnapshot) async throws {}
    func recordStems(projectID:ProjectID,stems:[StemArtifact]) async throws { stemWrites += 1; if failRecordStemsOnce { failRecordStemsOnce=false; throw DomainFailure.processingFailed(code:"TEST_DB_WRITE_FAILED",retryable:true) }; self.stems[projectID]=stems }
    func failNextStemWrite(){ failRecordStemsOnce=true }
    func stemWriteCount()->Int{stemWrites}
    func savedStems(projectID:ProjectID)->[StemArtifact]?{stems[projectID]}
}
private actor MockProvider: SourceSeparationProviding {
    private var startCountValue=0,resultCountValue=0,cancelCountValue=0; private var snapshots:[ProcessingSnapshot]=[]; private var resultArtifacts:[StemArtifact]=[]; private var startFailure:DomainFailure?; private let jobID:ProcessingJobID
    init(jobID:ProcessingJobID=ProcessingJobID()){self.jobID=jobID}
    func start(_ request:SeparationRequest) async throws -> ProcessingJobID { startCountValue += 1; if let startFailure { throw startFailure }; return jobID }
    func snapshot(jobID:ProcessingJobID) async throws -> ProcessingSnapshot { guard jobID==self.jobID else { throw DomainFailure.processingFailed(code:"TEST_JOB_MISMATCH",retryable:false) }; if !snapshots.isEmpty { return snapshots.removeFirst() }; return ProcessingSnapshot(jobID:jobID,phase:.separating,fractionComplete:0.5,retryable:true) }
    func result(jobID:ProcessingJobID) async throws -> [StemArtifact] { resultCountValue += 1; return resultArtifacts }
    func cancel(jobID:ProcessingJobID) async { cancelCountValue += 1 }
    func setSnapshots(_ v:[ProcessingSnapshot]){snapshots=v}; func setResult(_ v:[StemArtifact]){resultArtifacts=v}; func setStartFailure(_ v:DomainFailure?){startFailure=v}; func counts()->(start:Int,result:Int,cancel:Int){(startCountValue,resultCountValue,cancelCountValue)}
}
private func request(projectID:ProjectID,roles:Set<StemRole>=[.vocals,.drums])->SeparationRequest { SeparationRequest(projectID:projectID,asset:LocalAudioAsset(id:AssetID(),relativePath:"imports/song.wav",mediaKind:.audio,durationSeconds:120),requestedRoles:roles,qualityProfile:"standard") }
private func artifacts(projectID:ProjectID,roles:[StemRole])->[StemArtifact]{ roles.map{ role in StemArtifact(id:StemID(),projectID:projectID,role:role,relativePath:"separation-stems/\(projectID.rawValue.uuidString)/\(role.rawValue).wav",sampleRate:44100,channels:2,frameCount:441000) } }

private func testStartIsLocallyIdempotent() async throws {
    let p=ProjectID(), provider=MockProvider(), pers=MockProjectPersistence(), store=MemoryLifecycleStore(), out=MockOutputTransaction()
    let c=ProcessingLifecycleCoordinator(provider:provider,projectPersistence:pers,stateStore:store,outputTransaction:out)
    let r=request(projectID:p)
    let a=try await c.startOrReconnect(r), b=try await c.startOrReconnect(r)
    let counts=await provider.counts()
    require(a==b,"same job"); require(counts.start==1,"start once")
}
private func testProgressRegressionRejected() async throws {
    let p=ProjectID(), provider=MockProvider(), pers=MockProjectPersistence(), store=MemoryLifecycleStore(), out=MockOutputTransaction()
    let c=ProcessingLifecycleCoordinator(provider:provider,projectPersistence:pers,stateStore:store,outputTransaction:out)
    let j=try await c.startOrReconnect(request(projectID:p))
    await provider.setSnapshots([ProcessingSnapshot(jobID:j,phase:.separating,fractionComplete:0.6,retryable:true),ProcessingSnapshot(jobID:j,phase:.separating,fractionComplete:0.5,retryable:true)])
    _=try await c.poll(projectID:p)
    do { _=try await c.poll(projectID:p); fatalError("must fail") } catch { require(failureCode(error)=="PROC_PROGRESS_REGRESSION","regression code") }
}
private func testCancelRollsBackAfterProviderConfirmation() async throws {
    let p=ProjectID(), provider=MockProvider(), pers=MockProjectPersistence(), store=MemoryLifecycleStore(), out=MockOutputTransaction()
    let c=ProcessingLifecycleCoordinator(provider:provider,projectPersistence:pers,stateStore:store,outputTransaction:out)
    let j=try await c.startOrReconnect(request(projectID:p))
    await provider.setSnapshots([ProcessingSnapshot(jobID:j,phase:.cancelled,fractionComplete:0.4,retryable:true,stableErrorCode:"USER_CANCEL")])
    try await c.requestCancel(projectID:p)
    let t=try await c.poll(projectID:p)
    let outCounts=await out.counts(), providerCounts=await provider.counts()
    require(t.phase == .cancelled,"terminal cancel"); require(outCounts.2==1,"rollback once"); require(providerCounts.cancel==1,"cancel once")
}
private func testAmbiguousStartRequiresExplicitRetry() async throws {
    let p=ProjectID(), provider=MockProvider(); await provider.setStartFailure(.networkTimeout)
    let pers=MockProjectPersistence(), store=MemoryLifecycleStore(), out=MockOutputTransaction()
    let c=ProcessingLifecycleCoordinator(provider:provider,projectPersistence:pers,stateStore:store,outputTransaction:out)
    let r=request(projectID:p)
    do { _=try await c.startOrReconnect(r); fatalError("must fail") } catch { require(failureCode(error)=="PROC_NETWORK_TIMEOUT","timeout") }
    let action=try await c.recoveryAction(projectID:p); require(action == .ambiguousStart,"ambiguous")
    do { _=try await c.retry(r); fatalError("must gate") } catch { require(failureCode(error)=="PROC_AMBIGUOUS_RETRY_REQUIRES_CONFIRMATION","gate") }
    await provider.setStartFailure(nil); _=try await c.retry(r,allowPotentialDuplicateStart:true)
    let counts=await provider.counts(); require(counts.start==2,"explicit retry")
}
private func testResultPersistenceResumesWithoutRefetch() async throws {
    let p=ProjectID(), provider=MockProvider(), pers=MockProjectPersistence(), store=MemoryLifecycleStore(), out=MockOutputTransaction()
    let c=ProcessingLifecycleCoordinator(provider:provider,projectPersistence:pers,stateStore:store,outputTransaction:out)
    let j=try await c.startOrReconnect(request(projectID:p)); let s=artifacts(projectID:p,roles:[.vocals,.drums])
    await provider.setResult(s); await provider.setSnapshots([ProcessingSnapshot(jobID:j,phase:.ready,fractionComplete:1,retryable:false)]); await pers.failNextStemWrite()
    do { _=try await c.finish(projectID:p); fatalError("db fail expected") } catch { require(failureCode(error)=="TEST_DB_WRITE_FAILED","db code") }
    let staged=try await store.load(projectID:p); let before=await provider.counts()
    require(staged?.state == .resultStaged,"staged"); require(before.result==1,"result once")
    let r=ProcessingLifecycleCoordinator(provider:provider,projectPersistence:pers,stateStore:store,outputTransaction:out); _=try await r.recoverAfterRelaunch(projectID:p)
    let completed=try await store.load(projectID:p); let after=await provider.counts(); let writes=await pers.stemWriteCount(); let saved=await pers.savedStems(projectID:p)
    require(completed?.state == .completed,"completed"); require(after.result==1,"no refetch"); require(writes==2,"write retry"); require(saved?.count==2,"saved")
}
private func testFileRollbackRestoresPreviousStemSet() async throws {
    let fm=FileManager.default, root=fm.temporaryDirectory.appendingPathComponent("moi-proc-\(UUID().uuidString)",isDirectory:true); defer{try? fm.removeItem(at:root)}
    try fm.createDirectory(at:root,withIntermediateDirectories:true); let p=ProjectID(), g=UUID(), final=root.appendingPathComponent("separation-stems/\(p.rawValue.uuidString)",isDirectory:true)
    try fm.createDirectory(at:final,withIntermediateDirectories:true); let v=final.appendingPathComponent("vocals.wav"); try Data("OLD".utf8).write(to:v)
    let tx=FileProcessingOutputTransaction(appDataRoot:root); try await tx.begin(projectID:p,generationID:g); try Data("NEW".utf8).write(to:v); try Data("PARTIAL".utf8).write(to:final.appendingPathComponent("drums.wav")); try await tx.rollback(projectID:p,generationID:g)
    let restored=String(data:try Data(contentsOf:v),encoding:.utf8); require(restored=="OLD","restore"); require(!fm.fileExists(atPath:final.appendingPathComponent("drums.wav").path),"remove partial")
}
private func testInterruptedBackupPreparationNeverDeletesLiveStems() async throws {
    let fm=FileManager.default, root=fm.temporaryDirectory.appendingPathComponent("moi-proc-\(UUID().uuidString)",isDirectory:true); defer{try? fm.removeItem(at:root)}
    try fm.createDirectory(at:root,withIntermediateDirectories:true); let p=ProjectID(), g=UUID(), final=root.appendingPathComponent("separation-stems/\(p.rawValue.uuidString)",isDirectory:true)
    try fm.createDirectory(at:final,withIntermediateDirectories:true); let v=final.appendingPathComponent("vocals.wav"); try Data("LIVE".utf8).write(to:v)
    let partial=root.appendingPathComponent("processing-backups/\(p.rawValue.uuidString)/\(g.uuidString)/previous",isDirectory:true); try fm.createDirectory(at:partial,withIntermediateDirectories:true); try Data("PARTIAL_BACKUP".utf8).write(to:partial.appendingPathComponent("vocals.wav"))
    let tx=FileProcessingOutputTransaction(appDataRoot:root); try await tx.rollback(projectID:p,generationID:g)
    let live=String(data:try Data(contentsOf:v),encoding:.utf8); require(live=="LIVE","live preserved")
}

@main private struct Main { static func main() async throws { try await testStartIsLocallyIdempotent(); try await testProgressRegressionRejected(); try await testCancelRollsBackAfterProviderConfirmation(); try await testAmbiguousStartRequiresExplicitRetry(); try await testResultPersistenceResumesWithoutRefetch(); try await testFileRollbackRestoresPreviousStemSet(); try await testInterruptedBackupPreparationNeverDeletesLiveStems(); print("MOI_PROC_001_SELF_TEST_PASS") } }
