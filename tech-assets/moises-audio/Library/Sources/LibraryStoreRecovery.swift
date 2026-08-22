import Foundation

public enum LibraryStoreHealth: String, Codable, Sendable {
    case missing
    case plausibleSQLite
    case corruptOrUnreadable
}

public enum LibraryRecoveryAction: String, Codable, Sendable {
    case createFreshStore
    case openExistingStore
    case migratePreservingOriginal
    case quarantineAndRequireExplicitRecovery
}

public struct LibraryStoreRecoveryPlan: Hashable, Codable, Sendable {
    public let health: LibraryStoreHealth
    public let action: LibraryRecoveryAction
    public let originalStorePath: String
    public let recoveryRootPath: String
    public let destructiveResetAllowed: Bool

    public init(
        health: LibraryStoreHealth,
        action: LibraryRecoveryAction,
        originalStorePath: String,
        recoveryRootPath: String,
        destructiveResetAllowed: Bool = false
    ) {
        self.health = health
        self.action = action
        self.originalStorePath = originalStorePath
        self.recoveryRootPath = recoveryRootPath
        self.destructiveResetAllowed = destructiveResetAllowed
    }
}

public struct LibraryStoreFamilyMember: Hashable, Codable, Sendable {
    public let fileName: String
    public let byteCount: UInt64
    public let contentFingerprint: String
}

public struct LibraryStoreSnapshotManifest: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let reason: String
    public let createdAt: Date
    public let originalStorePath: String
    public let members: [LibraryStoreFamilyMember]

    public init(
        schemaVersion: Int = 1,
        reason: String,
        createdAt: Date,
        originalStorePath: String,
        members: [LibraryStoreFamilyMember]
    ) {
        self.schemaVersion = schemaVersion
        self.reason = reason
        self.createdAt = createdAt
        self.originalStorePath = originalStorePath
        self.members = members
    }
}

public struct LibraryStoreSnapshot: Hashable, Sendable {
    public let directoryURL: URL
    public let storeURL: URL
    public let manifestURL: URL
    public let manifest: LibraryStoreSnapshotManifest
}

public enum LibraryStoreRecoveryError: Error, Equatable, Sendable {
    case unsafeStoreURL
    case unreadableStore
    case invalidSQLiteHeader
    case snapshotFailed(String)
    case corruptSnapshot(String)
}

/// Foundation-only store-family preservation utilities used before Core Data touches an on-disk store.
/// It deliberately has no API that deletes or recreates the original store.
public struct LibraryStoreRecoveryManager: Sendable {
    public let storeURL: URL
    public let recoveryRootURL: URL

    private static let sqliteHeader = Data("SQLite format 3\0".utf8)
    private static let sidecarSuffixes = ["-wal", "-shm", "-journal"]

