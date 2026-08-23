import Foundation

actor A14FlakyLedgerStore: SeparationRunLedgerStoring {
    private var records: [String: SeparationRunLedger] = [:]
    private var failNextCommittedSave = false

    func load(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger? {
        records[projectID.rawValue.uuidString + ":" + jobID.rawValue.uuidString]
    }

    func save(_ ledger: SeparationRunLedger) async throws {
        if failNextCommittedSave, ledger.state == .committed {
            failNextCommittedSave = false
            throw DomainFailure.processingFailed(code: "A14_TEST_COMMITTED_LEDGER_SAVE_FAILED", retryable: true)
        }
        records[ledger.manifest.projectID.rawValue.uuidString + ":" + ledger.manifest.jobID.rawValue.uuidString] = ledger
    }

    func armCommittedSaveFailure() { failNextCommittedSave = true }
}

@MainActor
func a14Require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("A14 assertion failed: \(message)") }
}

@MainActor
func a14Expect(_ expected: String, _ operation: () async throws -> Void) async {
    do {
        try await operation()
        fatalError("A14 expected failure \(expected)")
    } catch {
        a14Require(failureCode(error) == expected, "expected \(expected), got \(failureCode(error))")
    }
}

func a14CopyPreparedSet(_ ledger: SeparationRunLedger, root: URL, destination: URL) throws {
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    for item in ledger.verifiedOutputs {
        let source = root.appendingPathComponent(item.stagedRelativePath)
        try FileManager.default.copyItem(at: source, to: destination.appendingPathComponent(item.role.rawValue + ".wav"))
    }
}

func a14WritePreviousFinal(_ directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("previous-project-result".utf8).write(to: directory.appendingPathComponent("previous.wav"))
}

func a14VisibleNames(_ directory: URL) -> Set<String> {
    Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
}

func a14Manifest(_ trusted: SeparationProviderRunManifest, expiresAt: Date) -> SeparationProviderRunManifest {
    let outputs = trusted.outputs.map { item in
        VendorStemOutputDescriptor(
            stemID: item.stemID,
            role: item.role,
            downloadURL: item.downloadURL,
            expiresAt: expiresAt,
            container: item.container,
            sampleRate: item.sampleRate,
            channels: item.channels,
            frameCount: item.frameCount,
            durationSeconds: item.durationSeconds,
            expectedByteCount: item.expectedByteCount,
            expectedSHA256: item.expectedSHA256
        )
    }
    return SeparationProviderRunManifest(
        schemaVersion: trusted.schemaVersion,
        projectID: trusted.projectID,
        jobID: trusted.jobID,
        providerID: trusted.providerID,
        providerKind: trusted.providerKind,
        modelName: trusted.modelName,
        modelVersion: trusted.modelVersion,
        qualityProfile: trusted.qualityProfile,
        requestedRoles: trusted.requestedRoles,
        outputs: outputs,
        cost: trusted.cost,
        retention: trusted.retention,
        uploadMilliseconds: trusted.uploadMilliseconds,
        queueMilliseconds: trusted.queueMilliseconds,
        inferenceMilliseconds: trusted.inferenceMilliseconds,
        downloadMilliseconds: trusted.downloadMilliseconds,
        generatedAt: trusted.generatedAt
    )
}

@main private struct L1A14AtomicTransactionSelfTest {
    static func main() async throws {
        try await happyPathExactSet()
        try await committedLedgerFailureRecovers()
        try await completeIncomingRecoversWithoutStaging()
        try await partialIncomingRestoresPreviousFinal()
        try await extraIncomingNeverPromotes()
        try await journalIdentityMismatchFailsClosed()
        try await backupWithoutLedgerIsProtected()
        try await committedFinalTamperFailsClosed()
        try await preparedLocalSetSurvivesVendorURLExpiry()
        try await expiredRemoteWithoutLocalSetFailsBeforeDownload()
        print("L1_A14_ATOMIC_TRANSACTION_SELF_TEST_PASS scenarios=10")
    }

