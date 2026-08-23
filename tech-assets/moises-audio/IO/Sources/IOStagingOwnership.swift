import Foundation

public struct IOStagingOwnershipRecord: Codable, Equatable, Sendable {
    public let token: String
    public var stagingFilename: String
    public let reservedBytes: Int64
    public var writtenBytes: Int64
    public var heartbeatAt: Date
    public var expiresAt: Date

    public init(
        token: String,
        stagingFilename: String,
        reservedBytes: Int64,
        writtenBytes: Int64 = 0,
        heartbeatAt: Date,
        expiresAt: Date
    ) {
        self.token = token
        self.stagingFilename = stagingFilename
        self.reservedBytes = reservedBytes
        self.writtenBytes = writtenBytes
        self.heartbeatAt = heartbeatAt
        self.expiresAt = expiresAt
    }

    public var remainingReservedBytes: Int64 {
        max(0, reservedBytes - writtenBytes)
    }
}

public enum IOStagingOwnershipError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidToken
    case invalidStagingFilename
    case ledgerUnavailable
    case leaseMissing
    case leaseCorrupt
}

/// Process-safe admission and durable ownership ledger for app-owned Staging files.
///
/// The on-disk lease survives process death. Recovery may delete a staging candidate only after the
/// lease expires (or a corrupt lease itself becomes stale). In-process mutations are serialized so
/// multiple importer instances cannot all preflight against the same free-space snapshot.
public final class IOStagingOwnershipRegistry: @unchecked Sendable {
    private static let processLock = NSLock()

    private let fileStore: IOFileStore
    private let storageReserveBytes: Int64
    private let leaseDuration: TimeInterval
    private let fileManager: FileManager

    public init(
        fileStore: IOFileStore,
        storageReserveBytes: Int64,
        leaseDuration: TimeInterval = 2 * 60 * 60,
        fileManager: FileManager = .default
    ) {
        self.fileStore = fileStore
        self.storageReserveBytes = storageReserveBytes
        self.leaseDuration = leaseDuration
        self.fileManager = fileManager
    }

    public var ledgerURL: URL {
        fileStore.rootURL
            .appendingPathComponent(".IORecovery", isDirectory: true)
            .appendingPathComponent("StagingOwnership", isDirectory: true)
    }

    public func acquire(
        token: String,
        stagingFilename: String,
        reservedBytes: Int64,
        now: Date = Date()
    ) throws -> IOStagingOwnershipLease {
        guard storageReserveBytes >= 0,
              leaseDuration.isFinite,
              leaseDuration > 0,
              reservedBytes > 0 else {
            throw IOStagingOwnershipError.invalidConfiguration
        }
        guard Self.isValidToken(token) else { throw IOStagingOwnershipError.invalidToken }
        guard Self.isValidStagingFilename(stagingFilename, token: token) else {
            throw IOStagingOwnershipError.invalidStagingFilename
        }

        try Self.processLock.withCriticalSection {
            try prepareLedgerDirectory()
            let active = try activeRecordsLocked(now: now, removeExpired: true)
            let existingRemaining = try Self.totalRemainingReservation(active)
            let combined = existingRemaining.addingReportingOverflow(reservedBytes)
            let required = combined.overflow ? Int64.max : combined.partialValue
            try fileStore.preflight(
                requiredBytes: required,
                reserveBytes: storageReserveBytes,
                fileManager: fileManager
            )

            let record = IOStagingOwnershipRecord(
                token: token,
                stagingFilename: stagingFilename,
                reservedBytes: reservedBytes,
                heartbeatAt: now,
                expiresAt: now.addingTimeInterval(leaseDuration)
            )
            try writeLocked(record)
        }
        return IOStagingOwnershipLease(registry: self, token: token)
    }

    public func update(
        token: String,
        writtenBytes: Int64? = nil,
        stagingFilename: String? = nil,
        now: Date = Date()
    ) throws {
        try Self.processLock.withCriticalSection {
            var record = try readLocked(token: token)
            if let writtenBytes {
                record.writtenBytes = min(record.reservedBytes, max(record.writtenBytes, writtenBytes))
            }
            if let stagingFilename {
                guard Self.isValidStagingFilename(stagingFilename, token: token) else {
                    throw IOStagingOwnershipError.invalidStagingFilename
                }
                record.stagingFilename = stagingFilename
            }
            record.heartbeatAt = now
            record.expiresAt = now.addingTimeInterval(leaseDuration)
            try writeLocked(record)
        }
    }

    public func release(token: String) {
        guard Self.isValidToken(token) else { return }
        Self.processLock.withCriticalSection {
            try? fileManager.removeItem(at: recordURL(token: token))
        }
    }

    /// Returns true when a durable lease protects this exact Staging filename.
    /// A fresh corrupt lease fails closed because the token encoded in the staging filename still
    /// identifies its lease file; stale corrupt leases may be removed after `corruptRecordGrace`.
    public func isProtected(
        stagingFilename: String,
        now: Date = Date(),
        corruptRecordGrace: TimeInterval
    ) throws -> Bool {
        guard corruptRecordGrace.isFinite, corruptRecordGrace >= 0 else {
            throw IOStagingOwnershipError.invalidConfiguration
        }
        guard let token = Self.token(fromStagingFilename: stagingFilename) else { return false }
        return Self.processLock.withCriticalSection {
            let url = recordURL(token: token)
            guard fileManager.fileExists(atPath: url.path) else { return false }
            do {
                let record = try decodeRecord(at: url)
                guard record.token == token, record.stagingFilename == stagingFilename else {
                    throw IOStagingOwnershipError.leaseCorrupt
                }
                if record.expiresAt > now { return true }
                try? fileManager.removeItem(at: url)
                return false
            } catch {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                if let modified = values?.contentModificationDate,
                   modified > now.addingTimeInterval(-corruptRecordGrace) {
                    return true
                }
                try? fileManager.removeItem(at: url)
                return false
            }
        }
    }

