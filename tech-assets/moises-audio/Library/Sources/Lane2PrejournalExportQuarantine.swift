import Foundation

public enum Lane2PrejournalQuarantineLocation: String, Codable, Hashable, Sendable {
    case pending, recoveredForUser
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
            $0.location.rawValue == $1.location.rawValue
                ? $0.batchName < $1.batchName
                : $0.location.rawValue < $1.location.rawValue
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

/// Explicit, crash-recoverable management for pre-journal export quarantine.
/// AW51 makes every disposition, preserve and purge filesystem authority fail closed through
/// `LibraryManagedPathBoundary`; dangling/symlink nodes are never equivalent to absence.
public actor Lane2PrejournalExportQuarantineManager {
    private enum DispositionKind: String, Codable, Sendable {
        case preserveForUser, purgePending, purgeRecovered
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

    public func inventory() -> Lane2PrejournalQuarantineInventory {
        let pending = inspectRoot(location: .pending)
        let recovered = inspectRoot(location: .recoveredForUser)
        return .init(
            pending: pending.batches,
            recoveredForUser: recovered.batches,
            issues: pending.issues + recovered.issues
        )
    }

    @discardableResult
    public func preserveForUser(batchID: String, snapshotToken: String) throws -> Lane2PrejournalQuarantineBatch {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .pending)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        do {
            if try boundary.nodeExists(batchURL(batchID: batchID, location: .recoveredForUser), fileManager: fileManager) {
                throw Lane2PrejournalQuarantineFailure.destinationConflict(batchID)
            }
        } catch let failure as Lane2PrejournalQuarantineFailure {
            throw failure
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PRESERVE_DESTINATION_\(batchID)")
        }
        let intent = try persistIntent(kind: .preserveForUser, batch: batch)
        try apply(intent)
        return try inspectBatch(batchID: batchID, location: .recoveredForUser)
    }

    public func purgePending(batchID: String, snapshotToken: String) throws {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .pending)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        try apply(try persistIntent(kind: .purgePending, batch: batch))
    }

