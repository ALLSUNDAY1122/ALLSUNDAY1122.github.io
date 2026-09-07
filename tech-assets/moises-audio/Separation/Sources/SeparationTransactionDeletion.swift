import Foundation

extension SeparationOutputAssurance {
    /// Discard a not-yet-committed transaction without deleting a previously committed project result.
    /// A job-specific backup is authoritative evidence that `final` was moved aside by this transaction.
    /// Without a backup, `final` is removed only if it exactly matches this prepared transaction's hashes.
    func discardPreparedTransactionForDeletion(_ ledger: SeparationRunLedger) throws {
        guard ledger.state == .prepared else {
            throw failure("SEP_DELETE_PREPARED_STATE_INVALID", false)
        }
        let projectID = ledger.manifest.projectID
        let jobID = ledger.manifest.jobID
        let final = finalDirectory(projectID: projectID)
        let backup = backupDirectory(projectID: projectID, jobID: jobID)
        let expected = try expectedCommitFiles(ledger)

        do {
            if fileManager.fileExists(atPath: backup.path) {
                // `backup` belongs to this job's promotion attempt. Any current `final` is the
                // uncommitted candidate and must not win over the protected previous result.
                if fileManager.fileExists(atPath: final.path) {
                    try fileManager.removeItem(at: final)
                }
                try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: backup, to: final)
            } else if try directoryMatchesExpectedCommitSet(final, expected: expected) {
                // No prior final was displaced; this exact-hash final is an uncommitted candidate.
                try fileManager.removeItem(at: final)
            }
        } catch let domain as DomainFailure {
            throw domain
        } catch {
            throw failure("SEP_DELETE_PREPARED_ROLLBACK_FAILED", true)
        }

        try cleanupTransactionScratch(projectID: projectID, jobID: jobID, includeStaging: true)
    }
}
