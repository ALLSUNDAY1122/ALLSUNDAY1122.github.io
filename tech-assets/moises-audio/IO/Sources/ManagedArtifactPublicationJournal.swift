import Foundation

public struct Lane2ManagedArtifactPublicationRecord: Codable, Hashable, Sendable {
    public let relativePath: String
    public let sessionID: String
    public let createdAtMicros: Int64

    public init(relativePath: String, sessionID: String, createdAtMicros: Int64) {
        self.relativePath = relativePath
        self.sessionID = sessionID
        self.createdAtMicros = createdAtMicros
    }
}

public struct Lane2ManagedArtifactPublicationRecoveryCursor: Codable, Hashable, Sendable {
    public let shardIndex: Int
    public let afterRelativePath: String?

    public init(shardIndex: Int, afterRelativePath: String? = nil) {
        self.shardIndex = shardIndex
        self.afterRelativePath = afterRelativePath
    }
}

public struct Lane2ManagedArtifactPublicationRecoverySlice: Hashable, Sendable {
    public let records: [Lane2ManagedArtifactPublicationRecord]
    public let visitedRecords: Int
    public let visitedShards: Int
    public let priorCursor: Lane2ManagedArtifactPublicationRecoveryCursor
    public let nextCursor: Lane2ManagedArtifactPublicationRecoveryCursor
    public let candidateLimit: Int
    public let recordVisitLimit: Int
    public let shardVisitLimit: Int

    public init(
        records: [Lane2ManagedArtifactPublicationRecord],
        visitedRecords: Int,
        visitedShards: Int,
        priorCursor: Lane2ManagedArtifactPublicationRecoveryCursor,
        nextCursor: Lane2ManagedArtifactPublicationRecoveryCursor,
        candidateLimit: Int,
        recordVisitLimit: Int,
        shardVisitLimit: Int
    ) {
        self.records = records
        self.visitedRecords = visitedRecords
        self.visitedShards = visitedShards
        self.priorCursor = priorCursor
        self.nextCursor = nextCursor
        self.candidateLimit = max(candidateLimit, 1)
        self.recordVisitLimit = max(recordVisitLimit, 1)
        self.shardVisitLimit = max(shardVisitLimit, 1)
    }
}

public enum Lane2ManagedArtifactPublicationJournalFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case priorSessionIntentExists(String)
    case corruptShard(String)
    case corruptCursor
    case publishedArtifactMissing(String)
    case publishedArtifactUnsafe(String)
}

private struct Lane2ManagedArtifactPublicationShard: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let shardIndex: Int
    var records: [Lane2ManagedArtifactPublicationRecord]
}

private struct Lane2ManagedArtifactPublicationCursorEnvelope: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let cursor: Lane2ManagedArtifactPublicationRecoveryCursor
}

/// Durable pre-publication signal for app-owned Imports/Stems/Exports artifacts.
/// Writers persist an intent before the final move/rename and retire it only after the Library
/// readiness boundary has registered the final path in the AW29 inventory.
public struct Lane2ManagedArtifactPublicationJournal: Sendable {
    public static let shardCount = 256
    public static let defaultRecoveryCandidateLimit = 64
    public static let defaultRecoveryRecordVisitLimit = 128
    public static let defaultRecoveryShardVisitLimit = 4
    public static let publicationSessionID = UUID().uuidString.lowercased()
    public static let managedRootNames = ["Imports", "Stems", "Exports"]

