import Foundation

public struct Lane2ManagedArtifactInventoryCandidate: Hashable, Sendable {
    public let relativePath: String
    public let recordedModificationTime: TimeInterval
    public init(relativePath: String, recordedModificationTime: TimeInterval) {
        self.relativePath = relativePath
        self.recordedModificationTime = recordedModificationTime
    }
}

public struct Lane2ManagedArtifactInventoryTraversal: Codable, Hashable, Sendable {
    public let shardIndex: Int
    public let afterRelativePath: String?
    public init(shardIndex: Int, afterRelativePath: String? = nil) {
        self.shardIndex = shardIndex
        self.afterRelativePath = afterRelativePath
    }
}

public struct Lane2ManagedArtifactInventorySlice: Hashable, Sendable {
    public let candidates: [Lane2ManagedArtifactInventoryCandidate]
    public let scannedInventoryEntries: Int
    public let visitedShards: Int
    public let candidateLimit: Int
    public let shardVisitLimit: Int
    public let priorTraversal: Lane2ManagedArtifactInventoryTraversal
    public let nextTraversal: Lane2ManagedArtifactInventoryTraversal
    public init(candidates: [Lane2ManagedArtifactInventoryCandidate], scannedInventoryEntries: Int, visitedShards: Int, candidateLimit: Int, shardVisitLimit: Int, priorTraversal: Lane2ManagedArtifactInventoryTraversal, nextTraversal: Lane2ManagedArtifactInventoryTraversal) {
        self.candidates = candidates
        self.scannedInventoryEntries = scannedInventoryEntries
        self.visitedShards = visitedShards
        self.candidateLimit = max(candidateLimit, 1)
        self.shardVisitLimit = max(shardVisitLimit, 1)
        self.priorTraversal = priorTraversal
        self.nextTraversal = nextTraversal
    }
}

public enum Lane2ManagedArtifactInventoryFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case unsafeManagedArtifact(String)
    case corruptShard(String)
    case corruptTraversalCursor
    case incompatibleManagedRoots
}

/// Foundation's FileManager is explicitly non-Sendable in current Apple SDKs.
/// Keep the unchecked compatibility assertion private to the injected dependency.
private final class Lane2ManagedArtifactInventoryFileManagerHandle: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}

