import Foundation

public enum Lane2PrejournalQuarantineLocation: String, Codable, Hashable, Sendable {
    case pending
    case recoveredForUser
}

public struct Lane2PrejournalQuarantineArtifact: Codable, Hashable, Sendable {
    public let filename: String
    public let byteCount: UInt64
    public let modifiedAtMilliseconds: Int64

    public init(filename: String, byteCount: UInt64, modifiedAtMilliseconds: Int64) {
        self.filename = filename
        self.byteCount = byteCount
        self.modifiedAtMilliseconds = modifiedAtMilliseconds
    }
}

public struct Lane2PrejournalQuarantineBatch: Codable, Hashable, Sendable {
    public let batchID: String
    public let location: Lane2PrejournalQuarantineLocation
    public let markerSessionID: String
    public let artifacts: [Lane2PrejournalQuarantineArtifact]
    public let totalBytes: UInt64
    public let snapshotToken: String

    public init(
        batchID: String,
        location: Lane2PrejournalQuarantineLocation,
        markerSessionID: String,
        artifacts: [Lane2PrejournalQuarantineArtifact],
        totalBytes: UInt64,
        snapshotToken: String
    ) {
        self.batchID = batchID
        self.location = location
        self.markerSessionID = markerSessionID
        self.artifacts = artifacts
        self.totalBytes = totalBytes
        self.snapshotToken = snapshotToken
    }
}

public struct Lane2PrejournalQuarantineIssue: Codable, Hashable, Sendable {
    public let location: Lane2PrejournalQuarantineLocation
    public let batchName: String
    public let stableCode: String

    public init(location: Lane2PrejournalQuarantineLocation, batchName: String, stableCode: String) {
        self.location = location
        self.batchName = batchName
        self.stableCode = stableCode
    }
}

public struct Lane2PrejournalQuarantineInventory: Codable, Hashable, Sendable {
    public let pending: [Lane2PrejournalQuarantineBatch]
    public let recoveredForUser: [Lane2PrejournalQuarantineBatch]
    public let issues: [Lane2PrejournalQuarantineIssue]

    public init(
        pending: [Lane2PrejournalQuarantineBatch],
        recoveredForUser: [Lane2PrejournalQuarantineBatch],
        issues: [Lane2PrejournalQuarantineIssue]
    ) {
        self.pending = pending.sorted { $0.batchID < $1.batchID }
        self.recoveredForUser = recoveredForUser.sorted { $0.batchID < $1.batchID }
        self.issues = issues.sorted {
            if $0.location.rawValue == $1.location.rawValue { return $0.batchName < $1.batchName }
            return $0.location.rawValue < $1.location.rawValue
        }
    }
}

public struct Lane2PrejournalDispositionRecoveryReport: Codable, Hashable, Sendable {
    public let completedPreserves: Int
    public let completedPendingPurges: Int
    public let completedRecoveredPurges: Int

    public init(completedPreserves: Int, completedPendingPurges: Int, completedRecoveredPurges: Int) {
        self.completedPreserves = completedPreserves
        self.completedPendingPurges = completedPendingPurges
        self.completedRecoveredPurges = completedRecoveredPurges
    }
}

public enum Lane2PrejournalQuarantineFailure: Error, Equatable, Sendable {
    case invalidBatchID(String)
    case batchNotFound(String)
    case unsafeBatchLocation(String)
    case batchNotDirectory(String)
    case symlinkRejected(String)
    case missingPublicationMarker(String)
    case invalidPublicationMarker(String)
    case emptyBatch(String)
    case unexpectedNestedEntry(String)
    case invalidArtifact(String)
    case emptyArtifact(String)
    case ambiguousArtifactName(String)
    case byteCountOverflow(String)
    case staleSnapshot(String)
    case destinationConflict(String)
    case corruptDisposition(String)
    case dispositionIdentityMismatch(String)
    case fileOperationFailed(String)
}

