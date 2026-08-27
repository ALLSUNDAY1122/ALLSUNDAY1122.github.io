import Foundation

public struct Lane2ExportRegistrationArtifact: Codable, Hashable, Sendable {
    public let relativePath: String
    public let mediaType: String

    public init(relativePath: String, mediaType: String) {
        self.relativePath = relativePath
        self.mediaType = mediaType
    }
}

public struct Lane2ExportRegistrationIntent: Codable, Hashable, Sendable {
    public let id: UUID
    public let projectUUID: UUID
    public let artifacts: [Lane2ExportRegistrationArtifact]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        projectUUID: UUID,
        artifacts: [Lane2ExportRegistrationArtifact],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectUUID = projectUUID
        self.artifacts = artifacts
        self.createdAt = createdAt
    }
}

public enum Lane2ExportRegistrationDisposition: String, Codable, Hashable, Sendable {
    case alreadyRegistered
    case unregistered
    case partial
}

public struct Lane2ExportRegistrationRecoveryReport: Equatable, Sendable {
    public let preservedRegistered: Int
    public let discardedUnregistered: Int
    public let retainedIncomplete: Int

    public init(preservedRegistered: Int, discardedUnregistered: Int, retainedIncomplete: Int) {
        self.preservedRegistered = preservedRegistered
        self.discardedUnregistered = discardedUnregistered
        self.retainedIncomplete = retainedIncomplete
    }
}

public struct Lane2PrejournalPublicationRecoveryReport: Equatable, Sendable {
    public let quarantinedBatchIDs: [String]
    public let retainedCurrentSessionBatchIDs: [String]

    public init(quarantinedBatchIDs: [String], retainedCurrentSessionBatchIDs: [String]) {
        self.quarantinedBatchIDs = quarantinedBatchIDs.sorted()
        self.retainedCurrentSessionBatchIDs = retainedCurrentSessionBatchIDs.sorted()
    }
}

public enum Lane2ExportRegistrationJournalFailure: Error, Equatable, Sendable {
    case emptyArtifacts
    case invalidRelativePath(String)
    case nonExportPath(String)
    case duplicateArtifactPath(String)
    case corruptIntent(String)
    case intentIdentityMismatch(String)
    case partialRegistration(UUID)
    case publicationMarkerClearFailed(String)
    case publicationMarkerRecoveryFailed(String)
    case publicationIntegrityFailed(String)
}