    public func purgeRecovered(batchID: String, snapshotToken: String) throws {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .recoveredForUser)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        try apply(try persistIntent(kind: .purgeRecovered, batch: batch))
    }

    public func recoveredArtifactURLs(batchID: String, snapshotToken: String) throws -> [URL] {
        _ = try recoverPendingDispositions()
        let batch = try inspectBatch(batchID: batchID, location: .recoveredForUser)
        guard batch.snapshotToken == snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(batchID)
        }
        let directory = batchURL(batchID: batchID, location: .recoveredForUser)
        return try batch.artifacts.map {
            let url = directory.appendingPathComponent($0.filename)
            do {
                try boundary.requireExistingRegularFile(url, within: directory, fileManager: fileManager)
                return url
            } catch {
                throw Lane2PrejournalQuarantineFailure.invalidArtifact($0.filename)
            }
        }
    }

    @discardableResult
    public func recoverPendingDispositions() throws -> Lane2PrejournalDispositionRecoveryReport {
        do {
            guard try boundary.nodeExists(dispositionRootURL, fileManager: fileManager) else {
                return .init(completedPreserves: 0, completedPendingPurges: 0, completedRecoveredPurges: 0)
            }
            try boundary.requireDirectory(dispositionRootURL, fileManager: fileManager)
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_ROOT")
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: dispositionRootURL,
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_ENUMERATE")
        }

        var preserved = 0, pendingPurged = 0, recoveredPurged = 0
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.pathExtension.lowercased() == "json" else {
                throw Lane2PrejournalQuarantineFailure.corruptDisposition(url.lastPathComponent)
            }
            do {
                try boundary.requireExistingRegularFile(url, within: dispositionRootURL, fileManager: fileManager)
            } catch {
                throw Lane2PrejournalQuarantineFailure.corruptDisposition(url.lastPathComponent)
            }
            let intent = try loadIntent(at: url)
            try apply(intent)
            switch intent.kind {
            case .preserveForUser: preserved += 1
            case .purgePending: pendingPurged += 1
            case .purgeRecovered: recoveredPurged += 1
            }
        }
        return .init(
            completedPreserves: preserved,
            completedPendingPurges: pendingPurged,
            completedRecoveredPurges: recoveredPurged
        )
    }

    private func apply(_ intent: DispositionIntent) throws {
        switch intent.kind {
        case .preserveForUser:
            let source = batchURL(batchID: intent.batchID, location: .pending)
            let destination = batchURL(batchID: intent.batchID, location: .recoveredForUser)
            let sourceExists: Bool
            let destinationExists: Bool
            do {
                sourceExists = try boundary.nodeExists(source, fileManager: fileManager)
                destinationExists = try boundary.nodeExists(destination, fileManager: fileManager)
            } catch {
                throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PRESERVE_AUTHORITY_\(intent.batchID)")
            }
            if sourceExists && destinationExists {
                throw Lane2PrejournalQuarantineFailure.destinationConflict(intent.batchID)
            } else if sourceExists {
                let batch = try inspectBatch(batchID: intent.batchID, location: .pending)
                guard batch.snapshotToken == intent.snapshotToken else {
                    throw Lane2PrejournalQuarantineFailure.staleSnapshot(intent.batchID)
                }
                do {
                    try boundary.ensureDirectory(recoveredRootURL, fileManager: fileManager)
                    try boundary.requireSafeDestination(destination, within: recoveredRootURL, fileManager: fileManager)
                    try boundary.requireDirectory(source, fileManager: fileManager)
                    try fileManager.moveItem(at: source, to: destination)
                    try boundary.requireDirectory(destination, fileManager: fileManager)
                } catch let failure as Lane2PrejournalQuarantineFailure {
                    throw failure
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
        let exists: Bool
        do {
            exists = try boundary.nodeExists(url, fileManager: fileManager)
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PURGE_AUTHORITY_\(intent.batchID)")
        }
        guard exists else { return }
        let batch = try inspectBatch(batchID: intent.batchID, location: location)
        guard batch.snapshotToken == intent.snapshotToken else {
            throw Lane2PrejournalQuarantineFailure.staleSnapshot(intent.batchID)
        }
        do {
            try boundary.requireDirectory(url, fileManager: fileManager)
            try fileManager.removeItem(at: url)
            if try boundary.nodeExists(url, fileManager: fileManager) {
                throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PURGE_REMAINS_\(intent.batchID)")
            }
        } catch let failure as Lane2PrejournalQuarantineFailure {
            throw failure
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("PURGE_\(intent.batchID)")
        }
    }

    private func persistIntent(
        kind: DispositionKind,
        batch: Lane2PrejournalQuarantineBatch
    ) throws -> DispositionIntent {
        let intent = DispositionIntent(
            id: UUID(),
            kind: kind,
            batchID: batch.batchID,
            snapshotToken: batch.snapshotToken,
            createdAt: Date()
        )
        let url = dispositionURL(id: intent.id)
        do {
            try boundary.ensureDirectory(dispositionRootURL, fileManager: fileManager)
            _ = try boundary.requireRegularFileOrMissing(url, within: dispositionRootURL, fileManager: fileManager)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(intent).write(to: url, options: [.atomic])
            try boundary.requireExistingRegularFile(url, within: dispositionRootURL, fileManager: fileManager)
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
            try boundary.requireExistingRegularFile(url, within: dispositionRootURL, fileManager: fileManager)
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
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return }
            try boundary.requireExistingRegularFile(url, within: dispositionRootURL, fileManager: fileManager)
            try fileManager.removeItem(at: url)
            guard !(try boundary.nodeExists(url, fileManager: fileManager)) else {
                throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_REMOVE")
            }
            guard try boundary.nodeExists(dispositionRootURL, fileManager: fileManager) else { return }
            try boundary.requireDirectory(dispositionRootURL, fileManager: fileManager)
            if try fileManager.contentsOfDirectory(atPath: dispositionRootURL.path).isEmpty {
                try fileManager.removeItem(at: dispositionRootURL)
            }
        } catch let failure as Lane2PrejournalQuarantineFailure {
            throw failure
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("DISPOSITION_REMOVE")
        }
    }

    private func inspectRoot(
        location: Lane2PrejournalQuarantineLocation
    ) -> (batches: [Lane2PrejournalQuarantineBatch], issues: [Lane2PrejournalQuarantineIssue]) {
        let root = rootURL(for: location)
        do {
            guard try boundary.nodeExists(root, fileManager: fileManager) else { return ([], []) }
            try boundary.requireDirectory(root, fileManager: fileManager)
        } catch {
            return (
                [],
                [.init(location: location, batchName: "<root>", stableCode: "UNSAFE_ROOT")]
            )
        }
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [], options: [])
        } catch {
            return (
                [],
                [.init(location: location, batchName: "<root>", stableCode: "ENUMERATE_FAILED")]
            )
        }
        var batches: [Lane2PrejournalQuarantineBatch] = []
        var issues: [Lane2PrejournalQuarantineIssue] = []
        for child in children {
            do {
                batches.append(try inspectBatch(batchID: child.lastPathComponent, location: location))
            } catch {
                issues.append(.init(
                    location: location,
                    batchName: child.lastPathComponent,
                    stableCode: Self.stableCode(error)
                ))
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
        do {
            try boundary.requireDirectory(root, fileManager: fileManager)
            guard try boundary.nodeExists(url, fileManager: fileManager) else {
                throw Lane2PrejournalQuarantineFailure.batchNotFound(batchID)
            }
            let topology = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard topology.isSymbolicLink != true else {
                throw Lane2PrejournalQuarantineFailure.symlinkRejected(batchID)
            }
            guard topology.isDirectory == true else {
                throw Lane2PrejournalQuarantineFailure.batchNotDirectory(batchID)
            }
            try boundary.requireDirectory(url, fileManager: fileManager)
        } catch let failure as Lane2PrejournalQuarantineFailure {
            throw failure
        } catch {
            throw Lane2PrejournalQuarantineFailure.symlinkRejected(batchID)
        }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
                    .fileSizeKey, .contentModificationDateKey
                ],
                options: []
            )
        } catch {
            throw Lane2PrejournalQuarantineFailure.fileOperationFailed("BATCH_ENUMERATE_\(batchID)")
        }
        guard let marker = children.first(where: { $0.lastPathComponent == markerFilename }) else {
            throw Lane2PrejournalQuarantineFailure.missingPublicationMarker(batchID)
        }
        let markerSession = try readMarker(marker, batchID: batchID)

        var artifacts: [Lane2PrejournalQuarantineArtifact] = []
        var names = Set<String>()
        var total: UInt64 = 0
        for child in children where child.lastPathComponent != markerFilename {
            guard isDirectChild(child, of: url) else {
                throw Lane2PrejournalQuarantineFailure.unsafeBatchLocation(child.lastPathComponent)
            }
            let topology: URLResourceValues
            do {
                topology = try child.resourceValues(
                    forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
                )
            } catch {
                throw Lane2PrejournalQuarantineFailure.invalidArtifact(child.lastPathComponent)
            }
            if topology.isDirectory == true {
                throw Lane2PrejournalQuarantineFailure.unexpectedNestedEntry(child.lastPathComponent)
            }
            if topology.isSymbolicLink == true {
                throw Lane2PrejournalQuarantineFailure.symlinkRejected(child.lastPathComponent)
            }
            guard topology.isRegularFile == true else {
                throw Lane2PrejournalQuarantineFailure.invalidArtifact(child.lastPathComponent)
            }
            do {
                try boundary.requireExistingRegularFile(child, within: url, fileManager: fileManager)
            } catch {
                throw Lane2PrejournalQuarantineFailure.invalidArtifact(child.lastPathComponent)
            }
            let values = try child.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let bytes = UInt64(max(values.fileSize ?? 0, 0))
            guard bytes > 0 else {
                throw Lane2PrejournalQuarantineFailure.emptyArtifact(child.lastPathComponent)
            }
            let canonical = child.lastPathComponent
                .precomposedStringWithCanonicalMapping
                .lowercased(with: Locale(identifier: "en_US_POSIX"))
            guard names.insert(canonical).inserted else {
                throw Lane2PrejournalQuarantineFailure.ambiguousArtifactName(child.lastPathComponent)
            }
            let seconds = (values.contentModificationDate ?? .distantPast).timeIntervalSince1970 * 1000
            let millis: Int64
            if seconds >= Double(Int64.max) { millis = .max }
            else if seconds <= Double(Int64.min) { millis = .min }
            else { millis = Int64(seconds.rounded(.towardZero)) }
            let (next, overflow) = total.addingReportingOverflow(bytes)
            guard !overflow else {
                throw Lane2PrejournalQuarantineFailure.byteCountOverflow(batchID)
            }
            total = next
            artifacts.append(.init(
                filename: child.lastPathComponent,
                byteCount: bytes,
                modifiedAtMilliseconds: millis
            ))
        }
        guard !artifacts.isEmpty else {
            throw Lane2PrejournalQuarantineFailure.emptyBatch(batchID)
        }
        artifacts.sort { $0.filename < $1.filename }
        return .init(
            batchID: batchID,
            location: location,
            markerSessionID: markerSession,
            artifacts: artifacts,
            totalBytes: total,
            snapshotToken: Self.snapshotToken(
                batchID: batchID,
                markerSession: markerSession,
                artifacts: artifacts
            )
        )
    }

    private func readMarker(_ url: URL, batchID: String) throws -> String {
        do {
            try boundary.requireExistingRegularFile(
                url,
                within: url.deletingLastPathComponent(),
                fileManager: fileManager
            )
        } catch {
            throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
        }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 1024 else {
            throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
        }
        do {
            let value = String(decoding: try Data(contentsOf: url), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !value.contains("\0") else {
                throw Lane2PrejournalQuarantineFailure.invalidPublicationMarker(batchID)
            }
            return value
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
        location == .pending ? pendingRootURL : recoveredRootURL
    }
    private func batchURL(batchID: String, location: Lane2PrejournalQuarantineLocation) -> URL {
        rootURL(for: location).appendingPathComponent(batchID, isDirectory: true).standardizedFileURL
    }
    private var pendingRootURL: URL {
        rootURL.appendingPathComponent(".LibraryRecovery/PrejournalExport", isDirectory: true)
    }
    private var recoveredRootURL: URL {
        rootURL.appendingPathComponent(".LibraryRecovery/RecoveredPrejournalExport", isDirectory: true)
    }
    private var dispositionRootURL: URL {
        rootURL.appendingPathComponent(".LibraryRecovery/PrejournalExportDisposition", isDirectory: true)
    }
    private func dispositionURL(id: UUID) -> URL {
        dispositionRootURL.appendingPathComponent(id.uuidString + ".json")
    }
    private var boundary: LibraryManagedPathBoundary {
        .init(rootURL: rootURL)
    }
    private func isDirectChild(_ candidate: URL, of parent: URL) -> Bool {
        candidate.standardizedFileURL.deletingLastPathComponent() == parent.standardizedFileURL
    }

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
        guard let failure = error as? Lane2PrejournalQuarantineFailure else { return "UNKNOWN" }
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