/// Explicit, crash-recoverable management for AW17 pre-journal export quarantine.
///
/// This type deliberately does not infer a ProjectID or write lifecycle export metadata. A caller
/// can either preserve a valid quarantined batch for user retrieval or explicitly purge it. The
/// preserve operation moves the whole batch into a non-orphan-swept recovery root so bytes remain
/// shareable/exportable without pretending ownership is known.
public actor Lane2PrejournalExportQuarantineManager {
    private enum DispositionKind: String, Codable, Sendable {
        case preserveForUser
        case purgePending
        case purgeRecovered
    }

    private struct DispositionIntent: Codable, Sendable {
        let id: UUID
        let kind: DispositionKind
        let batchID: String
        let snapshotToken: String
        let createdAt: Date
    }

    public let rootURL: URL
    private let fileManager: FileManager
    private let markerFilename: String

    public init(
        rootURL: URL,
        markerFilename: String = ".lane2-registration-pending",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.markerFilename = markerFilename
        self.fileManager = fileManager
    }

    /// Non-destructive inventory. One malformed batch is reported as an issue rather than hiding
    /// other valid recovery candidates.
    public func inventory() -> Lane2PrejournalQuarantineInventory {
        let pending = inspectRoot(location: .pending)
        let recovered = inspectRoot(location: .recoveredForUser)
        return Lane2PrejournalQuarantineInventory(
            pending: pending.batches,
            recoveredForUser: recovered.batches,
            issues: pending.issues + recovered.issues
        )
    }

    /// User/HQ explicitly chooses to retain bytes. The batch is moved atomically between two
    /// `.LibraryRecovery` roots; no ProjectID is invented and nothing enters canonical `Exports/**`.
    @discardableResult
    public func preserveForUser(batchID: String, snapshotToken: String) throws -> Lane2PrejournalQuarantineBatch {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .pending)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        guard !fileManager.fileExists(atPath: batchURL(batchID: batchID, location: .recoveredForUser).path) else {
            throw Lane2PrejournalQuarantineFailure.destinationConflict(batchID)
        }
        let intent = try persistIntent(kind: .preserveForUser, batch: batch)
        try apply(intent)
        return try inspectBatch(batchID: batchID, location: .recoveredForUser)
    }

    /// Explicit destructive decision for an unresolved quarantine batch. Exact snapshot matching is
    /// required before the durable purge intent is written.
    public func purgePending(batchID: String, snapshotToken: String) throws {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .pending)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        let intent = try persistIntent(kind: .purgePending, batch: batch)
        try apply(intent)
    }

    /// Explicit destructive decision for a batch that was previously preserved for user retrieval.
    public func purgeRecovered(batchID: String, snapshotToken: String) throws {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .recoveredForUser)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        let intent = try persistIntent(kind: .purgeRecovered, batch: batch)
        try apply(intent)
    }

    /// Returns only fully revalidated user-recovered artifact URLs. The hidden AW17 marker is never
    /// exposed as a media artifact.
    public func recoveredArtifactURLs(batchID: String, snapshotToken: String) throws -> [URL] {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .recoveredForUser)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        let directory = batchURL(batchID: batchID, location: .recoveredForUser)
        return batch.artifacts.map { directory.appendingPathComponent($0.filename, isDirectory: false) }
    }

    /// Relaunch convergence for a process death after the explicit decision became durable but before
    /// its filesystem mutation or intent cleanup completed.
    @discardableResult
    public func recoverPendingDispositions() throws -> Lane2PrejournalDispositionRecoveryReport {
        guard fileManager.fileExists(atPath: dispositionRootURL.path) else {
            return Lane2PrejournalDispositionRecoveryReport(
                completedPreserves: 0,
                completedPendingPurges: 0,
                completedRecoveredPurges: 0
            )
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: dispositionRootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_ENUMERATE")
        }

        var preserved = 0
        var purgedPending = 0
        var purgedRecovered = 0
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.pathExtension.lowercased() == "json" else {
                throw Lane2PrejournalQuarantineFailure.corruptDisposition(url.lastPathComponent)
            }
            let intent = try loadIntent(at: url)
            try apply(intent)
            switch intent.kind {
            case .preserveForUser: preserved += 1
            case .purgePending: purgedPending += 1
            case .purgeRecovered: purgedRecovered += 1
            }
        }
        return Lane2PrejournalDispositionRecoveryReport(
            completedPreserves: preserved,
            completedPendingPurges: purgedPending,
            completedRecoveredPurges: purgedRecovered
        )
    }

    private func apply(_ intent: DispositionIntent) throws {
        switch intent.kind {
        case .preserveForUser:
            let source = batchURL(batchID: intent.batchID, location: .pending)
            let destination = batchURL(batchID: intent.batchID, location: .recoveredForUser)
            let sourceExists = fileManager.fileExists(atPath: source.path)
            let destinationExists = fileManager.fileExists(atPath: destination.path)

            if sourceExists && destinationExists {
                throw Lane2PrejournalQuarantineFailure.destinationConflict(intent.batchID)
            }
            if sourceExists {
                let batch = try inspectBatch(batchID: intent.batchID, location: .pending)
                guard batch.snapshotToken == intent.snapshotToken else {
                    throw Lane2PrejournalQuarantineFailure.staleSnapshot(intent.batchID)
                }
                do {
                    try fileManager.createDirectory(at: recoveredRootURL, withIntermediateDirectories: true)
                    try fileManager.moveItem(at: source, to: destination)
                } catch {
                    throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PRESERVE_MOVE_\(intent.batchID)")
                }
            } else if destinationExists {
                let batch = try inspectBatch(batchID: intent.batchID, location: .recoveredForUser)
                guard batch.snapshotToken == intent.snapshotToken else {
                    throw Lane2PrejournalQuarantineFailure.staleSnapshot(intent.batchID)
                }
            } else {
                throw Lane2PrejournalQuarantineFailure.batchNotFound(intent.batchID)
            }

        case .purgePending:
            try applyPurge(intent, location: .pending)

        case .purgeRecovered:
            try applyPurge(intent, location: .recoveredForUser)
        }

        try removeIntent(id: intent.id)
    }

    private func applyPurge(_ intent: DispositionIntent, location: Lane2PrejournalQuarantineLocation) throws {
        let url = batchURL(batchID: intent.batchID, location: location)
        guard fileManager.fileExists(atPath: url.path) else { return }
        let batch = try inspectBatch(batchID: intent.batchID, location: location)
        guard batch.snapshotToken == intent.snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(intent.batchID)
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PURGE_\(intent.batchID)")
        }
    }

    private func persistIntent(kind: DispositionKind, batch: Lane2PrejournalQuarantineBatch) throws -> DispositionIntent {
        let intent = DispositionIntent(
            id: UUID(),
            kind: kind,
            batchID: batch.batchID,
            snapshotToken: batch.snapshotToken,
            createdAt: Date()
        )
        do {
            try fileManager.createDirectory(at: dispositionRootURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(intent).write(to: dispositionURL(id: intent.id), options: [.atomic])
            return intent
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_WRITE")
        }
    }

    private func loadIntent(at url: URL) throws -> DispositionIntent {
        let stem = url.deletingPathExtension().lastPathComponent
        guard let fileID = UUID(uuidString: stem) else {
            throw Lane2PrejournalQuarantineFailure.corruptDisposition(url.lastPathComponent)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let intent = try decoder.decode(DispositionIntent.self, from: Data(contentsOf: url))
            guard intent.id == fileID else {
                throw Lane2PrejournalQuarantineFailure.dispositionIdentityMismatch(url.lastPathComponent)
            }
            try validateBatchID(intent.batchID)
            guard intent.snapshotToken.hasPrefix("v1-") else {
                throw Lane2PrejournalQuarantineFailure.corruptDisposition(url.lastPathComponent)
            }
            return intent
        } catch let failure as Lane2PrejournalQuarantineFailure {
            throw failure
        } catch {
            throw Lane2PrejournalQuarantineFailure.corruptDisposition(url.lastPathComponent)
        }
    }

    private func removeIntent(id: UUID) throws {
        let url = dispositionURL(id: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
            if fileManager.fileExists(atPath: dispositionRootURL.path),
               (try fileManager.contentsOfDirectory(atPath: dispositionRootURL.path)).isEmpty {
                try fileManager.removeItem(at: dispositionRootURL)
            }
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_REMOVE")
        }
    }

    private func inspectRoot(
        location: Lane2PrejournalQuarantineLocation
    ) -> (batches: [Lane2PrejournalQuarantineBatch], issues: [Lane2PrejournalQuarantineIssue]) {
        let root = rootURL(for: location)
        guard fileManager.fileExists(atPath: root.path) else { return ([], []) }
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            )
        } catch {
            return ([], [Lane2PrejournalQuarantineIssue(location: location, batchName: "<root>", stableCode: "ENUMERATE_FAILED")])
        }

        var batches: [Lane2PrejournalQuarantineBatch] = []
        var issues: [Lane2PrejournalQuarantineIssue] = []
        for child in children {
            do {
                batches.append(try inspectBatch(batchID: child.lastPathComponent, location: location))
            } catch {
                issues.append(
                    Lane2PrejournalQuarantineIssue(
                        location: location,
                        batchName: child.lastPathComponent,
                        stableCode: Self.stableCode(error)
                    )
                )
            }
        }
        return (batches, issues)
    }

    private func inspectBatch(
        batchID: String,
        location: Lane2PrejournalQuarantineLocation
    ) throws -> Lane2PrejournalQuarantineBatch {
        try validateBatchID(batchID)
        let root = rootURL(for: location)
        let url = batchURL(batchID: batchID, location: location)
        guard isDirectChild(url, of: root) else {
            throw Lane2PrejournalQuarantineFailure.unsafeBatchLocation(batchID)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw Lane2PrejournalQuarantineFailure.batchNotFound(batchID)
        }
        guard isDirectory.boolValue else {
            throw Lane2PrejournalQuarantineFailure.batchNotDirectory(batchID)
        }
        let dirValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard dirValues.isDirectory == true else {
            throw Lane2PrejournalQuarantineFailure.batchNotDirectory(batchID)
        }
        guard dirValues.isSymbolicLink != true else {
            throw Lane2PrejournalQuarantineFailure.symlinkRejected(batchID)
        }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                    .contentModificationDateKey
                ],
                options: []
            )
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("BATCH_ENUMERATE_\(batchID)")
        }

        guard let markerURL = children.first(where: { $0.lastPathComponent == markerFilename }) else {
            throw Lane2PrejournalQuarantineFailure.missingPublicationMarker(batchID)
        }
        let markerSession = try readMarker(markerURL, batchID: batchID)

        var artifacts: [Lane2PrejournalQuarantineArtifact] = []
        var normalizedNames = Set<String>()
        var total: UInt64 = 0
        for child in children where child.lastPathComponent != markerFilename {
            guard isDirectChild(child, of: url) else {
                throw Lane2PrejournalQuarantineFailure.unsafeBatchLocation(child.lastPathComponent)
            }
            let values = try child.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey
            ])
            if values.isDirectory == true {
                throw Lane2PrejournalQuarantineFailure.unexpectedNestedEntry(child.lastPathComponent)
            }
            guard values.isSymbolicLink != true else {
                throw Lane2PrejournalQuarantineFailure.symlinkRejected(child.lastPathComponent)
            }
            guard values.isRegularFile == true else {
                throw Lane2PrejournalQuarantineFailure.invalidArtifact(child.lastPathComponent)
            }
            let byteCount = UInt64(max(values.fileSize ?? 0, 0))
            guard byteCount > 0 else {
                throw Lane2PrejournalQuarantineFailure.emptyArtifact(child.lastPathComponent)
            }
            let canonicalName = child.lastPathComponent
                .precomposedStringWithCanonicalMapping
                .lowercased(with: Locale(identifier: "en_US_POSIX"))
            guard normalizedNames.insert(canonicalName).inserted else {
                throw Lane2PrejournalQuarantineFailure.ambiguousArtifactName(child.lastPathComponent)
            }
            let modified = values.contentModificationDate ?? .distantPast
            let millisDouble = modified.timeIntervalSince1970 * 1000
            let millis: Int64
            if millisDouble >= Double(Int64.max) {
                millis = Int64.max
            } else if millisDouble <= Double(Int64.min) {
                millis = Int64.min
            } else {
                millis = Int64(millisDouble.rounded(.towardZero))
            }
            let (nextTotal, overflow) = total.addingReportingOverflow(byteCount)
            guard !overflow else {
                throw Lane2PrejournalQuarantineFailure.byteCountOverflow(batchID)
            }
            total = nextTotal
            artifacts.append(
                Lane2PrejournalQuarantineArtifact(
                    filename: child.lastPathComponent,
                    byteCount: byteCount,
                    modifiedAtMilliseconds: millis
                )
            )
        }
        guard !artifacts.isEmpty else {
            throw Lane2PrejournalQuarantineFailure.emptyBatch(batchID)
        }
        artifacts.sort { $0.filename < $1.filename }
        let token = Self.snapshotToken(batchID: batchID, markerSession: markerSession, artifacts: artifacts)
        return Lane2PrejournalQuarantineBatch(
            batchID: batchID,
            location: location,
            markerSessionID: markerSession,
            artifacts: artifacts,
            totalBytes: total,
            snapshotToken: token
        )
    }

    private func readMarker(_ url: URL, batchID: String) throws -> String {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
        }
        let size = values.fileSize ?? 0
        guard size > 0, size <= 1024 else {
            throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
        }
        do {
            let session = String(decoding: try Data(contentsOf: url), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !session.isEmpty, !session.contains("\0") else {
                throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
            }
            return session
        } catch let failure as Lane2PrejournalQuarantineFailure {
            throw failure
        } catch {
            throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
        }
    }

    private func validateBatchID(_ batchID: String) throws {
        guard let parsed = UUID(uuidString: batchID),
              parsed.uuidString.lowercased() == batchID.lowercased(),
              !batchID.contains("/"),
              !batchID.contains("\\") else {
            throw Lane2PrejournalQuarantineFailure.invalidBatchID(batchID)
        }
    }

    private func rootURL(for location: Lane2PrejournalQuarantineLocation) -> URL {
        switch location {
        case .pending: return pendingRootURL
        case .recoveredForUser: return recoveredRootURL
        }
    }

    private func batchURL(batchID: String, location: Lane2PrejournalQuarantineLocation) -> URL {
        rootURL(for: location).appendingPathComponent(batchID, isDirectory: true).standardizedFileURL
    }

    private var pendingRootURL: URL {
        rootURL
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("PrejournalExport", isDirectory: true)
    }

    private var recoveredRootURL: URL {
        rootURL
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("RecoveredPrejournalExport", isDirectory: true)
    }

    private var dispositionRootURL: URL {
        rootURL
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("PrejournalExportDisposition", isDirectory: true)
    }

    private func dispositionURL(id: UUID) -> URL {
        dispositionRootURL.appendingPathComponent(id.uuidString + ".json", isDirectory: false)
    }

    private func isDirectChild(_ candidate: URL, of parent: URL) -> Bool {
        candidate.standardizedFileURL.deletingLastPathComponent() == parent.standardizedFileURL
    }

    /// Snapshot token detects stale UI/HQ confirmation caused by filename/size/mtime/session changes.
    /// It is intentionally a non-cryptographic revision token, not a content-authenticity digest.
    private static func snapshotToken(
        batchID: String,
        markerSession: String,
        artifacts: [Lane2PrejournalQuarantineArtifact]
    ) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        func feed(_ text: String) {
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001b3
            }
            hash ^= 0xff
            hash = hash &* 0x100000001b3
        }
        feed(batchID.lowercased())
        feed(markerSession)
        for artifact in artifacts {
            feed(artifact.filename.precomposedStringWithCanonicalMapping)
            feed(String(artifact.byteCount))
            feed(String(artifact.modifiedAtMilliseconds))
        }
        return String(format: "v1-%016llx", hash)
    }

    private static func stableCode(_ error: Error) -> String {
        guard let failure = error as? Lane2PrejournalQuarantineFailure else {
            return "UNKNOWN"
        }
        switch failure {
        case .invalidBatchID: return "INVALID_BATCH_ID"
        case .batchNotFound: return "BATCH_NOT_FOUND"
        case .unsafeBatchLocation: return "UNSAFE_BATCH_LOCATION"
        case .batchNotDirectory: return "BATCH_NOT_DIRECTORY"
        case .symlinkRejected: return "SYMLINK_REJECTED"
        case .missingPublicationMarker: return "MISSING_MARKER"
        case .invalidPublicationMarker: return "INVALID_MARKER"
        case .emptyBatch: return "EMPTY_BATCH"
        case .unexpectedNestedEntry: return "NESTED_ENTRY"
        case .invalidArtifact: return "INVALID_ARTIFACT"
        case .emptyArtifact: return "EMPTY_ARTIFACT"
        case .ambiguousArtifactName: return "AMBIGUOUS_ARTIFACT_NAME"
        case .byteCountOverflow: return "BYTE_COUNT_OVERFLOW"
        case .staleSnapshot: return "STALE_SNAPSHOT"
        case .destinationConflict: return "DESTINATION_CONFLICT"
        case .corruptDisposition: return "CORRUPT_DISPOSITION"
        case .dispositionIdentityMismatch: return "DISPOSITION_IDENTITY_MISMATCH"
        case .fileOperationFailed: return "FILE_OPERATION_FAILED"
        }
    }
}
