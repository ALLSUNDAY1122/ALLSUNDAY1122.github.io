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

    public init(
        candidates: [Lane2ManagedArtifactInventoryCandidate],
        scannedInventoryEntries: Int,
        visitedShards: Int,
        candidateLimit: Int,
        shardVisitLimit: Int,
        priorTraversal: Lane2ManagedArtifactInventoryTraversal,
        nextTraversal: Lane2ManagedArtifactInventoryTraversal
    ) {
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

private struct Lane2ManagedArtifactInventoryEntry: Codable, Hashable, Sendable {
    let relativePath: String
    let modificationTime: TimeInterval
}

private struct Lane2ManagedArtifactInventoryShard: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let shardIndex: Int
    var entries: [Lane2ManagedArtifactInventoryEntry]
}

private struct Lane2ManagedArtifactInventoryCursor: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let traversal: Lane2ManagedArtifactInventoryTraversal
}

/// Durable steady-state inventory for app-owned Imports/Stems/Exports artifacts.
///
/// The inventory is deliberately not assumed authoritative for an upgraded installation until a
/// compatibility census says so. Fresh installations can become authoritative before any managed
/// root exists. Once authoritative, orphan maintenance reads only a bounded number of deterministic
/// shard snapshots rather than walking every managed filesystem entry on every pass.
public struct Lane2ManagedArtifactInventory: Sendable {
    public static let shardCount = 256
    public static let defaultShardVisitLimit = 4
    public static let defaultCandidateLimit = 128
    public static let managedRootNames = ["Imports", "Stems", "Exports"]

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    public var isAuthoritative: Bool {
        fileManager.fileExists(atPath: authoritativeMarkerURL.path)
    }