    static func happyPathExactSet() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let prepared = try await f.assurance.prepare(f.manifest())
        let committed = try await f.assurance.commit(projectID: f.projectID, jobID: f.jobID)
        a14Require(committed.state == .committed, "happy path must commit")
        a14Require(Set(committed.finalArtifacts.map(\.role)) == prepared.manifest.requestedRoles, "all roles required")
        let final = await f.assurance.finalDirectory(projectID: f.projectID)
        a14Require(a14VisibleNames(final) == Set(["vocals.wav", "drums.wav"]), "exact final set")
    }

    static func committedLedgerFailureRecovers() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let store = A14FlakyLedgerStore()
        let assurance = SeparationOutputAssurance(
            appDataRoot: f.root,
            fetcher: f.fetcher,
            ledgerStore: store,
            minimumExpiryLeadSeconds: 30,
            now: { [now = f.now] in now }
        )
        _ = try await assurance.prepare(f.manifest())
        await store.armCommittedSaveFailure()
        await a14Expect("A14_TEST_COMMITTED_LEDGER_SAVE_FAILED") {
            _ = try await assurance.commit(projectID: f.projectID, jobID: f.jobID)
        }
        let stillPrepared = try await store.load(projectID: f.projectID, jobID: f.jobID)
        a14Require(stillPrepared?.state == .prepared, "failed ledger save cannot publish metadata")
        let recovered = try await assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        a14Require(recovered?.state == .committed, "relaunch must finish exact promoted set")
    }

    static func completeIncomingRecoversWithoutStaging() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let prepared = try await f.assurance.prepare(f.manifest())
        let incoming = await f.assurance.incomingDirectory(projectID: f.projectID, jobID: f.jobID)
        try a14CopyPreparedSet(prepared, root: f.root, destination: incoming)
        let staging = await f.assurance.stagingDirectory(projectID: f.projectID, jobID: f.jobID)
        try FileManager.default.removeItem(at: staging)
        let journal = try await f.assurance.makeCommitJournal(ledger: prepared, phase: .incomingVerified)
        try await f.assurance.saveCommitJournal(journal, projectID: f.projectID, jobID: f.jobID)
        let recovered = try await f.assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        a14Require(recovered?.state == .committed, "complete incoming hashes must recover without provider re-download")
    }

    static func partialIncomingRestoresPreviousFinal() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let prepared = try await f.assurance.prepare(f.manifest())
        let final = await f.assurance.finalDirectory(projectID: f.projectID)
        try a14WritePreviousFinal(final)
        let backup = await f.assurance.backupDirectory(projectID: f.projectID, jobID: f.jobID)
        try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: final, to: backup)
        let incoming = await f.assurance.incomingDirectory(projectID: f.projectID, jobID: f.jobID)
        try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)
        let item = prepared.verifiedOutputs[0]
        try FileManager.default.copyItem(
            at: f.root.appendingPathComponent(item.stagedRelativePath),
            to: incoming.appendingPathComponent(item.role.rawValue + ".wav")
        )
        let journal = try await f.assurance.makeCommitJournal(ledger: prepared, phase: .promotionReady)
        try await f.assurance.saveCommitJournal(journal, projectID: f.projectID, jobID: f.jobID)
        let recovered = try await f.assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        a14Require(recovered?.state == .prepared, "partial new set must remain uncommitted")
        a14Require(a14VisibleNames(final) == Set(["previous.wav"]), "previous final must be restored")
    }

    static func extraIncomingNeverPromotes() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let prepared = try await f.assurance.prepare(f.manifest())
        let incoming = await f.assurance.incomingDirectory(projectID: f.projectID, jobID: f.jobID)
        try a14CopyPreparedSet(prepared, root: f.root, destination: incoming)
        try Data("unexpected".utf8).write(to: incoming.appendingPathComponent("extra.wav"))
        let journal = try await f.assurance.makeCommitJournal(ledger: prepared, phase: .incomingVerified)
        try await f.assurance.saveCommitJournal(journal, projectID: f.projectID, jobID: f.jobID)
        let recovered = try await f.assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        a14Require(recovered?.state == .prepared, "extra file invalidates exact set")
        a14Require(!FileManager.default.fileExists(atPath: incoming.path), "invalid incoming must be stale-cleaned")
    }

    static func journalIdentityMismatchFailsClosed() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try await f.assurance.prepare(f.manifest())
        let bad = SeparationCommitJournal(
            projectID: f.projectID.rawValue.uuidString,
            jobID: f.jobID.rawValue.uuidString,
            phase: .incomingVerified,
            expectedSHA256ByFilename: ["vocals.wav": String(repeating: "0", count: 64)],
            createdAtEpochSeconds: 1,
            updatedAtEpochSeconds: 2
        )
        try await f.assurance.saveCommitJournal(bad, projectID: f.projectID, jobID: f.jobID)
        await a14Expect("SEP_COMMIT_JOURNAL_IDENTITY_MISMATCH") {
            _ = try await f.assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        }
    }

    static func backupWithoutLedgerIsProtected() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let emptyStore = MemoryLedgerStore()
        let assurance = SeparationOutputAssurance(appDataRoot: f.root, fetcher: f.fetcher, ledgerStore: emptyStore)
        let backup = await assurance.backupDirectory(projectID: f.projectID, jobID: f.jobID)
        try a14WritePreviousFinal(backup)
        await a14Expect("SEP_COMMIT_RECOVERY_LEDGER_MISSING") {
            _ = try await assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        }
        a14Require(FileManager.default.fileExists(atPath: backup.path), "orphan backup is user-data protection")
    }

    static func committedFinalTamperFailsClosed() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try await f.assurance.prepare(f.manifest())
        _ = try await f.assurance.commit(projectID: f.projectID, jobID: f.jobID)
        let final = await f.assurance.finalDirectory(projectID: f.projectID)
        try Data("tamper".utf8).write(to: final.appendingPathComponent("vocals.wav"))
        await a14Expect("SEP_COMMIT_COMMITTED_FINAL_MISMATCH") {
            _ = try await f.assurance.recoverInterruptedCommit(projectID: f.projectID, jobID: f.jobID)
        }
    }

    static func preparedLocalSetSurvivesVendorURLExpiry() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let trusted = f.manifest()
        _ = try await f.assurance.prepare(trusted)
        let expired = a14Manifest(trusted, expiresAt: f.now.addingTimeInterval(1))
        let provider = AssuredSeparationProvider(
            controller: ControllerStub(jobID: f.jobID),
            manifestProvider: ManifestProviderStub(expired),
            assurance: f.assurance,
            ledgerStore: f.store
        )
        let artifacts = try await provider.result(jobID: f.jobID)
        a14Require(Set(artifacts.map(\.role)) == trusted.requestedRoles, "verified local set must not depend on signed URL freshness")
    }

    static func expiredRemoteWithoutLocalSetFailsBeforeDownload() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let emptyStore = MemoryLedgerStore()
        let assurance = SeparationOutputAssurance(
            appDataRoot: f.root,
            fetcher: f.fetcher,
            ledgerStore: emptyStore,
            minimumExpiryLeadSeconds: 30,
            now: { [now = f.now] in now }
        )
        let expired = a14Manifest(f.manifest(), expiresAt: f.now.addingTimeInterval(1))
        let provider = AssuredSeparationProvider(
            controller: ControllerStub(jobID: f.jobID),
            manifestProvider: ManifestProviderStub(expired),
            assurance: assurance,
            ledgerStore: emptyStore
        )
        await a14Expect("SEP_OUTPUT_URL_EXPIRING") {
            _ = try await provider.result(jobID: f.jobID)
        }
        let fetchCount = await f.fetcher.count()
        a14Require(fetchCount == 0, "expired remote set must fail before download")
    }
}