    public init(storeURL: URL, recoveryRootURL: URL? = nil) throws {
        guard storeURL.isFileURL, storeURL.pathExtension.lowercased() == "sqlite" else {
            throw LibraryStoreRecoveryError.unsafeStoreURL
        }
        self.storeURL = storeURL.standardizedFileURL
        self.recoveryRootURL = (recoveryRootURL ?? storeURL.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)).standardizedFileURL
    }

    public func inspect() -> LibraryStoreHealth {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return .missing }
        guard let handle = try? FileHandle(forReadingFrom: storeURL) else { return .corruptOrUnreadable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: Self.sqliteHeader.count), data == Self.sqliteHeader else {
            return .corruptOrUnreadable
        }
        return .plausibleSQLite
    }

    public func recoveryPlan() -> LibraryStoreRecoveryPlan {
        let health = inspect()
        let action: LibraryRecoveryAction
        switch health {
        case .missing: action = .createFreshStore
        case .plausibleSQLite: action = .openExistingStore
        case .corruptOrUnreadable: action = .quarantineAndRequireExplicitRecovery
        }
        return LibraryStoreRecoveryPlan(
            health: health,
            action: action,
            originalStorePath: storeURL.path,
            recoveryRootPath: recoveryRootURL.path,
            destructiveResetAllowed: false
        )
    }

    public func migrationPlan() -> LibraryStoreRecoveryPlan {
        LibraryStoreRecoveryPlan(
            health: inspect(),
            action: .migratePreservingOriginal,
            originalStorePath: storeURL.path,
            recoveryRootPath: recoveryRootURL.path,
            destructiveResetAllowed: false
        )
    }

    @discardableResult
    public func snapshotOriginal(reason: String, now: Date = Date()) throws -> LibraryStoreSnapshot {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else {
            throw LibraryStoreRecoveryError.snapshotFailed("original store missing")
        }
        try fm.createDirectory(at: recoveryRootURL, withIntermediateDirectories: true)
        let safeReason = sanitize(reason)
        let directory = recoveryRootURL
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("\(timestamp(now))-\(safeReason)-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        var members: [LibraryStoreFamilyMember] = []
        for source in existingStoreFamilyURLs() {
            let destination = directory.appendingPathComponent(source.lastPathComponent, isDirectory: false)
            do {
                try fm.copyItem(at: source, to: destination)
            } catch {
                throw LibraryStoreRecoveryError.snapshotFailed(String(describing: error))
            }
            let data = try Data(contentsOf: destination, options: [.mappedIfSafe])
            members.append(
                LibraryStoreFamilyMember(
                    fileName: destination.lastPathComponent,
                    byteCount: UInt64(data.count),
                    contentFingerprint: fnv1a64(data)
                )
            )
        }

        guard members.contains(where: { $0.fileName == storeURL.lastPathComponent }) else {
            throw LibraryStoreRecoveryError.snapshotFailed("main sqlite file missing from snapshot")
        }
        let manifest = LibraryStoreSnapshotManifest(
            reason: reason,
            createdAt: now,
            originalStorePath: storeURL.path,
            members: members.sorted { $0.fileName < $1.fileName }
        )
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        let snapshot = LibraryStoreSnapshot(
            directoryURL: directory,
            storeURL: directory.appendingPathComponent(storeURL.lastPathComponent),
            manifestURL: manifestURL,
            manifest: manifest
        )
        try validate(snapshot: snapshot)
        return snapshot
    }

    /// Creates an independent migration candidate from a verified snapshot.
    /// Migration code may modify this candidate; failure leaves the original store untouched.
    public func createWorkingCopy(from snapshot: LibraryStoreSnapshot) throws -> LibraryStoreSnapshot {
        try validate(snapshot: snapshot)
        let fm = FileManager.default
        let directory = recoveryRootURL
            .appendingPathComponent("Working", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        for member in snapshot.manifest.members {
            try fm.copyItem(
                at: snapshot.directoryURL.appendingPathComponent(member.fileName),
                to: directory.appendingPathComponent(member.fileName)
            )
        }
        let manifest = LibraryStoreSnapshotManifest(
            reason: "working-copy-from-\(snapshot.manifest.reason)",
            createdAt: Date(),
            originalStorePath: snapshot.manifest.originalStorePath,
            members: try fingerprintMembers(in: directory, names: snapshot.manifest.members.map(\.fileName))
        )
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        return LibraryStoreSnapshot(
            directoryURL: directory,
            storeURL: directory.appendingPathComponent(storeURL.lastPathComponent),
            manifestURL: manifestURL,
            manifest: manifest
        )
    }

    /// Copies a corrupt/unopenable store family for support/export without moving or deleting the original.
    public func exportRecoveryPackage(reason: String, now: Date = Date()) throws -> LibraryStoreSnapshot {
        try snapshotOriginal(reason: "recovery-export-\(reason)", now: now)
    }

    public func validate(snapshot: LibraryStoreSnapshot) throws {
        let fm = FileManager.default
        for member in snapshot.manifest.members {
            let url = snapshot.directoryURL.appendingPathComponent(member.fileName)
            guard fm.fileExists(atPath: url.path) else {
                throw LibraryStoreRecoveryError.corruptSnapshot("missing \(member.fileName)")
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard UInt64(data.count) == member.byteCount, fnv1a64(data) == member.contentFingerprint else {
                throw LibraryStoreRecoveryError.corruptSnapshot("fingerprint mismatch \(member.fileName)")
            }
        }
    }

    private func existingStoreFamilyURLs() -> [URL] {
        let fm = FileManager.default
        var urls: [URL] = []
        if fm.fileExists(atPath: storeURL.path) { urls.append(storeURL) }
        for suffix in Self.sidecarSuffixes {
            let sidecar = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: sidecar.path) { urls.append(sidecar) }
        }
        return urls
    }

    private func fingerprintMembers(in directory: URL, names: [String]) throws -> [LibraryStoreFamilyMember] {
        try names.sorted().map { name in
            let url = directory.appendingPathComponent(name)
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return LibraryStoreFamilyMember(fileName: name, byteCount: UInt64(data.count), contentFingerprint: fnv1a64(data))
        }
    }

    private func fnv1a64(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(mapped).prefix(64)
        return result.isEmpty ? "snapshot" : String(result)
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
    }
}

public struct LibraryActiveStoreManifest: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let activatedAt: Date
    public let preservedOriginalStorePath: String
    public let preservedSnapshotPath: String
    public let activeStorePath: String

    public init(
        schemaVersion: Int = 1,
        activatedAt: Date,
        preservedOriginalStorePath: String,
        preservedSnapshotPath: String,
        activeStorePath: String
    ) {
        self.schemaVersion = schemaVersion
        self.activatedAt = activatedAt
        self.preservedOriginalStorePath = preservedOriginalStorePath
        self.preservedSnapshotPath = preservedSnapshotPath
        self.activeStorePath = activeStorePath
    }
}

