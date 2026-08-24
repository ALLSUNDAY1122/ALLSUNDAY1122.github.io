import Foundation

public enum LibraryArtifactFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case missingArtifact(String)
    case emptyArtifact(String)
    case destinationAlreadyExists(String)
    case journalCorrupt(String)
    case journalNotCommitted(UUID)
    case journalNotArtifactsDeleted(UUID)
    case cleanupFailed(String)
}

public enum LibraryDeletionPhase: String, Codable, Hashable, Sendable {
    case prepared
    case committed
    case artifactsDeleted
}

public struct LibraryDeletionJournal: Codable, Hashable, Sendable {
    public let projectUUID: UUID
    public let relativePaths: [String]
    public let createdAt: Date
    public let phase: LibraryDeletionPhase

    public init(
        projectUUID: UUID,
        relativePaths: [String],
        createdAt: Date = Date(),
        phase: LibraryDeletionPhase = .prepared
    ) {
        self.projectUUID = projectUUID
        self.relativePaths = Array(Set(relativePaths)).sorted()
        self.createdAt = createdAt
        self.phase = phase
    }
}

public struct LibraryArtifactInspection: Hashable, Sendable {
    public let relativePath: String
    public let exists: Bool
    public let isRegularFile: Bool
    public let byteCount: UInt64
    public var isReady: Bool { exists && isRegularFile && byteCount > 0 }
}

public struct LibraryOrphanSweepResult: Hashable, Sendable {
    public let scanned: Int
    public let removed: [String]
    public let retainedReferenced: Int
    public let retainedYoung: Int
}

