import Foundation

enum SeparationCommitJournalPhase: String, Codable, Sendable {
    case assemblingIncoming
    case incomingVerified
    case promotionReady
    case finalPromoted
}

struct SeparationCommitJournal: Codable, Sendable {
    let schemaVersion: Int
    let projectID: String
    let jobID: String
    let phase: SeparationCommitJournalPhase
    let expectedSHA256ByFilename: [String: String]
    let createdAtEpochSeconds: Double
    let updatedAtEpochSeconds: Double

    init(
        schemaVersion: Int = 1,
        projectID: String,
        jobID: String,
        phase: SeparationCommitJournalPhase,
        expectedSHA256ByFilename: [String: String],
        createdAtEpochSeconds: Double,
        updatedAtEpochSeconds: Double
    ) {
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.jobID = jobID
        self.phase = phase
        self.expectedSHA256ByFilename = expectedSHA256ByFilename
        self.createdAtEpochSeconds = createdAtEpochSeconds
        self.updatedAtEpochSeconds = updatedAtEpochSeconds
    }

    func advanced(to phase: SeparationCommitJournalPhase, at epochSeconds: Double) -> SeparationCommitJournal {
        SeparationCommitJournal(
            schemaVersion: schemaVersion,
            projectID: projectID,
            jobID: jobID,
            phase: phase,
            expectedSHA256ByFilename: expectedSHA256ByFilename,
            createdAtEpochSeconds: createdAtEpochSeconds,
            updatedAtEpochSeconds: epochSeconds
        )
    }
}

extension SeparationOutputAssurance {
    func expectedCommitFiles(_ ledger: SeparationRunLedger) throws -> [String: String] {
        guard ledger.state == .prepared || ledger.state == .committed,
              !ledger.verifiedOutputs.isEmpty,
              Set(ledger.verifiedOutputs.map(\.role)) == ledger.manifest.requestedRoles else {
            throw failure("SEP_COMMIT_EXPECTED_SET_INVALID", false)
        }
        var expected: [String: String] = [:]
        for item in ledger.verifiedOutputs {
            let name = item.role.rawValue + ".wav"
            guard expected[name] == nil, isSHA256(item.sha256) else {
                throw failure("SEP_COMMIT_EXPECTED_SET_INVALID", false)
            }
            expected[name] = normalizeSHA256(item.sha256)
        }
        return expected
    }

    func commitJournalURL(projectID: ProjectID, jobID: ProcessingJobID) -> URL {
        appDataRoot.appendingPathComponent("separation-commit-journal", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString + "-" + jobID.rawValue.uuidString + ".json")
    }

    func loadCommitJournal(projectID: ProjectID, jobID: ProcessingJobID) throws -> SeparationCommitJournal? {
        let url = commitJournalURL(projectID: projectID, jobID: jobID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let journal = try JSONDecoder().decode(SeparationCommitJournal.self, from: Data(contentsOf: url))
            guard journal.schemaVersion == 1,
                  journal.projectID == projectID.rawValue.uuidString,
                  journal.jobID == jobID.rawValue.uuidString,
                  !journal.expectedSHA256ByFilename.isEmpty,
                  journal.createdAtEpochSeconds.isFinite,
                  journal.updatedAtEpochSeconds.isFinite,
                  journal.updatedAtEpochSeconds >= journal.createdAtEpochSeconds else {
                throw failure("SEP_COMMIT_JOURNAL_CORRUPT", false)
            }
            for (name, hash) in journal.expectedSHA256ByFilename {
                guard !name.isEmpty, !name.contains("/"), isSHA256(hash) else {
                    throw failure("SEP_COMMIT_JOURNAL_CORRUPT", false)
                }
            }
            return journal
        } catch let domain as DomainFailure {
            throw domain
        } catch {
            throw failure("SEP_COMMIT_JOURNAL_CORRUPT", false)
        }
    }