public extension LibraryStoreRecoveryManager {
    var activeManifestURL: URL {
        recoveryRootURL.appendingPathComponent("active-store.json", isDirectory: false)
    }

    func resolveActiveStoreManifest() throws -> LibraryActiveStoreManifest? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: activeManifestURL.path) else { return nil }
        let data = try Data(contentsOf: activeManifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LibraryActiveStoreManifest.self, from: data)
        guard manifest.schemaVersion == 1 else {
            throw LibraryStoreRecoveryError.corruptSnapshot("unsupported active manifest schema")
        }
        let activeURL = URL(fileURLWithPath: manifest.activeStorePath).standardizedFileURL
        guard activeURL.path.hasPrefix(recoveryRootURL.path + "/"),
              fm.fileExists(atPath: activeURL.path) else {
            throw LibraryStoreRecoveryError.corruptSnapshot("active store path invalid or missing")
        }
        return manifest
    }

    /// Promotes a successfully migrated working copy to a new immutable active generation.
    /// The original store and its verified snapshot remain untouched.
    func activateMigratedCopy(
        from working: LibraryStoreSnapshot,
        preservedOriginalSnapshot: LibraryStoreSnapshot,
        now: Date = Date()
    ) throws -> LibraryActiveStoreManifest {
        try validate(snapshot: preservedOriginalSnapshot)
        let fm = FileManager.default
        guard fm.fileExists(atPath: working.storeURL.path) else {
            throw LibraryStoreRecoveryError.snapshotFailed("migrated working store missing")
        }
        let activeDirectory = recoveryRootURL
            .appendingPathComponent("Active", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: activeDirectory, withIntermediateDirectories: true)

        let workingFamily = existingStoreFamilyURLs(for: working.storeURL)
        guard workingFamily.contains(where: { $0.lastPathComponent == storeURL.lastPathComponent }) else {
            throw LibraryStoreRecoveryError.snapshotFailed("migrated main store missing")
        }
        for source in workingFamily {
            try fm.copyItem(at: source, to: activeDirectory.appendingPathComponent(source.lastPathComponent))
        }
        let activeStoreURL = activeDirectory.appendingPathComponent(storeURL.lastPathComponent)
        let activeManager = try LibraryStoreRecoveryManager(storeURL: activeStoreURL, recoveryRootURL: recoveryRootURL)
        guard activeManager.inspect() == .plausibleSQLite else {
            throw LibraryStoreRecoveryError.invalidSQLiteHeader
        }

        let manifest = LibraryActiveStoreManifest(
            activatedAt: now,
            preservedOriginalStorePath: storeURL.path,
            preservedSnapshotPath: preservedOriginalSnapshot.directoryURL.path,
            activeStorePath: activeStoreURL.path
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: activeManifestURL, options: .atomic)
        return manifest
    }

    private func existingStoreFamilyURLs(for mainURL: URL) -> [URL] {
        let fm = FileManager.default
        var urls: [URL] = []
        if fm.fileExists(atPath: mainURL.path) { urls.append(mainURL) }
        for suffix in ["-wal", "-shm", "-journal"] {
            let sidecar = URL(fileURLWithPath: mainURL.path + suffix)
            if fm.fileExists(atPath: sidecar.path) { urls.append(sidecar) }
        }
        return urls
    }
}