/// Canonical managed-artifact inventory facade.
///
/// AW42 keeps the public AW29 contract stable while routing steady-state registration, removal,
/// candidate preparation and cursor persistence through the AW41 bridge/AW40 segmented runtime.
/// Legacy v1 shards remain readable rollback/upgrade evidence but are no longer rewritten here.
public struct Lane2ManagedArtifactInventory: Sendable {
    public static let shardCount = 256
    public static let defaultShardVisitLimit = 4
    public static let defaultCandidateLimit = 128
    public static let managedRootNames = ["Imports", "Stems", "Exports"]

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManagerHandle: Lane2ManagedArtifactInventoryFileManagerHandle

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery", fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManagerHandle = Lane2ManagedArtifactInventoryFileManagerHandle(fileManager)
    }

    var inventoryFileManager: FileManager {
        fileManagerHandle.value
    }

    private var fileManager: FileManager {
        inventoryFileManager
    }

    private var descriptorIO: Lane2LibraryDescriptorRelativeIO {
        Lane2LibraryDescriptorRelativeIO(rootURL: rootURL)
    }

    private var pathAuthority: Lane2ManagedArtifactInventoryPathAuthority {
        Lane2ManagedArtifactInventoryPathAuthority(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
    }

    public var isAuthoritative: Bool {
        hasValidAuthoritativeMarker
    }

    @discardableResult
    public func initializeFreshAuthoritativeIfNoManagedArtifacts() throws -> Bool {
        if isAuthoritative { return true }
        for rootName in Self.managedRootNames {
            let url = pathAuthority.managedRootURL(rootName)
            do {
                guard try pathAuthority.requireManagedRootIfPresent(rootName) else { continue }
            } catch {
                return false
            }
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in false }
            ) else { return false }
            if enumerator.nextObject() != nil { return false }
        }
        try markAuthoritativeAfterCompatibilityCensus()
        return true
    }

    public func markAuthoritativeAfterCompatibilityCensus() throws {
        do {
            try pathAuthority.ensureV1Directory()
            _ = try pathAuthority.requireRegularFileOrMissing(
                authoritativeMarkerURL,
                within: inventoryDirectoryURL
            )
            try descriptorIO.writeRegularFileAtomically(
                Data("lane2-managed-artifact-inventory-v1\n".utf8),
                to: authoritativeMarkerURL
            )
            try pathAuthority.requireExistingRegularFile(
                authoritativeMarkerURL,
                within: inventoryDirectoryURL
            )
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(
                authoritativeMarkerURL.path
            )
        }
    }

    public func canServe(managedRootNames: [String]) -> Bool {
        managedRootNames.map { $0.replacingOccurrences(of: "\\", with: "/") }.sorted() == Self.managedRootNames.sorted()
    }

    @discardableResult
    public func registerIfManaged(relativePath: String) throws -> Bool {
        let normalized = try Self.normalize(relativePath)
        guard Self.isManaged(normalized) else { return false }
        let url = try absoluteURL(normalized)
        let rootName = String(normalized.split(separator: "/", omittingEmptySubsequences: false)[0])
        do {
            guard try pathAuthority.requireManagedRegularFileIfPresent(
                url,
                managedRootName: rootName
            ) else { return false }
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(normalized)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(normalized)
        }
        try bridge.registerManaged(relativePaths: [normalized])
        return true
    }

    public func registerManaged(relativePaths: [String]) throws {
        let normalized = try Array(Set(relativePaths)).sorted().map { path -> String in
            let value = try Self.normalize(path)
            guard Self.isManaged(value) else { throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(path) }
            return value
        }
        try bridge.registerManaged(relativePaths: normalized)
    }

    public func remove(relativePaths: [String]) throws {
        let normalized = try Array(Set(relativePaths)).map(Self.normalize).filter(Self.isManaged)
        try bridge.remove(relativePaths: normalized)
    }

    public func prepareOrphanCandidateSlice(gracePeriod: TimeInterval = 3600, now: Date = Date(), candidateLimit: Int = Self.defaultCandidateLimit, shardVisitLimit: Int = Self.defaultShardVisitLimit) throws -> Lane2ManagedArtifactInventorySlice {
        guard isAuthoritative else { throw Lane2ManagedArtifactInventoryFailure.incompatibleManagedRoots }
        return try bridge.prepareOrphanCandidateSlice(gracePeriod: gracePeriod, now: now, candidateLimit: candidateLimit, shardVisitLimit: shardVisitLimit)
    }

    public func applyOrphanCandidateSlice(_ slice: Lane2ManagedArtifactInventorySlice, referencedRelativePaths: Set<String>, gracePeriod: TimeInterval = 3600, now: Date = Date()) throws -> LibraryOrphanSweepResult {
        let referenced = Set(try referencedRelativePaths.map(Self.normalize))
        var removed: [String] = []
        var staleInventoryPaths: [String] = []
        var refreshPaths: [String] = []
        var retainedReferenced = 0
        var retainedYoung = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]

        for candidate in slice.candidates {
            let relativePath = try Self.normalize(candidate.relativePath)
            guard Self.isManaged(relativePath) else { throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath) }
            if referenced.contains(relativePath) { retainedReferenced += 1; continue }
            let url = try absoluteURL(relativePath)
            let rootName = String(relativePath.split(separator: "/", omittingEmptySubsequences: false)[0])
            do {
                guard try pathAuthority.requireManagedRegularFileIfPresent(
                    url,
                    managedRootName: rootName
                ) else {
                    staleInventoryPaths.append(relativePath)
                    continue
                }
            } catch {
                throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(relativePath)
            }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isRegularFile == true else { throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(relativePath) }
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) < gracePeriod {
                retainedYoung += 1
                refreshPaths.append(relativePath)
                continue
            }
            do {
                try pathAuthority.requireExistingRegularFile(
                    url,
                    within: pathAuthority.managedRootURL(rootName)
                )
                try fileManager.removeItem(at: url)
                removed.append(relativePath)
                staleInventoryPaths.append(relativePath)
            } catch let failure as Lane2ManagedArtifactInventoryFailure {
                throw failure
            } catch let failure as LibraryManagedPathBoundaryFailure {
                _ = failure
                throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(relativePath)
            } catch {
                throw LibraryArtifactFailure.cleanupFailed(relativePath)
            }
        }

        try bridge.remove(relativePaths: staleInventoryPaths)
        try bridge.registerManaged(relativePaths: refreshPaths)
        return LibraryOrphanSweepResult(scanned: slice.scannedInventoryEntries, removed: removed.sorted(), retainedReferenced: retainedReferenced, retainedYoung: retainedYoung)
    }

    public func persistTraversal(after slice: Lane2ManagedArtifactInventorySlice) throws {
        try bridge.persistTraversal(after: slice)
    }

    public static func shardIndex(for relativePath: String) throws -> Int {
        shardIndex(forNormalized: try normalize(relativePath))
    }

    private var bridge: Lane2ManagedArtifactInventorySegmentedBridge {
        Lane2ManagedArtifactInventorySegmentedBridge(rootURL: rootURL, recoveryDirectoryName: recoveryDirectoryName, fileManager: fileManager)
    }

    private func absoluteURL(_ relativePath: String) throws -> URL {
        let normalized = try Self.normalize(relativePath)
        let candidate = rootURL.appendingPathComponent(normalized, isDirectory: false).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard candidate.path.hasPrefix(prefix) else { throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath) }
        return candidate
    }

    private var inventoryDirectoryURL: URL {
        pathAuthority.v1DirectoryURL
    }
    private var authoritativeMarkerURL: URL { pathAuthority.authoritativeMarkerURL }

    private static func isManaged(_ relativePath: String) -> Bool {
        guard let root = relativePath.split(separator: "/", omittingEmptySubsequences: false).first else { return false }
        return managedRootNames.contains(String(root))
    }

    private static func normalize(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty, !normalized.hasPrefix("/"), !normalized.contains("\0"), !(normalized as NSString).isAbsolutePath else { throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath) }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath) }
        return parts.joined(separator: "/")
    }

    private static func shardIndex(forNormalized relativePath: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in relativePath.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
        return Int(hash % UInt64(shardCount))
    }
}
