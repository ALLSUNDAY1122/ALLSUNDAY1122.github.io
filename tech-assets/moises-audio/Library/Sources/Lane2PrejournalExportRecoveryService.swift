import Foundation

/// Production-facing composition seam for AW17/AW19 pre-journal export recovery.
///
/// It first lets the AW17 registration journal quarantine previous-process published batches,
/// then converges any explicit AW19 preserve/purge disposition, and finally returns a non-destructive
/// inventory for App/HQ recovery UX. No project ownership is inferred by this service.
public actor Lane2PrejournalExportRecoveryService {
    private let registrationJournal: Lane2ExportRegistrationJournal
    private let quarantine: Lane2PrejournalExportQuarantineManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.registrationJournal = Lane2ExportRegistrationJournal(rootURL: rootURL, fileManager: fileManager)
        self.quarantine = Lane2PrejournalExportQuarantineManager(rootURL: rootURL, fileManager: fileManager)
    }

    public func inventoryAfterRelaunch() async throws -> Lane2PrejournalQuarantineInventory {
        _ = try registrationJournal.recoverPrejournalPublishedBatches()
        _ = try await quarantine.recoverPendingDispositions()
        return await quarantine.inventory()
    }

    @discardableResult
    public func preserveForUser(batchID: String, snapshotToken: String) async throws -> Lane2PrejournalQuarantineBatch {
        try await quarantine.preserveForUser(batchID: batchID, snapshotToken: snapshotToken)
    }

    public func purgePending(batchID: String, snapshotToken: String) async throws {
        try await quarantine.purgePending(batchID: batchID, snapshotToken: snapshotToken)
    }

    public func purgeRecovered(batchID: String, snapshotToken: String) async throws {
        try await quarantine.purgeRecovered(batchID: batchID, snapshotToken: snapshotToken)
    }

    public func recoveredArtifactURLs(batchID: String, snapshotToken: String) async throws -> [URL] {
        try await quarantine.recoveredArtifactURLs(batchID: batchID, snapshotToken: snapshotToken)
    }

    @discardableResult
    public func recoverPendingDispositions() async throws -> Lane2PrejournalDispositionRecoveryReport {
        try await quarantine.recoverPendingDispositions()
    }
}