    /// Safe fresh-install activation. Existing managed content never becomes authoritative merely
    /// because AW29 is present; upgrades must complete an explicit compatibility census first.
    @discardableResult
    public func initializeFreshAuthoritativeIfNoManagedArtifacts() throws -> Bool {
        if isAuthoritative { return true }
        for rootName in Self.managedRootNames {
            let url = rootURL.appendingPathComponent(rootName, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            guard isDirectory.boolValue else { return false }
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in false }
            ) else { return false }
            if enumerator.nextObject() != nil { return false }
        }
        try markAuthoritativeAfterCompatibilityCensus()
        return true
    }

    public func markAuthoritativeAfterCompatibilityCensus() throws {
        try ensureLayout()
        let data = Data("lane2-managed-artifact-inventory-v1\n".utf8)
        try data.write(to: authoritativeMarkerURL, options: [.atomic])
    }

    public func canServe(managedRootNames: [String]) -> Bool {
        let normalized = managedRootNames.map { $0.replacingOccurrences(of: "\\", with: "/") }.sorted()
        return normalized == Self.managedRootNames.sorted()
    }

    /// Registers a path only when it is below one of the standard managed roots. Non-managed staging
    /// paths are intentionally ignored so callers may use this safely from generic readiness checks.
    @discardableResult
    public func registerIfManaged(relativePath: String) throws -> Bool {
        let normalized = try Self.normalize(relativePath)
        guard Self.isManaged(normalized) else { return false }
        guard let snapshot = try snapshot(relativePath: normalized) else { return false }
        try upsert(entries: [snapshot])
        return true
    }

    public func registerManaged(relativePaths: [String]) throws {
        var snapshots: [Lane2ManagedArtifactInventoryEntry] = []
        snapshots.reserveCapacity(relativePaths.count)
        for path in Array(Set(relativePaths)).sorted() {
            let normalized = try Self.normalize(path)
            guard Self.isManaged(normalized) else {
                throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(path)
            }
            guard let item = try snapshot(relativePath: normalized) else { continue }
            snapshots.append(item)
        }
        try upsert(entries: snapshots)
    }

    public func remove(relativePaths: [String]) throws {
        var pathsByShard: [Int: Set<String>] = [:]
        for path in Array(Set(relativePaths)) {
            let normalized = try Self.normalize(path)
            guard Self.isManaged(normalized) else { continue }
            pathsByShard[Self.shardIndex(forNormalized: normalized), default: []].insert(normalized)
        }
        for (shardIndex, removals) in pathsByShard {
            var shard = try loadShard(shardIndex)
            let originalCount = shard.entries.count
            shard.entries.removeAll { removals.contains($0.relativePath) }
            if shard.entries.count != originalCount {
                try writeShard(shard)
            }
        }
    }

    public func prepareOrphanCandidateSlice(
        gracePeriod: TimeInterval = 3600,
        now: Date = Date(),
        candidateLimit: Int = Self.defaultCandidateLimit,
        shardVisitLimit: Int = Self.defaultShardVisitLimit
    ) throws -> Lane2ManagedArtifactInventorySlice {
        guard isAuthoritative else {
            throw Lane2ManagedArtifactInventoryFailure.incompatibleManagedRoots
        }
        let effectiveCandidateLimit = max(candidateLimit, 1)
        let effectiveShardVisitLimit = min(max(shardVisitLimit, 1), Self.shardCount)
        let prior = try loadTraversal()
        var traversal = prior
        var visitedShards = 0
        var scannedEntries = 0
        var candidates: [Lane2ManagedArtifactInventoryCandidate] = []

        while visitedShards < effectiveShardVisitLimit && candidates.count < effectiveCandidateLimit {
            let shard = try loadShard(traversal.shardIndex)
            let after = traversal.afterRelativePath
            var completedShard = true
            for entry in shard.entries where after == nil || entry.relativePath > after! {
                scannedEntries += 1
                traversal = Lane2ManagedArtifactInventoryTraversal(
                    shardIndex: shard.shardIndex,
                    afterRelativePath: entry.relativePath
                )
                if now.timeIntervalSince1970 - entry.modificationTime >= gracePeriod {
                    candidates.append(
                        Lane2ManagedArtifactInventoryCandidate(
                            relativePath: entry.relativePath,
                            recordedModificationTime: entry.modificationTime
                        )
                    )
                    if candidates.count >= effectiveCandidateLimit {
                        completedShard = false
                        break
                    }
                }
            }

            if completedShard {
                traversal = Lane2ManagedArtifactInventoryTraversal(
                    shardIndex: (shard.shardIndex + 1) % Self.shardCount,
                    afterRelativePath: nil
                )
                visitedShards += 1
            } else {
                // The current shard remains active and resumes after the last scanned entry.
                visitedShards += 1
                break
            }
        }

        return Lane2ManagedArtifactInventorySlice(
            candidates: candidates,
            scannedInventoryEntries: scannedEntries,
            visitedShards: visitedShards,
            candidateLimit: effectiveCandidateLimit,
            shardVisitLimit: effectiveShardVisitLimit,
            priorTraversal: prior,
            nextTraversal: traversal
        )
    }

    public func applyOrphanCandidateSlice(
        _ slice: Lane2ManagedArtifactInventorySlice,
        referencedRelativePaths: Set<String>,
        gracePeriod: TimeInterval = 3600,
        now: Date = Date()
    ) throws -> LibraryOrphanSweepResult {
        let referenced = Set(try referencedRelativePaths.map(Self.normalize))
        var removed: [String] = []
        var staleInventoryPaths: [String] = []
        var refreshed: [Lane2ManagedArtifactInventoryEntry] = []
        var retainedReferenced = 0
        var retainedYoung = 0
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ]

        for candidate in slice.candidates {
            let relativePath = try Self.normalize(candidate.relativePath)
            guard Self.isManaged(relativePath) else {
                throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath)
            }
            if referenced.contains(relativePath) {
                retainedReferenced += 1
                continue
            }

            let url = try absoluteURL(relativePath)
            guard fileManager.fileExists(atPath: url.path) else {
                staleInventoryPaths.append(relativePath)
                continue
            }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(relativePath)
            }
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) < gracePeriod {
                retainedYoung += 1
                refreshed.append(
                    Lane2ManagedArtifactInventoryEntry(
                        relativePath: relativePath,
                        modificationTime: modified.timeIntervalSince1970
                    )
                )
                continue
            }

            do {
                try fileManager.removeItem(at: url)
                removed.append(relativePath)
                staleInventoryPaths.append(relativePath)
            } catch {
                throw LibraryArtifactFailure.cleanupFailed(relativePath)
            }
        }

        // Inventory changes happen only after filesystem decisions. If this persistence fails after a
        // file removal, the stale record is harmless and will converge as missing on the next pass.
        try remove(relativePaths: staleInventoryPaths)
        try upsert(entries: refreshed)

        return LibraryOrphanSweepResult(
            scanned: slice.scannedInventoryEntries,
            removed: removed.sorted(),
            retainedReferenced: retainedReferenced,
            retainedYoung: retainedYoung
        )
    }

    public func persistTraversal(after slice: Lane2ManagedArtifactInventorySlice) throws {
        try ensureLayout()
        let cursor = Lane2ManagedArtifactInventoryCursor(
            schemaVersion: Lane2ManagedArtifactInventoryCursor.schemaVersion,
            traversal: slice.nextTraversal
        )
        let data = try stableEncoder.encode(cursor)
        try data.write(to: traversalCursorURL, options: [.atomic])
    }

    public static func shardIndex(for relativePath: String) throws -> Int {
        shardIndex(forNormalized: try normalize(relativePath))
    }

    private func ensureLayout() throws {
        try fileManager.createDirectory(at: shardDirectoryURL, withIntermediateDirectories: true)
    }

    private func snapshot(relativePath: String) throws -> Lane2ManagedArtifactInventoryEntry? {
        let url = try absoluteURL(relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(relativePath)
        }
        return Lane2ManagedArtifactInventoryEntry(
            relativePath: relativePath,
            modificationTime: (values.contentModificationDate ?? .distantPast).timeIntervalSince1970
        )
    }

    private func upsert(entries: [Lane2ManagedArtifactInventoryEntry]) throws {
        guard !entries.isEmpty else { return }
        var grouped: [Int: [Lane2ManagedArtifactInventoryEntry]] = [:]
        for entry in entries {
            grouped[Self.shardIndex(forNormalized: entry.relativePath), default: []].append(entry)
        }
        for (index, updates) in grouped {
            var shard = try loadShard(index)
            var byPath = Dictionary(uniqueKeysWithValues: shard.entries.map { ($0.relativePath, $0) })
            for update in updates { byPath[update.relativePath] = update }
            shard.entries = byPath.values.sorted { $0.relativePath < $1.relativePath }
            try writeShard(shard)
        }
    }

    private func loadShard(_ index: Int) throws -> Lane2ManagedArtifactInventoryShard {
        guard (0..<Self.shardCount).contains(index) else {
            throw Lane2ManagedArtifactInventoryFailure.corruptShard(String(index))
        }
        let url = shardURL(index)
        guard fileManager.fileExists(atPath: url.path) else {
            return Lane2ManagedArtifactInventoryShard(
                schemaVersion: Lane2ManagedArtifactInventoryShard.schemaVersion,
                shardIndex: index,
                entries: []
            )
        }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
            }
            let shard = try JSONDecoder().decode(
                Lane2ManagedArtifactInventoryShard.self,
                from: Data(contentsOf: url)
            )
            guard shard.schemaVersion == Lane2ManagedArtifactInventoryShard.schemaVersion,
                  shard.shardIndex == index else {
                throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
            }
            var seen = Set<String>()
            var validated: [Lane2ManagedArtifactInventoryEntry] = []
            validated.reserveCapacity(shard.entries.count)
            for entry in shard.entries {
                let normalized = try Self.normalize(entry.relativePath)
                guard normalized == entry.relativePath,
                      Self.isManaged(normalized),
                      Self.shardIndex(forNormalized: normalized) == index,
                      seen.insert(normalized).inserted else {
                    throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
                }
                validated.append(entry)
            }
            return Lane2ManagedArtifactInventoryShard(
                schemaVersion: shard.schemaVersion,
                shardIndex: shard.shardIndex,
                entries: validated.sorted { $0.relativePath < $1.relativePath }
            )
        } catch let failure as Lane2ManagedArtifactInventoryFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptShard(url.lastPathComponent)
        }
    }

    private func writeShard(_ shard: Lane2ManagedArtifactInventoryShard) throws {
        try ensureLayout()
        let url = shardURL(shard.shardIndex)
        if shard.entries.isEmpty {
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
            return
        }
        let data = try stableEncoder.encode(shard)
        try data.write(to: url, options: [.atomic])
    }

    private func loadTraversal() throws -> Lane2ManagedArtifactInventoryTraversal {
        let url = traversalCursorURL
        guard fileManager.fileExists(atPath: url.path) else {
            return Lane2ManagedArtifactInventoryTraversal(shardIndex: 0)
        }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
            }
            let record = try JSONDecoder().decode(
                Lane2ManagedArtifactInventoryCursor.self,
                from: Data(contentsOf: url)
            )
            guard record.schemaVersion == Lane2ManagedArtifactInventoryCursor.schemaVersion,
                  (0..<Self.shardCount).contains(record.traversal.shardIndex) else {
                throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
            }
            if let after = record.traversal.afterRelativePath {
                let normalized = try Self.normalize(after)
                guard normalized == after,
                      Self.shardIndex(forNormalized: normalized) == record.traversal.shardIndex else {
                    throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
                }
            }
            return record.traversal
        } catch let failure as Lane2ManagedArtifactInventoryFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor
        }
    }

    private func absoluteURL(_ relativePath: String) throws -> URL {
        let normalized = try Self.normalize(relativePath)
        let candidate = rootURL.appendingPathComponent(normalized, isDirectory: false).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard candidate.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath)
        }
        return candidate
    }

    private var inventoryDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }

    private var shardDirectoryURL: URL {
        inventoryDirectoryURL.appendingPathComponent("Shards", isDirectory: true)
    }

    private var authoritativeMarkerURL: URL {
        inventoryDirectoryURL.appendingPathComponent("authoritative", isDirectory: false)
    }

    private var traversalCursorURL: URL {
        inventoryDirectoryURL.appendingPathComponent("cursor.json", isDirectory: false)
    }

    private func shardURL(_ index: Int) -> URL {
        shardDirectoryURL.appendingPathComponent(
            String(format: "%02x.json", index),
            isDirectory: false
        )
    }

    private var stableEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func isManaged(_ relativePath: String) -> Bool {
        guard let root = relativePath.split(separator: "/", omittingEmptySubsequences: false).first else {
            return false
        }
        return managedRootNames.contains(String(root))
    }

    private static func normalize(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath)
        }
        return parts.joined(separator: "/")
    }

    private static func shardIndex(forNormalized relativePath: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in relativePath.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(shardCount))
    }
}