/// Durable handoff between export publication and lifecycle metadata registration.
///
/// Canonical IO batches cross their atomic publication rename with a hidden pre-registration
/// marker. `prepare` first validates any AW35+ batch integrity manifest, then persists this journal
/// intent and only then clears that marker. A crash therefore always leaves either the IO marker,
/// this Library intent, or both. Pre-AW35 batches have no integrity manifest and retain the historical
/// compatibility path rather than being made unrecoverable by an upgrade.
///
/// AW50 additionally treats the journal roots, intent leaves, publication markers and pre-journal
/// quarantine destinations as filesystem authority: dangling/symlink/non-regular nodes are never
/// interpreted as "missing" compatibility state.
public struct Lane2ExportRegistrationJournal: Sendable {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    @discardableResult
    public func prepare(
        projectUUID: UUID,
        artifacts: [Lane2ExportRegistrationArtifact],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> Lane2ExportRegistrationIntent {
        guard !artifacts.isEmpty else { throw Lane2ExportRegistrationJournalFailure.emptyArtifacts }
        var seen = Set<String>()
        let normalized = try artifacts.map { artifact -> Lane2ExportRegistrationArtifact in
            let path = try Self.normalizeExportPath(artifact.relativePath)
            guard seen.insert(path).inserted else {
                throw Lane2ExportRegistrationJournalFailure.duplicateArtifactPath(path)
            }
            return Lane2ExportRegistrationArtifact(relativePath: path, mediaType: artifact.mediaType)
        }

        try validatePublishedBatchIntegrityIfPresent(for: normalized)

        let intent = Lane2ExportRegistrationIntent(
            id: id,
            projectUUID: projectUUID,
            artifacts: normalized,
            createdAt: now
        )
        let url = intentURL(id: id)
        do {
            try boundary.ensureDirectory(directoryURL, fileManager: fileManager)
            _ = try boundary.requireRegularFileOrMissing(
                url,
                within: directoryURL,
                fileManager: fileManager
            )
            try encode(intent).write(to: url, options: [.atomic])
            try boundary.requireExistingRegularFile(
                url,
                within: directoryURL,
                fileManager: fileManager
            )
        } catch let failure as Lane2ExportRegistrationJournalFailure {
            throw failure
        } catch {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
        }

        // Ordering is deliberate: the Library intent must be durable before the IO publication
        // marker disappears. If marker removal fails, the intent remains and recovery has both
        // signals rather than neither.
        try clearPreRegistrationPublicationMarkers(for: normalized)
        return intent
    }

    public func pending() throws -> [Lane2ExportRegistrationIntent] {
        _ = try recoverPrejournalPublishedBatches()
        do {
            guard try boundary.nodeExists(directoryURL, fileManager: fileManager) else { return [] }
            try boundary.requireDirectory(directoryURL, fileManager: fileManager)
            let urls = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles]
            )
            let intents: [Lane2ExportRegistrationIntent] = try urls
                .filter { $0.pathExtension.lowercased() == "json" }
                .map { try loadIntent(at: $0) }
            return intents.sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.createdAt < rhs.createdAt
            }
        } catch let failure as Lane2ExportRegistrationJournalFailure {
            throw failure
        } catch {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent("ExportRegistration")
        }
    }

    /// Moves only previous-process finalized batches that still carry the IO pre-registration
    /// marker into `.LibraryRecovery/PrejournalExport`. Current-process markers are retained because
    /// another actor call may observe the tiny interval between atomic IO publication and journal
    /// adoption. Quarantine preserves bytes rather than deleting under uncertainty.
    @discardableResult
    public func recoverPrejournalPublishedBatches() throws -> Lane2PrejournalPublicationRecoveryReport {
        do {
            guard try boundary.nodeExists(finalizedBatchesURL, fileManager: fileManager) else {
                return Lane2PrejournalPublicationRecoveryReport(
                    quarantinedBatchIDs: [],
                    retainedCurrentSessionBatchIDs: []
                )
            }
            try boundary.requireDirectory(finalizedBatchesURL, fileManager: fileManager)
        } catch {
            throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed("BATCH_ROOT")
        }

        let batches: [URL]
        do {
            batches = try fileManager.contentsOfDirectory(
                at: finalizedBatchesURL,
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed("ENUMERATE")
        }

        var quarantined: [String] = []
        var retainedCurrent: [String] = []
        for batch in batches {
            let batchID = batch.lastPathComponent
            do {
                try boundary.requireDirectory(batch, fileManager: fileManager)
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed(batchID)
            }

            let marker = batch.appendingPathComponent(
                IOExportBatchTransaction.preRegistrationMarkerFilename,
                isDirectory: false
            )
            let markerPresent: Bool
            do {
                markerPresent = try boundary.nodeExists(marker, fileManager: fileManager)
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed(batchID)
            }
            guard markerPresent else { continue }

            let markerSession: String
            do {
                try boundary.requireExistingRegularFile(
                    marker,
                    within: batch,
                    fileManager: fileManager
                )
                let attributes = try fileManager.attributesOfItem(atPath: marker.path)
                let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
                guard size > 0, size <= 1024 else {
                    throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed(batchID)
                }
                markerSession = String(decoding: try Data(contentsOf: marker), as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !markerSession.isEmpty, !markerSession.contains("\0") else {
                    throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed(batchID)
                }
            } catch let failure as Lane2ExportRegistrationJournalFailure {
                throw failure
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed(batchID)
            }
            if markerSession == IOExportBatchTransaction.publicationSessionID {
                retainedCurrent.append(batchID)
                continue
            }

            do {
                try boundary.ensureDirectory(prejournalQuarantineURL, fileManager: fileManager)
                let destination = prejournalQuarantineURL.appendingPathComponent(
                    batchID,
                    isDirectory: true
                )
                try boundary.requireSafeDestination(
                    destination,
                    within: prejournalQuarantineURL,
                    fileManager: fileManager
                )
                try boundary.requireDirectory(batch, fileManager: fileManager)
                try fileManager.moveItem(at: batch, to: destination)
                try boundary.requireDirectory(destination, fileManager: fileManager)
                quarantined.append(batchID)
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed(batchID)
            }
        }
        return Lane2PrejournalPublicationRecoveryReport(
            quarantinedBatchIDs: quarantined,
            retainedCurrentSessionBatchIDs: retainedCurrent
        )
    }

    public func complete(intentID: UUID) throws {
        let url = intentURL(id: intentID)
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return }
            _ = try loadIntent(at: url)
            try boundary.requireExistingRegularFile(
                url,
                within: directoryURL,
                fileManager: fileManager
            )
            try fileManager.removeItem(at: url)
            guard try !boundary.nodeExists(url, fileManager: fileManager) else {
                throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
            }
            try pruneDirectoryIfEmpty()
        } catch let failure as Lane2ExportRegistrationJournalFailure {
            throw failure
        } catch {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
        }
    }

    public func exists(intentID: UUID) -> Bool {
        let url = intentURL(id: intentID)
        return (try? boundary.requireExistingRegularFile(
            url,
            within: directoryURL,
            fileManager: fileManager
        )) != nil
    }

    public static func disposition(
        intent: Lane2ExportRegistrationIntent,
        registeredRelativePaths: Set<String>
    ) -> Lane2ExportRegistrationDisposition {
        let intended = Set(intent.artifacts.map(\.relativePath))
        let matched = intended.intersection(registeredRelativePaths)
        if matched.isEmpty { return .unregistered }
        if matched.count == intended.count { return .alreadyRegistered }
        return .partial
    }

    private func validatePublishedBatchIntegrityIfPresent(
        for artifacts: [Lane2ExportRegistrationArtifact]
    ) throws {
        let grouped = Dictionary(grouping: artifacts.compactMap {
            artifact -> (String, Lane2ExportRegistrationArtifact)? in
            guard let directory = batchDirectoryURL(for: artifact.relativePath) else { return nil }
            return (directory.lastPathComponent, artifact)
        }, by: { $0.0 })

        let transaction = IOExportBatchTransaction(fileStore: IOFileStore(rootURL: rootURL))
        for (batchID, members) in grouped {
            let directory = finalizedBatchesURL.appendingPathComponent(batchID, isDirectory: true)
            let manifest = directory.appendingPathComponent(
                IOExportBatchTransaction.integrityManifestFilename,
                isDirectory: false
            )
            let manifestPresent: Bool
            do {
                manifestPresent = try boundary.nodeExists(manifest, fileManager: fileManager)
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed(batchID)
            }
            guard manifestPresent else {
                // Compatibility for genuinely absent manifests on batches published before AW35.
                continue
            }
            do {
                // If a dangling/symlink/non-regular manifest occupies the path, AW48 batch
                // verification fails closed instead of silently entering the pre-AW35 path.
                let verified = try transaction.verifyPublishedBatch(
                    batchID: batchID,
                    fileManager: fileManager
                )
                let verifiedPaths = Set(verified.map(\.relativePath))
                let intendedPaths = Set(members.map { $0.1.relativePath })
                guard verifiedPaths == intendedPaths else {
                    throw Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed(batchID)
                }
            } catch let failure as Lane2ExportRegistrationJournalFailure {
                throw failure
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed(batchID)
            }
        }
    }

    private func clearPreRegistrationPublicationMarkers(
        for artifacts: [Lane2ExportRegistrationArtifact]
    ) throws {
        let batchDirectories = Set(artifacts.compactMap { batchDirectoryURL(for: $0.relativePath) })
        for batchDirectory in batchDirectories {
            let marker = batchDirectory.appendingPathComponent(
                IOExportBatchTransaction.preRegistrationMarkerFilename,
                isDirectory: false
            )
            do {
                guard try boundary.nodeExists(marker, fileManager: fileManager) else { continue }
                try boundary.requireExistingRegularFile(
                    marker,
                    within: batchDirectory,
                    fileManager: fileManager
                )
                try fileManager.removeItem(at: marker)
                guard try !boundary.nodeExists(marker, fileManager: fileManager) else {
                    throw Lane2ExportRegistrationJournalFailure.publicationMarkerClearFailed(
                        batchDirectory.lastPathComponent
                    )
                }
            } catch let failure as Lane2ExportRegistrationJournalFailure {
                throw failure
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationMarkerClearFailed(
                    batchDirectory.lastPathComponent
                )
            }
        }
    }

    private func batchDirectoryURL(for relativePath: String) -> URL? {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts[0] == "Exports",
              parts[1] == "Batches",
              !parts[2].isEmpty,
              !parts[3].isEmpty else {
            return nil
        }
        return rootURL
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent("Batches", isDirectory: true)
            .appendingPathComponent(String(parts[2]), isDirectory: true)
    }

    private func loadIntent(at url: URL) throws -> Lane2ExportRegistrationIntent {
        let filename = url.deletingPathExtension().lastPathComponent
        guard let fileID = UUID(uuidString: filename) else {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
        }
        do {
            try boundary.requireExistingRegularFile(
                url,
                within: directoryURL,
                fileManager: fileManager
            )
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let intent = try decoder.decode(
                Lane2ExportRegistrationIntent.self,
                from: Data(contentsOf: url)
            )
            guard intent.id == fileID else {
                throw Lane2ExportRegistrationJournalFailure.intentIdentityMismatch(
                    url.lastPathComponent
                )
            }
            guard !intent.artifacts.isEmpty else {
                throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
            }
            var seen = Set<String>()
            for artifact in intent.artifacts {
                let normalized = try Self.normalizeExportPath(artifact.relativePath)
                guard normalized == artifact.relativePath, seen.insert(normalized).inserted else {
                    throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
                }
            }
            return intent
        } catch let failure as Lane2ExportRegistrationJournalFailure {
            throw failure
        } catch {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
        }
    }

    private func encode(_ intent: Lane2ExportRegistrationIntent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(intent)
    }

    private func intentURL(id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString + ".json", isDirectory: false)
    }

    private var directoryURL: URL {
        rootURL
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("ExportRegistration", isDirectory: true)
    }

    private var prejournalQuarantineURL: URL {
        rootURL
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("PrejournalExport", isDirectory: true)
    }

    private var finalizedBatchesURL: URL {
        rootURL
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent("Batches", isDirectory: true)
    }

    private var boundary: LibraryManagedPathBoundary {
        LibraryManagedPathBoundary(rootURL: rootURL)
    }

    private func pruneDirectoryIfEmpty() throws {
        do {
            guard try boundary.nodeExists(directoryURL, fileManager: fileManager) else { return }
            try boundary.requireDirectory(directoryURL, fileManager: fileManager)
            let children = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
            if children.isEmpty {
                try boundary.requireDirectory(directoryURL, fileManager: fileManager)
                try fileManager.removeItem(at: directoryURL)
            }
        } catch let failure as Lane2ExportRegistrationJournalFailure {
            throw failure
        } catch {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent("ExportRegistration")
        }
    }

    private static func normalizeExportPath(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2ExportRegistrationJournalFailure.invalidRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2ExportRegistrationJournalFailure.invalidRelativePath(relativePath)
        }
        let result = parts.joined(separator: "/")
        guard parts.count >= 2, parts.first == "Exports" else {
            throw Lane2ExportRegistrationJournalFailure.nonExportPath(relativePath)
        }
        return result
    }
}
