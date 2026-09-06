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
    public static let defaultDeletionJournalRecoveryLimit = 64
    public static let maximumDeletionJournalRecoveryLimit = 256

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
        let registeredManaged = try inventory.registerIfManaged(relativePath: relativePath)
        if registeredManaged {
            try? Lane2ManagedArtifactPublicationJournal(
                rootURL: rootURL,
                recoveryDirectoryName: recoveryDirectoryName
            ).completeIfPresent(relativePath: relativePath)
        }
    }

    public func promoteReadyArtifact(stagingRelativePath: String, finalRelativePath: String) throws {
        let staging = try absoluteURL(for: stagingRelativePath)
        let final = try absoluteURL(for: finalRelativePath)
        try requireReady(relativePath: stagingRelativePath)
        guard !FileManager.default.fileExists(atPath: final.path) else {
            throw LibraryArtifactFailure.destinationAlreadyExists(finalRelativePath)
        }
        try FileManager.default.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)

        let normalizedFinal = try Self.normalize(finalRelativePath)
        let finalRoot = normalizedFinal.split(separator: "/", omittingEmptySubsequences: false).first.map(String.init)
        let isManagedPublication = finalRoot.map { ["Imports", "Stems", "Exports"].contains($0) } ?? false
        let publicationJournal = Lane2ManagedArtifactPublicationJournal(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName
        )
        if isManagedPublication {
            _ = try publicationJournal.begin(relativePath: normalizedFinal)
        }
        do {
            try FileManager.default.moveItem(at: staging, to: final)
        } catch {
            if isManagedPublication {
                try? publicationJournal.cancelCurrentSessionIfPresent(relativePath: normalizedFinal)
            }
            throw error
        }
        try requireReady(relativePath: finalRelativePath)
    }

    @discardableResult
    public func persistPreparedDeletion(projectUUID: UUID, relativePaths: [String]) throws -> URL {
        try ensureLayout()
        let normalized = try relativePaths.map(Self.normalize)
        let journal = LibraryDeletionJournal(projectUUID: projectUUID, relativePaths: normalized, phase: .prepared)
        return try write(journal: journal)
    }

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

    public func discardPreparedDeletion(projectUUID: UUID) throws {
        let url = deletionJournalURL(projectUUID: projectUUID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let journal = try loadJournal(at: url)
        guard journal.phase == .prepared else { return }
        try FileManager.default.removeItem(at: url)
    }

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

    /// Returns a bounded recovery window. A successful recovery pass retires every selected journal,
    /// so later passes naturally advance through an extreme backlog without materializing the full
    /// directory. `limit + 1` is the maximum number of journal URLs inspected/retained by this call.
    /// Journal bytes outside the current window are not decoded early.
    public func pendingDeletionJournals(
        limit: Int = Self.defaultDeletionJournalRecoveryLimit
    ) throws -> [LibraryDeletionJournal] {
        try ensureLayout()
        let effectiveLimit = min(max(limit, 1), Self.maximumDeletionJournalRecoveryLimit)
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var enumerationFailed = false
        guard let enumerator = FileManager.default.enumerator(
            at: deletionJournalDirectoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in
                enumerationFailed = true
                return false
            }
        ) else {
            throw LibraryArtifactFailure.journalCorrupt("Delete")
        }

        var urls: [URL] = []
        urls.reserveCapacity(effectiveLimit)
        for case let url as URL in enumerator {
            guard url.pathExtension == "json" else { continue }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw LibraryArtifactFailure.journalCorrupt(url.lastPathComponent)
            }
            let filename = url.deletingPathExtension().lastPathComponent
            guard let projectUUID = UUID(uuidString: filename),
                  filename == projectUUID.uuidString,
                  url.lastPathComponent == projectUUID.uuidString + ".json" else {
                throw LibraryArtifactFailure.journalCorrupt(url.lastPathComponent)
            }
            urls.append(url)
            if urls.count >= effectiveLimit { break }
        }
        if enumerationFailed {
            throw LibraryArtifactFailure.journalCorrupt("Delete")
        }

        return try urls.map(loadJournal).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.projectUUID.uuidString < rhs.projectUUID.uuidString }
            return lhs.createdAt < rhs.createdAt
        }
    }

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
            let journal = try decoder.decode(LibraryDeletionJournal.self, from: Data(contentsOf: url))
            let filename = url.deletingPathExtension().lastPathComponent
            guard journal.projectUUID.uuidString == filename else {
                throw LibraryArtifactFailure.journalCorrupt(url.lastPathComponent)
            }
            return journal
        } catch let failure as LibraryArtifactFailure {
            throw failure
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