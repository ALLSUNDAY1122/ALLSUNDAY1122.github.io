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

public enum Lane2ExportRegistrationJournalFailure: Error, Equatable, Sendable {
    case emptyArtifacts
    case invalidRelativePath(String)
    case nonExportPath(String)
    case duplicateArtifactPath(String)
    case corruptIntent(String)
    case intentIdentityMismatch(String)
    case partialRegistration(UUID)
}

/// Durable handoff between export publication and lifecycle metadata registration.
///
/// The journal closes the process-termination gap where audio bytes have been published but the
/// lifecycle sidecar has not committed yet. Intents contain only app-owned `Exports/**` paths and
/// are removed only after metadata commit or safe compensation. A relaunch can therefore distinguish
/// committed exports from unregistered leftovers without a broad orphan sweep.
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
        let intent = Lane2ExportRegistrationIntent(
            id: id,
            projectUUID: projectUUID,
            artifacts: normalized,
            createdAt: now
        )
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encode(intent).write(to: intentURL(id: id), options: [.atomic])
        return intent
    }

    public func pending() throws -> [Lane2ExportRegistrationIntent] {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let intents: [Lane2ExportRegistrationIntent] = try urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { try loadIntent(at: $0) }
        return intents.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public func complete(intentID: UUID) throws {
        let url = intentURL(id: intentID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        _ = try loadIntent(at: url)
        try fileManager.removeItem(at: url)
        try pruneDirectoryIfEmpty()
    }

    public func exists(intentID: UUID) -> Bool {
        fileManager.fileExists(atPath: intentURL(id: intentID).path)
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

    private func loadIntent(_ url: URL) throws -> Lane2ExportRegistrationIntent {
        try loadIntent(at: url)
    }

    private func loadIntent(at url: URL) throws -> Lane2ExportRegistrationIntent {
        let filename = url.deletingPathExtension().lastPathComponent
        guard let fileID = UUID(uuidString: filename) else {
            throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let intent = try decoder.decode(Lane2ExportRegistrationIntent.self, from: Data(contentsOf: url))
            guard intent.id == fileID else {
                throw Lane2ExportRegistrationJournalFailure.intentIdentityMismatch(url.lastPathComponent)
            }
            guard !intent.artifacts.isEmpty else {
                throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
            }
            var seen = Set<String>()
            for artifact in intent.artifacts {
                let normalized = try Self.normalizeExportPath(artifact.relativePath)
                guard normalized == artifact.relativePath else {
                    throw Lane2ExportRegistrationJournalFailure.corruptIntent(url.lastPathComponent)
                }
                guard seen.insert(normalized).inserted else {
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

    private func pruneDirectoryIfEmpty() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        let children = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
        if children.isEmpty {
            try fileManager.removeItem(at: directoryURL)
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