    func saveCommitJournal(_ journal: SeparationCommitJournal, projectID: ProjectID, jobID: ProcessingJobID) throws {
        let url = commitJournalURL(projectID: projectID, jobID: jobID)
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(journal).write(to: url, options: [.atomic])
        } catch {
            throw failure("SEP_COMMIT_JOURNAL_WRITE_FAILED", true)
        }
    }

    func validateCommitJournal(_ journal: SeparationCommitJournal, ledger: SeparationRunLedger) throws {
        guard journal.projectID == ledger.manifest.projectID.rawValue.uuidString,
              journal.jobID == ledger.manifest.jobID.rawValue.uuidString,
              journal.expectedSHA256ByFilename == (try expectedCommitFiles(ledger)) else {
            throw failure("SEP_COMMIT_JOURNAL_IDENTITY_MISMATCH", false)
        }
    }

    func makeCommitJournal(
        ledger: SeparationRunLedger,
        phase: SeparationCommitJournalPhase,
        createdAtEpochSeconds: Double? = nil
    ) throws -> SeparationCommitJournal {
        let timestamp = now().timeIntervalSince1970
        return SeparationCommitJournal(
            projectID: ledger.manifest.projectID.rawValue.uuidString,
            jobID: ledger.manifest.jobID.rawValue.uuidString,
            phase: phase,
            expectedSHA256ByFilename: try expectedCommitFiles(ledger),
            createdAtEpochSeconds: createdAtEpochSeconds ?? timestamp,
            updatedAtEpochSeconds: timestamp
        )
    }

    func directoryMatchesExpectedCommitSet(_ directory: URL, expected: [String: String]) throws -> Bool {
        guard !expected.isEmpty, fileManager.fileExists(atPath: directory.path) else { return false }
        let names: Set<String>
        do {
            names = Set(try fileManager.contentsOfDirectory(atPath: directory.path).filter { !$0.hasPrefix(".") })
        } catch {
            throw failure("SEP_COMMIT_DIRECTORY_READ_FAILED", true)
        }
        guard names == Set(expected.keys) else { return false }
        for (name, hash) in expected {
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            if attributes?[.type] as? FileAttributeType == .typeSymbolicLink { return false }
            guard try SHA256FileHasher.hash(url: url) == hash else { return false }
        }
        return true
    }

    func requireExpectedCommitSet(_ directory: URL, expected: [String: String], code: String) throws {
        guard try directoryMatchesExpectedCommitSet(directory, expected: expected) else {
            throw failure(code, false)
        }
    }

    func makeCommittedLedger(from prepared: SeparationRunLedger, finalDirectory: URL) throws -> SeparationRunLedger {
        guard prepared.state == .prepared else { throw failure("SEP_COMMIT_STATE_INVALID", false) }
        let expected = try expectedCommitFiles(prepared)
        try requireExpectedCommitSet(finalDirectory, expected: expected, code: "SEP_COMMIT_FINAL_SET_MISMATCH")
        let artifacts = try prepared.verifiedOutputs.sorted(by: { $0.role.rawValue < $1.role.rawValue }).map { item in
            let finalURL = finalDirectory.appendingPathComponent(item.role.rawValue + ".wav")
            return StemArtifact(
                id: item.stemID,
                projectID: prepared.manifest.projectID,
                role: item.role,
                relativePath: try relativePath(finalURL),
                sampleRate: item.sampleRate,
                channels: item.channels,
                frameCount: item.frameCount
            )
        }
        return SeparationRunLedger(
            state: .committed,
            manifest: prepared.manifest,
            verifiedOutputs: prepared.verifiedOutputs,
            finalArtifacts: artifacts,
            preparedAt: prepared.preparedAt,
            committedAt: now()
        )
    }

    func cleanupTransactionScratch(projectID: ProjectID, jobID: ProcessingJobID, includeStaging: Bool) throws {
        var targets = [
            incomingDirectory(projectID: projectID, jobID: jobID),
            backupDirectory(projectID: projectID, jobID: jobID),
            commitJournalURL(projectID: projectID, jobID: jobID)
        ]
        if includeStaging { targets.append(stagingDirectory(projectID: projectID, jobID: jobID)) }
        do {
            for target in targets where fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
        } catch {
            throw failure("SEP_COMMIT_SCRATCH_CLEANUP_FAILED", true)
        }
    }

    func rollbackUncommittedFinal(projectID: ProjectID, jobID: ProcessingJobID) throws {
        let final = finalDirectory(projectID: projectID)
        let backup = backupDirectory(projectID: projectID, jobID: jobID)
        do {
            if fileManager.fileExists(atPath: backup.path) {
                if fileManager.fileExists(atPath: final.path) { try fileManager.removeItem(at: final) }
                try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: backup, to: final)
            } else if fileManager.fileExists(atPath: final.path) {
                try fileManager.removeItem(at: final)
            }
        } catch {
            throw failure("SEP_COMMIT_ROLLBACK_FAILED", true)
        }
    }

    @discardableResult
    func recoverAtomicCommit(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger? {
        let incoming = incomingDirectory(projectID: projectID, jobID: jobID)
        let final = finalDirectory(projectID: projectID)
        let backup = backupDirectory(projectID: projectID, jobID: jobID)
        let ledger = try await ledgerStore.load(projectID: projectID, jobID: jobID)

        // With no authoritative ledger, no new transaction can be published. Preserve an orphan
        // backup because it may be the only previous user result; otherwise remove all job-local
        // scratch, including stale staging that may contain downloaded audio from a crash before save.
        guard let ledger else {
            if fileManager.fileExists(atPath: backup.path) {
                throw failure("SEP_COMMIT_RECOVERY_LEDGER_MISSING", false)
            }
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
            return nil
        }

        let journal = try loadCommitJournal(projectID: projectID, jobID: jobID)

        if ledger.state == .deleted {
            if fileManager.fileExists(atPath: backup.path) {
                throw failure("SEP_COMMIT_RECOVERY_DELETED_WITH_BACKUP", false)
            }
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
            return ledger
        }

        let expected = try expectedCommitFiles(ledger)
        if let journal { try validateCommitJournal(journal, ledger: ledger) }

        if ledger.state == .committed {
            guard try directoryMatchesExpectedCommitSet(final, expected: expected) else {
                throw failure("SEP_COMMIT_COMMITTED_FINAL_MISMATCH", false)
            }
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
            return ledger
        }

        guard ledger.state == .prepared else {
            throw failure("SEP_COMMIT_STATE_INVALID", false)
        }

        if try directoryMatchesExpectedCommitSet(final, expected: expected) {
            let committed = try makeCommittedLedger(from: ledger, finalDirectory: final)
            try await ledgerStore.save(committed)
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
            return committed
        }

        if try directoryMatchesExpectedCommitSet(incoming, expected: expected) {
            if fileManager.fileExists(atPath: backup.path), fileManager.fileExists(atPath: final.path) {
                throw failure("SEP_COMMIT_RECOVERY_AMBIGUOUS_FINALS", false)
            }
            do {
                try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: final.path) {
                    guard !fileManager.fileExists(atPath: backup.path) else {
                        throw failure("SEP_COMMIT_RECOVERY_AMBIGUOUS_FINALS", false)
                    }
                    try fileManager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fileManager.moveItem(at: final, to: backup)
                }
                try fileManager.moveItem(at: incoming, to: final)
            } catch let domain as DomainFailure {
                throw domain
            } catch {
                if !fileManager.fileExists(atPath: final.path), fileManager.fileExists(atPath: backup.path) {
                    try? fileManager.moveItem(at: backup, to: final)
                }
                throw failure("SEP_COMMIT_RECOVERY_PROMOTION_FAILED", true)
            }
            guard try directoryMatchesExpectedCommitSet(final, expected: expected) else {
                try rollbackUncommittedFinal(projectID: projectID, jobID: jobID)
                throw failure("SEP_COMMIT_RECOVERY_FINAL_MISMATCH", false)
            }
            let committed = try makeCommittedLedger(from: ledger, finalDirectory: final)
            try await ledgerStore.save(committed)
            try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
            return committed
        }

        // No complete new set exists. A previous protected final wins because the new ledger has not
        // been committed. Partial incoming/journal state is scratch; verified staging is kept so a
        // later commit can rebuild incoming without re-downloading provider outputs.
        if fileManager.fileExists(atPath: backup.path) {
            do {
                if fileManager.fileExists(atPath: final.path) { try fileManager.removeItem(at: final) }
                try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: backup, to: final)
            } catch {
                throw failure("SEP_COMMIT_ROLLBACK_FAILED", true)
            }
        }
        do {
            if fileManager.fileExists(atPath: incoming.path) { try fileManager.removeItem(at: incoming) }
            let journalURL = commitJournalURL(projectID: projectID, jobID: jobID)
            if fileManager.fileExists(atPath: journalURL.path) { try fileManager.removeItem(at: journalURL) }
        } catch {
            throw failure("SEP_COMMIT_SCRATCH_CLEANUP_FAILED", true)
        }
        return ledger
    }
}