    @discardableResult
    public func sweepExpired(now: Date = Date()) throws -> [String] {
        try Self.processLock.withCriticalSection {
            try prepareLedgerDirectory()
            let before = try leaseFilesLocked()
            _ = try activeRecordsLocked(now: now, removeExpired: true)
            let after = Set(try leaseFilesLocked().map(\.lastPathComponent))
            return before.map(\.lastPathComponent).filter { !after.contains($0) }.sorted()
        }
    }

    public static func totalRemainingReservation(_ records: [IOStagingOwnershipRecord]) throws -> Int64 {
        var total: Int64 = 0
        for record in records {
            let next = total.addingReportingOverflow(record.remainingReservedBytes)
            if next.overflow { return Int64.max }
            total = next.partialValue
        }
        return total
    }

    private func activeRecordsLocked(now: Date, removeExpired: Bool) throws -> [IOStagingOwnershipRecord] {
        var records: [IOStagingOwnershipRecord] = []
        for url in try leaseFilesLocked() {
            let record = try decodeRecord(at: url)
            if record.expiresAt <= now {
                if removeExpired { try? fileManager.removeItem(at: url) }
                continue
            }
            records.append(record)
        }
        return records
    }

    private func leaseFilesLocked() throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: ledgerURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "json" }
        } catch {
            throw IOStagingOwnershipError.ledgerUnavailable
        }
    }

    private func prepareLedgerDirectory() throws {
        do {
            try fileManager.createDirectory(at: ledgerURL, withIntermediateDirectories: true)
        } catch {
            throw IOStagingOwnershipError.ledgerUnavailable
        }
    }

    private func readLocked(token: String) throws -> IOStagingOwnershipRecord {
        guard Self.isValidToken(token) else { throw IOStagingOwnershipError.invalidToken }
        let url = recordURL(token: token)
        guard fileManager.fileExists(atPath: url.path) else { throw IOStagingOwnershipError.leaseMissing }
        let record = try decodeRecord(at: url)
        guard record.token == token else { throw IOStagingOwnershipError.leaseCorrupt }
        return record
    }

    private func decodeRecord(at url: URL) throws -> IOStagingOwnershipRecord {
        do {
            return try JSONDecoder().decode(IOStagingOwnershipRecord.self, from: Data(contentsOf: url))
        } catch {
            throw IOStagingOwnershipError.leaseCorrupt
        }
    }

    private func writeLocked(_ record: IOStagingOwnershipRecord) throws {
        do {
            let data = try JSONEncoder().encode(record)
            try data.write(to: recordURL(token: record.token), options: .atomic)
        } catch let error as IOStagingOwnershipError {
            throw error
        } catch {
            throw IOStagingOwnershipError.ledgerUnavailable
        }
    }

    private func recordURL(token: String) -> URL {
        ledgerURL.appendingPathComponent(token).appendingPathExtension("json")
    }

    private static func token(fromStagingFilename filename: String) -> String? {
        guard let first = filename.split(separator: ".", maxSplits: 1).first else { return nil }
        let token = String(first)
        return isValidToken(token) ? token : nil
    }

    private static func isValidToken(_ token: String) -> Bool {
        UUID(uuidString: token) != nil && !token.contains("/") && !token.contains("\\")
    }

    private static func isValidStagingFilename(_ filename: String, token: String) -> Bool {
        !filename.isEmpty
            && !filename.contains("/")
            && !filename.contains("\\")
            && filename.hasPrefix(token + ".")
    }
}

public final class IOStagingOwnershipLease: @unchecked Sendable {
    private let registry: IOStagingOwnershipRegistry
    public let token: String
    private let stateLock = NSLock()
    private var released = false
    private var lastWrittenBytes: Int64 = 0

    fileprivate init(registry: IOStagingOwnershipRegistry, token: String) {
        self.registry = registry
        self.token = token
    }

    public func heartbeat(writtenBytes: Int64? = nil, now: Date = Date()) throws {
        let value: Int64? = stateLock.withCriticalSection {
            guard !released else { return nil }
            if let writtenBytes { lastWrittenBytes = max(lastWrittenBytes, writtenBytes) }
            return lastWrittenBytes
        }
        guard let value else { throw IOStagingOwnershipError.leaseMissing }
        try registry.update(token: token, writtenBytes: value, now: now)
    }

    public func retarget(stagingFilename: String, writtenBytes: Int64, now: Date = Date()) throws {
        stateLock.withCriticalSection { lastWrittenBytes = max(lastWrittenBytes, writtenBytes) }
        try registry.update(
            token: token,
            writtenBytes: writtenBytes,
            stagingFilename: stagingFilename,
            now: now
        )
    }

    public func release() {
        let shouldRelease = stateLock.withCriticalSection { () -> Bool in
            guard !released else { return false }
            released = true
            return true
        }
        if shouldRelease { registry.release(token: token) }
    }
}

private extension NSLock {
    func withCriticalSection<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