/// Foundation-only file lifecycle used by Library persistence.
/// All paths are app-owned relative paths; external provider URLs never cross this boundary.
public struct LibraryArtifactLifecycle: Sendable {
    public let rootURL: URL
    public let recoveryDirectoryName: String

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery") {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
    }

    public func ensureLayout() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deletionJournalDirectoryURL, withIntermediateDirectories: true)
    }

    public func absoluteURL(for relativePath: String) throws -> URL {
        let normalized = try Self.normalize(relativePath)
        let candidate = rootURL.appendingPathComponent(normalized, isDirectory: false).standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            throw LibraryArtifactFailure.invalidRelativePath(relativePath)
        }
        return candidate
    }

    public func inspect(relativePath: String) throws -> LibraryArtifactInspection {
        let url = try absoluteURL(for: relativePath)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            return LibraryArtifactInspection(relativePath: relativePath, exists: false, isRegularFile: false, byteCount: 0)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        return LibraryArtifactInspection(
            relativePath: relativePath,
            exists: true,
            isRegularFile: values.isRegularFile == true && !isDirectory.boolValue,
            byteCount: UInt64(max(values.fileSize ?? 0, 0))
        )
    }

    public func requireReady(relativePath: String) throws {
        let inspection = try inspect(relativePath: relativePath)
        guard inspection.exists else { throw LibraryArtifactFailure.missingArtifact(relativePath) }
        guard inspection.isRegularFile, inspection.byteCount > 0 else {
            throw LibraryArtifactFailure.emptyArtifact(relativePath)
        }
        let inventory = Lane2ManagedArtifactInventory(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName
        )
        _ = try inventory.activateForFirstManagedArtifactIfSafe(relativePath: relativePath)
        _ = try inventory.registerIfManaged(relativePath: relativePath)
    }

    /// Metadata may expose finalRelativePath only after this succeeds.
    /// An existing final artifact is never silently overwritten.
    public func promoteReadyArtifact(stagingRelativePath: String, finalRelativePath: String) throws {
        let staging = try absoluteURL(for: stagingRelativePath)
        let final = try absoluteURL(for: finalRelativePath)
        try requireReady(relativePath: stagingRelativePath)
        guard !FileManager.default.fileExists(atPath: final.path) else {
            throw LibraryArtifactFailure.destinationAlreadyExists(finalRelativePath)
        }
        try FileManager.default.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: staging, to: final)
        try requireReady(relativePath: finalRelativePath)
    }

    /// PREPARED is durable intent only; files cannot be deleted until the metadata tombstone commits.
    @discardableResult
    public func persistPreparedDeletion(projectUUID: UUID, relativePaths: [String]) throws -> URL {
        try ensureLayout()
        let normalized = try relativePaths.map(Self.normalize)
        let journal = LibraryDeletionJournal(projectUUID: projectUUID, relativePaths: normalized, phase: .prepared)
        return try write(journal: journal)
    }

    /// Called only after the metadata tombstone transaction commits.
    public func markDeletionCommitted(projectUUID: UUID) throws {
        let existing = try requireJournal(projectUUID: projectUUID)
        switch existing.phase {
        case .prepared:
            let committed = LibraryDeletionJournal(
                projectUUID: existing.projectUUID,
                relativePaths: existing.relativePaths,
                createdAt: existing.createdAt,
                phase: .committed
            )
            _ = try write(journal: committed)
        case .committed, .artifactsDeleted:
            return
        }
    }

    /// Backfills a durable COMMITTED journal for a tombstone created by an older build or by an
    /// interrupted metadata-only delete. The tombstone itself is the already-durable deletion intent.
    @discardableResult
    public func persistCommittedDeletion(projectUUID: UUID, relativePaths: [String]) throws -> URL {
        try ensureLayout()
        let normalized = Array(Set(try relativePaths.map(Self.normalize))).sorted()
        let url = deletionJournalURL(projectUUID: projectUUID)
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try loadJournal(at: url)
            guard existing.projectUUID == projectUUID, existing.relativePaths == normalized else {
                throw LibraryArtifactFailure.journalCorrupt(url.lastPathComponent)
            }
            if existing.phase == .prepared {
                try markDeletionCommitted(projectUUID: projectUUID)
            }
            return url
        }
        return try write(
            journal: LibraryDeletionJournal(
                projectUUID: projectUUID,
                relativePaths: normalized,
                phase: .committed
            )
        )
    }

    /// A PREPARED journal can be discarded only when metadata is proven live after relaunch.
    public func discardPreparedDeletion(projectUUID: UUID) throws {
        let url = deletionJournalURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let journal = try loadJournal(at: url)
        guard journal.phase == .prepared else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Idempotent artifact deletion. Missing files are already-clean. The journal remains durable
    /// in ARTIFACTS_DELETED until Core Data metadata compaction commits, closing the old crash window
    /// where file cleanup could finish and erase the only recovery signal before physical metadata cleanup.
    public func executeCommittedDeletion(projectUUID: UUID) throws {
        let journalURL = deletionJournalURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return }
        let journal = try loadJournal(at: journalURL)
        guard journal.projectUUID == projectUUID else {
            throw LibraryArtifactFailure.journalCorrupt(journalURL.lastPathComponent)
        }
        if journal.phase == .artifactsDeleted { return }
        guard journal.phase == .committed else {
            throw LibraryArtifactFailure.journalNotCommitted(projectUUID)
        }
        for relativePath in journal.relativePaths {
            let url = try absoluteURL(for: relativePath)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    throw LibraryArtifactFailure.cleanupFailed(relativePath)
                }
            }
        }
        _ = try write(
            journal: LibraryDeletionJournal(
                projectUUID: journal.projectUUID,
                relativePaths: journal.relativePaths,
                createdAt: journal.createdAt,
                phase: .artifactsDeleted
            )
        )
    }

    /// Final journal retirement is legal only after metadata compaction has committed. Missing is
    /// idempotently treated as already complete for the post-removal crash boundary.
    public func completeMetadataCompaction(projectUUID: UUID) throws {
        let url = deletionJournalURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let journal = try loadJournal(at: url)
        guard journal.projectUUID == projectUUID else {
            throw LibraryArtifactFailure.journalCorrupt(url.lastPathComponent)
        }
        guard journal.phase == .artifactsDeleted else {
            throw LibraryArtifactFailure.journalNotArtifactsDeleted(projectUUID)
        }
        try FileManager.default.removeItem(at: url)
    }

    public func pendingDeletionJournals() throws -> [LibraryDeletionJournal] {
        try ensureLayout()
        return try FileManager.default.contentsOfDirectory(
            at: deletionJournalDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .map(loadJournal)
        .sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.projectUUID.uuidString < rhs.projectUUID.uuidString }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// Removes only unreferenced files in explicitly managed roots and only after a grace period.
    public func sweepOrphans(
        referencedRelativePaths: Set<String>,
        managedRootNames: [String] = ["Imports", "Stems", "Exports"],
        gracePeriod: TimeInterval = 3600,
        now: Date = Date()
    ) throws -> LibraryOrphanSweepResult {
        let referenced = Set(try referencedRelativePaths.map(Self.normalize))
        var scanned = 0
        var removed: [String] = []
        var retainedReferenced = 0
        var retainedYoung = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]

        for rootName in managedRootNames {
            let managedRoot = try absoluteURL(for: Self.normalize(rootName))
            guard FileManager.default.fileExists(atPath: managedRoot.path) else { continue }
            guard let enumerator = FileManager.default.enumerator(
                at: managedRoot,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: keys)
                guard values.isRegularFile == true else { continue }
                scanned += 1
                let relativePath = try relativePath(for: fileURL)
                if referenced.contains(relativePath) {
                    retainedReferenced += 1
                    continue
                }
                let modified = values.contentModificationDate ?? .distantPast
                if now.timeIntervalSince(modified) < gracePeriod {
                    retainedYoung += 1
                    continue
                }
                try FileManager.default.removeItem(at: fileURL)
                removed.append(relativePath)
            }
        }

        return LibraryOrphanSweepResult(
            scanned: scanned,
            removed: removed.sorted(),
            retainedReferenced: retainedReferenced,
            retainedYoung: retainedYoung
        )
    }

    private var deletionJournalDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("Delete", isDirectory: true)
    }

    private func deletionJournalURL(projectUUID: UUID) -> URL {
        deletionJournalDirectoryURL.appendingPathComponent(projectUUID.uuidString + ".json", isDirectory: false)
    }

    private func requireJournal(projectUUID: UUID) throws -> LibraryDeletionJournal {
        let url = deletionJournalURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LibraryArtifactFailure.journalCorrupt(projectUUID.uuidString)
        }
        return try loadJournal(at: url)
    }

    @discardableResult
    private func write(journal: LibraryDeletionJournal) throws -> URL {
        let url = deletionJournalURL(projectUUID: journal.projectUUID)
        let data = try JSONEncoder.stable.encode(journal)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func loadJournal(at url: URL) throws -> LibraryDeletionJournal {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(LibraryDeletionJournal.self, from: Data(contentsOf: url))
        } catch {
            throw LibraryArtifactFailure.journalCorrupt(url.lastPathComponent)
        }
    }

    private func relativePath(for url: URL) throws -> String {
        let standardized = url.standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard standardized.path.hasPrefix(rootPath) else {
            throw LibraryArtifactFailure.invalidRelativePath(url.path)
        }
        return try Self.normalize(String(standardized.path.dropFirst(rootPath.count)))
    }

    private static func normalize(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw LibraryArtifactFailure.invalidRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw LibraryArtifactFailure.invalidRelativePath(relativePath)
        }
        return parts.joined(separator: "/")
    }
}

private extension JSONEncoder {
    static var stable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