    public let rootURL: URL
    public let recoveryDirectoryName: String
    public let sessionID: String
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        sessionID: String = Self.publicationSessionID,
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.sessionID = sessionID
        self.fileManager = fileManager
    }

    @discardableResult
    public func begin(relativePath: String, now: Date = Date()) throws -> Lane2ManagedArtifactPublicationRecord {
        let normalized = try Self.normalize(relativePath)
        let index = Self.shardIndex(forNormalized: normalized)
        var shard = try loadShard(index)
        if let existing = shard.records.first(where: { $0.relativePath == normalized }) {
            guard existing.sessionID == sessionID else {
                throw Lane2ManagedArtifactPublicationJournalFailure.priorSessionIntentExists(normalized)
            }
            return existing
        }
        let record = Lane2ManagedArtifactPublicationRecord(
            relativePath: normalized,
            sessionID: sessionID,
            createdAtMicros: Self.micros(now)
        )
        shard.records.append(record)
        shard.records.sort(by: Self.recordLessThan)
        try writeShard(shard)
        return record
    }

    public func completeIfPresent(relativePath: String) throws {
        let normalized = try Self.normalize(relativePath)
        let url = try absoluteURL(normalized)
        guard fileManager.fileExists(atPath: url.path) else {
            throw Lane2ManagedArtifactPublicationJournalFailure.publishedArtifactMissing(normalized)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactPublicationJournalFailure.publishedArtifactUnsafe(normalized)
        }
        try remove(relativePath: normalized, expectedSessionID: nil)
    }

    public func cancelCurrentSessionIfPresent(relativePath: String) throws {
        let normalized = try Self.normalize(relativePath)
        try remove(relativePath: normalized, expectedSessionID: sessionID)
    }

    public func preparePreviousSessionRecoverySlice(
        candidateLimit: Int = Self.defaultRecoveryCandidateLimit,
        recordVisitLimit: Int = Self.defaultRecoveryRecordVisitLimit,
        shardVisitLimit: Int = Self.defaultRecoveryShardVisitLimit
    ) throws -> Lane2ManagedArtifactPublicationRecoverySlice {
        let effectiveCandidateLimit = max(candidateLimit, 1)
        let effectiveRecordLimit = max(recordVisitLimit, 1)
        let effectiveShardLimit = min(max(shardVisitLimit, 1), Self.shardCount)
        let prior = try loadRecoveryCursor()
        var cursor = prior
        var records: [Lane2ManagedArtifactPublicationRecord] = []
        var visitedRecords = 0
        var visitedShards = 0

        outer: while visitedShards < effectiveShardLimit,
                     visitedRecords < effectiveRecordLimit,
                     records.count < effectiveCandidateLimit {
            let shard = try loadShard(cursor.shardIndex)
            var completedShard = true
            for record in shard.records {
                if let after = cursor.afterRelativePath, record.relativePath <= after { continue }
                visitedRecords += 1
                cursor = Lane2ManagedArtifactPublicationRecoveryCursor(
                    shardIndex: shard.shardIndex,
                    afterRelativePath: record.relativePath
                )
                if record.sessionID != sessionID {
                    records.append(record)
                    if records.count >= effectiveCandidateLimit {
                        completedShard = false
                        break
                    }
                }
                if visitedRecords >= effectiveRecordLimit {
                    completedShard = false
                    break
                }
            }
            visitedShards += 1
            if completedShard {
                cursor = Lane2ManagedArtifactPublicationRecoveryCursor(
                    shardIndex: (shard.shardIndex + 1) % Self.shardCount,
                    afterRelativePath: nil
                )
            } else {
                break outer
            }
        }

        return Lane2ManagedArtifactPublicationRecoverySlice(
            records: records,
            visitedRecords: visitedRecords,
            visitedShards: visitedShards,
            priorCursor: prior,
            nextCursor: cursor,
            candidateLimit: effectiveCandidateLimit,
            recordVisitLimit: effectiveRecordLimit,
            shardVisitLimit: effectiveShardLimit
        )
    }

    public func resolveRecoveredRecord(_ record: Lane2ManagedArtifactPublicationRecord) throws {
        let normalized = try Self.normalize(record.relativePath)
        guard record.sessionID != sessionID else { return }
        try remove(relativePath: normalized, expectedSessionID: record.sessionID)
    }

    public func persistRecoveryCursor(after slice: Lane2ManagedArtifactPublicationRecoverySlice) throws {
        try ensureLayout()
        let envelope = Lane2ManagedArtifactPublicationCursorEnvelope(
            schemaVersion: Lane2ManagedArtifactPublicationCursorEnvelope.schemaVersion,
            cursor: slice.nextCursor
        )
        let data = try stableEncoder.encode(envelope)
        try data.write(to: recoveryCursorURL, options: [.atomic])
    }

    public func contains(relativePath: String) throws -> Bool {
        let normalized = try Self.normalize(relativePath)
        return try loadShard(Self.shardIndex(forNormalized: normalized)).records.contains {
            $0.relativePath == normalized
        }
    }

    public static func shardIndex(for relativePath: String) throws -> Int {
        shardIndex(forNormalized: try normalize(relativePath))
    }

    private func remove(relativePath: String, expectedSessionID: String?) throws {
        let index = Self.shardIndex(forNormalized: relativePath)
        var shard = try loadShard(index)
        guard let offset = shard.records.firstIndex(where: { $0.relativePath == relativePath }) else { return }
        if let expectedSessionID, shard.records[offset].sessionID != expectedSessionID { return }
        shard.records.remove(at: offset)
        try writeShard(shard)
    }

    private func ensureLayout() throws {
        try fileManager.createDirectory(at: shardDirectoryURL, withIntermediateDirectories: true)
    }

    private func loadShard(_ index: Int) throws -> Lane2ManagedArtifactPublicationShard {
        guard (0..<Self.shardCount).contains(index) else {
            throw Lane2ManagedArtifactPublicationJournalFailure.corruptShard(String(index))
        }
        let url = shardURL(index)
        guard fileManager.fileExists(atPath: url.path) else {
            return Lane2ManagedArtifactPublicationShard(
                schemaVersion: Lane2ManagedArtifactPublicationShard.schemaVersion,
                shardIndex: index,
                records: []
            )
        }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactPublicationJournalFailure.corruptShard(url.lastPathComponent)
            }
            let shard = try JSONDecoder().decode(
                Lane2ManagedArtifactPublicationShard.self,
                from: Data(contentsOf: url)
            )
            guard shard.schemaVersion == Lane2ManagedArtifactPublicationShard.schemaVersion,
                  shard.shardIndex == index else {
                throw Lane2ManagedArtifactPublicationJournalFailure.corruptShard(url.lastPathComponent)
            }
            var seen = Set<String>()
            var validated: [Lane2ManagedArtifactPublicationRecord] = []
            validated.reserveCapacity(shard.records.count)
            for record in shard.records {
                let normalized = try Self.normalize(record.relativePath)
                guard normalized == record.relativePath,
                      !record.sessionID.isEmpty,
                      Self.shardIndex(forNormalized: normalized) == index,
                      seen.insert(normalized).inserted else {
                    throw Lane2ManagedArtifactPublicationJournalFailure.corruptShard(url.lastPathComponent)
                }
                validated.append(record)
            }
            return Lane2ManagedArtifactPublicationShard(
                schemaVersion: shard.schemaVersion,
                shardIndex: shard.shardIndex,
                records: validated.sorted(by: Self.recordLessThan)
            )
        } catch let failure as Lane2ManagedArtifactPublicationJournalFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactPublicationJournalFailure.corruptShard(url.lastPathComponent)
        }
    }

    private func writeShard(_ shard: Lane2ManagedArtifactPublicationShard) throws {
        try ensureLayout()
        let url = shardURL(shard.shardIndex)
        if shard.records.isEmpty {
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
            return
        }
        let data = try stableEncoder.encode(shard)
        try data.write(to: url, options: [.atomic])
    }

    private func loadRecoveryCursor() throws -> Lane2ManagedArtifactPublicationRecoveryCursor {
        guard fileManager.fileExists(atPath: recoveryCursorURL.path) else {
            return Lane2ManagedArtifactPublicationRecoveryCursor(shardIndex: 0)
        }
        do {
            let values = try recoveryCursorURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactPublicationJournalFailure.corruptCursor
            }
            let envelope = try JSONDecoder().decode(
                Lane2ManagedArtifactPublicationCursorEnvelope.self,
                from: Data(contentsOf: recoveryCursorURL)
            )
            guard envelope.schemaVersion == Lane2ManagedArtifactPublicationCursorEnvelope.schemaVersion,
                  (0..<Self.shardCount).contains(envelope.cursor.shardIndex) else {
                throw Lane2ManagedArtifactPublicationJournalFailure.corruptCursor
            }
            if let after = envelope.cursor.afterRelativePath {
                let normalized = try Self.normalize(after)
                guard normalized == after,
                      Self.shardIndex(forNormalized: normalized) == envelope.cursor.shardIndex else {
                    throw Lane2ManagedArtifactPublicationJournalFailure.corruptCursor
                }
            }
            return envelope.cursor
        } catch let failure as Lane2ManagedArtifactPublicationJournalFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactPublicationJournalFailure.corruptCursor
        }
    }

    private func absoluteURL(_ relativePath: String) throws -> URL {
        let candidate = rootURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard candidate.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactPublicationJournalFailure.invalidRelativePath(relativePath)
        }
        return candidate
    }

    private var journalDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Publications", isDirectory: true)
    }

    private var shardDirectoryURL: URL {
        journalDirectoryURL.appendingPathComponent("Shards", isDirectory: true)
    }

    private var recoveryCursorURL: URL {
        journalDirectoryURL.appendingPathComponent("cursor.json", isDirectory: false)
    }

    private func shardURL(_ index: Int) -> URL {
        shardDirectoryURL.appendingPathComponent(String(format: "%02x.json", index), isDirectory: false)
    }

    private var stableEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func normalize(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2ManagedArtifactPublicationJournalFailure.invalidRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
              let root = parts.first,
              managedRootNames.contains(String(root)) else {
            throw Lane2ManagedArtifactPublicationJournalFailure.invalidRelativePath(relativePath)
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

    private static func recordLessThan(
        _ lhs: Lane2ManagedArtifactPublicationRecord,
        _ rhs: Lane2ManagedArtifactPublicationRecord
    ) -> Bool {
        if lhs.relativePath == rhs.relativePath { return lhs.sessionID < rhs.sessionID }
        return lhs.relativePath < rhs.relativePath
    }

    private static func micros(_ date: Date) -> Int64 {
        let scaled = date.timeIntervalSince1970 * 1_000_000
        guard scaled.isFinite else { return Int64.min }
        if scaled >= Double(Int64.max) { return Int64.max }
        if scaled <= Double(Int64.min) { return Int64.min }
        return Int64(scaled.rounded())
    }
}
