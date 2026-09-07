import Foundation

public actor SeparationOutputAssurance {
    let appDataRoot: URL
    let fetcher: any VendorOutputFetching
    let ledgerStore: any SeparationRunLedgerStoring
    let fileManager: FileManager
    let now: @Sendable () -> Date
    let minimumExpiryLeadSeconds: TimeInterval
    let durationToleranceSeconds: Double

    public init(
        appDataRoot: URL,
        fetcher: any VendorOutputFetching,
        ledgerStore: any SeparationRunLedgerStoring,
        fileManager: FileManager = .default,
        minimumExpiryLeadSeconds: TimeInterval = 30,
        durationToleranceSeconds: Double = 0.020,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appDataRoot = appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        self.fetcher = fetcher
        self.ledgerStore = ledgerStore
        self.fileManager = fileManager
        self.minimumExpiryLeadSeconds = minimumExpiryLeadSeconds
        self.durationToleranceSeconds = durationToleranceSeconds
        self.now = now
    }

    @discardableResult
    public func prepare(_ manifest: SeparationProviderRunManifest) async throws -> SeparationRunLedger {
        try validateManifest(manifest)
        try SeparationArtifactSetIntegrity.validate(manifest, durationToleranceSeconds: durationToleranceSeconds)
        let staging = stagingDirectory(projectID: manifest.projectID, jobID: manifest.jobID)
        do {
            // Stale job-owned staging is reclaimed before capacity is measured. This avoids false
            // insufficiency while still ensuring all new staging + one download temp + reserve fit.
            if fileManager.fileExists(atPath: staging.path) { try fileManager.removeItem(at: staging) }
            try requirePrepareStorage(manifest)
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

            var verified: [VerifiedSeparationOutput] = []
            verified.reserveCapacity(manifest.outputs.count)
            for output in manifest.outputs.sorted(by: { $0.role.rawValue < $1.role.rawValue }) {
                try ensureNotExpired(output)
                let downloaded = try await fetcher.download(output.downloadURL)
                try ensureNotExpired(output)
                let destination = staging.appendingPathComponent(output.role.rawValue + ".wav")
                try copyReplacing(source: downloaded, destination: destination)
                let inspected = try inspectWAV(destination)
                let size = try fileSize(destination)
                let digest = try SHA256FileHasher.hash(url: destination)
                try validateDownloaded(output: output, inspected: inspected, byteCount: size, sha256: digest)
                verified.append(
                    VerifiedSeparationOutput(
                        stemID: output.stemID,
                        role: output.role,
                        stagedRelativePath: try relativePath(destination),
                        sha256: digest,
                        byteCount: size,
                        sampleRate: Double(inspected.sampleRate),
                        channels: inspected.channels,
                        frameCount: inspected.frameCount,
                        durationSeconds: inspected.durationSeconds
                    )
                )
            }

            guard Set(verified.map(\.role)) == manifest.requestedRoles else {
                throw DomainFailure.processingFailed(code: "SEP_OUTPUT_ROLE_SET_MISMATCH", retryable: false)
            }
            let ledger = SeparationRunLedger(
                state: .prepared,
                manifest: manifest,
                verifiedOutputs: verified,
                preparedAt: now()
            )
            try await ledgerStore.save(ledger)
            return ledger
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Commit only after every required stem has passed prepare(). A durable journal binds the exact
    /// role->SHA set before any existing project result is touched. Project-visible metadata becomes
    /// committed only after the complete final directory has been hash-verified and the committed
    /// ledger is durably saved.
    @discardableResult
    public func commit(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger {
        if let recovered = try await recoverAtomicCommit(projectID: projectID, jobID: jobID), recovered.state == .committed {
            return recovered
        }
        guard let prepared = try await ledgerStore.load(projectID: projectID, jobID: jobID) else {
            throw DomainFailure.processingFailed(code: "SEP_LEDGER_MISSING", retryable: false)
        }
        if prepared.state == .committed { return prepared }
        guard prepared.state == .prepared else {
            throw DomainFailure.processingFailed(code: "SEP_COMMIT_STATE_INVALID", retryable: false)
        }
        try validateManifest(prepared.manifest, requireFreshOutputURLs: false)
        try SeparationArtifactSetIntegrity.validate(prepared.manifest, durationToleranceSeconds: durationToleranceSeconds)
        try verifyPreparedFiles(prepared)
        // A14 duplicates the complete staging set into incoming before rename promotion. Refuse to
        // touch an existing final unless that additional full-set copy plus reserve fits first.
        try requireCommitStorage(prepared)

        let expected = try expectedCommitFiles(prepared)
        let incoming = incomingDirectory(projectID: projectID, jobID: jobID)
        let final = finalDirectory(projectID: projectID)
        let backup = backupDirectory(projectID: projectID, jobID: jobID)
        let journalURL = commitJournalURL(projectID: projectID, jobID: jobID)

        do {
            if fileManager.fileExists(atPath: backup.path) {
                throw DomainFailure.processingFailed(code: "SEP_COMMIT_BACKUP_STILL_PRESENT", retryable: false)
            }
            for target in [incoming, journalURL] where fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.createDirectory(at: incoming, withIntermediateDirectories: true)

            var journal = try makeCommitJournal(ledger: prepared, phase: .assemblingIncoming)
            try saveCommitJournal(journal, projectID: projectID, jobID: jobID)

            for item in prepared.verifiedOutputs {
                let source = try resolveRelativePath(item.stagedRelativePath)
                let destination = incoming.appendingPathComponent(item.role.rawValue + ".wav")
                try fileManager.copyItem(at: source, to: destination)
                guard try SHA256FileHasher.hash(url: destination) == item.sha256 else {
                    throw DomainFailure.processingFailed(code: "SEP_COMMIT_COPY_HASH_MISMATCH", retryable: false)
                }
            }
            try requireExpectedCommitSet(incoming, expected: expected, code: "SEP_COMMIT_INCOMING_SET_MISMATCH")
            journal = journal.advanced(to: .incomingVerified, at: now().timeIntervalSince1970)
            try saveCommitJournal(journal, projectID: projectID, jobID: jobID)

            try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: final.path) {
                try fileManager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: final, to: backup)
            }
            journal = journal.advanced(to: .promotionReady, at: now().timeIntervalSince1970)
            try saveCommitJournal(journal, projectID: projectID, jobID: jobID)

            do {
                try fileManager.moveItem(at: incoming, to: final)
            } catch {
                if !fileManager.fileExists(atPath: final.path), fileManager.fileExists(atPath: backup.path) {
                    try? fileManager.moveItem(at: backup, to: final)
                }
                throw DomainFailure.processingFailed(code: "SEP_COMMIT_PROMOTION_FAILED", retryable: true)
            }
            journal = journal.advanced(to: .finalPromoted, at: now().timeIntervalSince1970)
            try saveCommitJournal(journal, projectID: projectID, jobID: jobID)

            guard try directoryMatchesExpectedCommitSet(final, expected: expected) else {
                try rollbackUncommittedFinal(projectID: projectID, jobID: jobID)
                throw DomainFailure.processingFailed(code: "SEP_COMMIT_FINAL_SET_MISMATCH", retryable: false)
            }

            let committed = try makeCommittedLedger(from: prepared, finalDirectory: final)
            try await ledgerStore.save(committed)
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
            return committed
        } catch let failure as DomainFailure {
            throw failure
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_COMMIT_FAILED", retryable: true)
        }
    }

    @discardableResult
    public func recoverInterruptedCommit(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger? {
        try await recoverAtomicCommit(projectID: projectID, jobID: jobID)
    }

    /// Delete only files proven to belong to this run. A prepared transaction never deletes a
    /// previously committed project result: if this job displaced one into its backup, that prior
    /// final is restored before all job-local staging/incoming/journal content is removed.
    @discardableResult
    public func deleteLocalRun(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger {
        guard let ledger = try await ledgerStore.load(projectID: projectID, jobID: jobID) else {
            throw DomainFailure.processingFailed(code: "SEP_LEDGER_MISSING", retryable: false)
        }
        if ledger.state == .deleted { return ledger }

        switch ledger.state {
        case .committed:
            guard try finalDirectoryMatches(ledger) else {
                throw DomainFailure.processingFailed(code: "SEP_DELETE_NEWER_RUN_PROTECTED", retryable: false)
            }
            let final = finalDirectory(projectID: projectID)
            if fileManager.fileExists(atPath: final.path) { try fileManager.removeItem(at: final) }
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
        case .prepared:
            try discardPreparedTransactionForDeletion(ledger)
        case .deleted:
            return ledger
        }

        let deleted = SeparationRunLedger(
            state: .deleted,
            manifest: ledger.manifest,
            verifiedOutputs: ledger.verifiedOutputs,
            finalArtifacts: ledger.finalArtifacts,
            preparedAt: ledger.preparedAt,
            committedAt: ledger.committedAt,
            deletedAt: now()
        )
        try await ledgerStore.save(deleted)
        return deleted
    }

    public func committedArtifacts(projectID: ProjectID, jobID: ProcessingJobID) async throws -> [StemArtifact] {
        guard let ledger = try await ledgerStore.load(projectID: projectID, jobID: jobID), ledger.state == .committed else {
            throw DomainFailure.processingFailed(code: "SEP_COMMITTED_LEDGER_MISSING", retryable: false)
        }
        guard try finalDirectoryMatches(ledger) else {
            throw DomainFailure.processingFailed(code: "SEP_COMMITTED_OUTPUT_CHANGED", retryable: false)
        }
        return ledger.finalArtifacts
    }
}
