import Foundation

public struct Lane2ManagedArtifactPublicationRecoveryReport: Hashable, Sendable {
    public let recoveredPublished: [String]
    public let discardedMissing: [String]
    public let retainedUnsafe: [String]
    public let visitedRecords: Int
    public let visitedShards: Int
    public let authorityInvalidated: Bool

    public init(
        recoveredPublished: [String],
        discardedMissing: [String],
        retainedUnsafe: [String],
        visitedRecords: Int,
        visitedShards: Int,
        authorityInvalidated: Bool
    ) {
        self.recoveredPublished = recoveredPublished.sorted()
        self.discardedMissing = discardedMissing.sorted()
        self.retainedUnsafe = retainedUnsafe.sorted()
        self.visitedRecords = visitedRecords
        self.visitedShards = visitedShards
        self.authorityInvalidated = authorityInvalidated
    }
}

/// Reconciles only durable publication intents from previous process sessions. It never enumerates
/// Imports/Stems/Exports and therefore does not reintroduce AW28/AW30 full-root discovery after AW29
/// authority. Regular files, including zero-byte interrupted outputs, are indexed so normal grace-
/// based orphan cleanup can converge them. Unsafe non-regular/symlink paths retain their intent and
/// revoke inventory authority so compatibility reconciliation becomes mandatory rather than hidden.
public struct Lane2ManagedArtifactPublicationRecovery: Sendable {
    public let rootURL: URL
    public let recoveryDirectoryName: String
    public let sessionID: String
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        sessionID: String = Lane2ManagedArtifactPublicationJournal.publicationSessionID,
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.sessionID = sessionID
        self.fileManager = fileManager
    }

    @discardableResult
    public func recoverPreviousSessionPublications(
        candidateLimit: Int = Lane2ManagedArtifactPublicationJournal.defaultRecoveryCandidateLimit,
        recordVisitLimit: Int = Lane2ManagedArtifactPublicationJournal.defaultRecoveryRecordVisitLimit,
        shardVisitLimit: Int = Lane2ManagedArtifactPublicationJournal.defaultRecoveryShardVisitLimit
    ) throws -> Lane2ManagedArtifactPublicationRecoveryReport {
        let journal = Lane2ManagedArtifactPublicationJournal(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            sessionID: sessionID,
            fileManager: fileManager
        )
        let inventory = Lane2ManagedArtifactInventory(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
        let slice = try journal.preparePreviousSessionRecoverySlice(
            candidateLimit: candidateLimit,
            recordVisitLimit: recordVisitLimit,
            shardVisitLimit: shardVisitLimit
        )

        var recovered: [String] = []
        var missing: [String] = []
        var unsafe: [String] = []
        var authorityInvalidated = false

        for record in slice.records {
            let url = try absoluteURL(relativePath: record.relativePath)
            guard fileManager.fileExists(atPath: url.path) else {
                try journal.resolveRecoveredRecord(record)
                missing.append(record.relativePath)
                continue
            }

            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey
            ])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                try inventory.invalidateAuthorityForReconciliation()
                authorityInvalidated = true
                unsafe.append(record.relativePath)
                continue
            }

            try inventory.registerManaged(relativePaths: [record.relativePath])
            try journal.resolveRecoveredRecord(record)
            recovered.append(record.relativePath)
        }

        try journal.persistRecoveryCursor(after: slice)
        return Lane2ManagedArtifactPublicationRecoveryReport(
            recoveredPublished: recovered,
            discardedMissing: missing,
            retainedUnsafe: unsafe,
            visitedRecords: slice.visitedRecords,
            visitedShards: slice.visitedShards,
            authorityInvalidated: authorityInvalidated
        )
    }

    /// Used only when publication-journal recovery itself cannot be trusted (for example a corrupt
    /// shard/cursor). Invalidating the authority marker makes the next AW30 census/fallback prove the
    /// complete managed namespace again instead of silently trusting an incomplete steady-state index.
    public func invalidateAuthorityAfterRecoveryFailure() {
        try? Lane2ManagedArtifactInventory(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        ).invalidateAuthorityForReconciliation()
    }

    private func absoluteURL(relativePath: String) throws -> URL {
        let candidate = rootURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard candidate.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactPublicationJournalFailure.invalidRelativePath(relativePath)
        }
        return candidate
    }
}

public extension Lane2ManagedArtifactInventory {
    /// Revokes only the steady-state authority claim. Existing shards are intentionally preserved so
    /// AW30 can idempotently reconcile them during a complete compatibility census. A directory at
    /// the marker location is not recursively removed; callers fail closed and leave authority invalid.
    func invalidateAuthorityForReconciliation() throws {
        let marker = rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("authoritative", isDirectory: false)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDirectory) else { return }
        guard !isDirectory.boolValue else { return }
        try FileManager.default.removeItem(at: marker)
    }
}
