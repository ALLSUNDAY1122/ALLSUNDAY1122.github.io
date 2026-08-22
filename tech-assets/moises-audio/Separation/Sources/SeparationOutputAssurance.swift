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
        let staging = stagingDirectory(projectID: manifest.projectID, jobID: manifest.jobID)
        do {
            if fileManager.fileExists(atPath: staging.path) { try fileManager.removeItem(at: staging) }
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

    /// Commit only after the entire result set has passed prepare(). Existing final output is backed
    /// up during the directory swap. `recoverInterruptedCommit` repairs a crash between rename steps.
    @discardableResult
    public func commit(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger {
        guard let prepared = try await ledgerStore.load(projectID: projectID, jobID: jobID) else {
            throw DomainFailure.processingFailed(code: "SEP_LEDGER_MISSING", retryable: false)
        }
        if prepared.state == .committed { return prepared }
        guard prepared.state == .prepared else {
            throw DomainFailure.processingFailed(code: "SEP_COMMIT_STATE_INVALID", retryable: false)
        }
        try validateManifest(prepared.manifest)
        try verifyPreparedFiles(prepared)

        let incoming = incomingDirectory(projectID: projectID, jobID: jobID)
        let final = finalDirectory(projectID: projectID)
        let backup = backupDirectory(projectID: projectID, jobID: jobID)
        do {
            for url in [incoming, backup] where fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            try fileManager.createDirectory(at: incoming, withIntermediateDirectories: true)
            for item in prepared.verifiedOutputs {
                let source = try resolveRelativePath(item.stagedRelativePath)
                let destination = incoming.appendingPathComponent(item.role.rawValue + ".wav")
                try fileManager.copyItem(at: source, to: destination)
                guard try SHA256FileHasher.hash(url: destination) == item.sha256 else {
                    throw DomainFailure.processingFailed(code: "SEP_COMMIT_COPY_HASH_MISMATCH", retryable: false)
                }
            }

            try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: final.path) {
                try fileManager.moveItem(at: final, to: backup)
            }
            do {
                try fileManager.moveItem(at: incoming, to: final)
            } catch {
                if !fileManager.fileExists(atPath: final.path), fileManager.fileExists(atPath: backup.path) {
                    try? fileManager.moveItem(at: backup, to: final)
                }
                throw error
            }

            var artifacts: [StemArtifact] = []
            for item in prepared.verifiedOutputs.sorted(by: { $0.role.rawValue < $1.role.rawValue }) {
                let finalURL = final.appendingPathComponent(item.role.rawValue + ".wav")
                guard try SHA256FileHasher.hash(url: finalURL) == item.sha256 else {
                    throw DomainFailure.processingFailed(code: "SEP_COMMIT_FINAL_HASH_MISMATCH", retryable: false)
                }
                artifacts.append(
                    StemArtifact(
                        id: item.stemID,
                        projectID: projectID,
                        role: item.role,
                        relativePath: try relativePath(finalURL),
                        sampleRate: item.sampleRate,
                        channels: item.channels,
                        frameCount: item.frameCount
                    )
                )
            }

            let committed = SeparationRunLedger(
                state: .committed,
                manifest: prepared.manifest,
                verifiedOutputs: prepared.verifiedOutputs,
                finalArtifacts: artifacts,
                preparedAt: prepared.preparedAt,
                committedAt: now()
            )
            try await ledgerStore.save(committed)
            if fileManager.fileExists(atPath: backup.path) { try fileManager.removeItem(at: backup) }
            let staging = stagingDirectory(projectID: projectID, jobID: jobID)
            if fileManager.fileExists(atPath: staging.path) { try? fileManager.removeItem(at: staging) }
            return committed
        } catch let failure as DomainFailure {
            throw failure
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_COMMIT_FAILED", retryable: true)
        }
    }

    /// Crash repair for directory swap. If a backup exists and no final directory exists, restore it.
    /// If both exist, final is retained only when it matches the committed ledger; otherwise backup wins.
    public func recoverInterruptedCommit(projectID: ProjectID, jobID: ProcessingJobID) async throws {
        let final = finalDirectory(projectID: projectID)
        let backup = backupDirectory(projectID: projectID, jobID: jobID)
        guard fileManager.fileExists(atPath: backup.path) else { return }
        let ledger = try await ledgerStore.load(projectID: projectID, jobID: jobID)
        if !fileManager.fileExists(atPath: final.path) {
            try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: backup, to: final)
            return
        }
        if let ledger, ledger.state == .committed, (try? finalDirectoryMatches(ledger)) == true {
            try fileManager.removeItem(at: backup)
            return
        }
        try fileManager.removeItem(at: final)
        try fileManager.moveItem(at: backup, to: final)
    }

    /// Delete only files proven to belong to this committed run. If paths now contain a newer run,
    /// deletion fails closed instead of removing user data written after this ledger.
    @discardableResult
    public func deleteLocalRun(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger {
        guard let ledger = try await ledgerStore.load(projectID: projectID, jobID: jobID) else {
            throw DomainFailure.processingFailed(code: "SEP_LEDGER_MISSING", retryable: false)
        }
        if ledger.state == .deleted { return ledger }
        if ledger.state == .committed {
            guard try finalDirectoryMatches(ledger) else {
                throw DomainFailure.processingFailed(code: "SEP_DELETE_NEWER_RUN_PROTECTED", retryable: false)
            }
            let final = finalDirectory(projectID: projectID)
            if fileManager.fileExists(atPath: final.path) { try fileManager.removeItem(at: final) }
        }
        let staging = stagingDirectory(projectID: projectID, jobID: jobID)
        if fileManager.fileExists(atPath: staging.path) { try fileManager.removeItem(at: staging) }
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
