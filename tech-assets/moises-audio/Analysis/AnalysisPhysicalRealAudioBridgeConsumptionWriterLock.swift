import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError: Error, Equatable, Sendable {
    case unsafeLedgerID
    case unsafeLockDirectory
    case lockOpenFailed(Int32)
    case lockAcquireFailed(Int32)
    case lockTokenWriteFailed(Int32)
    case lockTokenMismatch
}

struct AnalysisPhysicalRealAudioBridgeConsumptionWriterLease: Sendable {
    let fileDescriptor: Int32
    let lockURL: URL
    let token: String
    let device: UInt64
    let inode: UInt64
}

private final class AnalysisPhysicalRealAudioBridgeConsumptionInProcessWriterRegistry: @unchecked Sendable {
    static let shared = AnalysisPhysicalRealAudioBridgeConsumptionInProcessWriterRegistry()
    private let registryLock = NSLock()
    private var locks: [String: NSLock] = [:]

    func withLock<T>(key: String, body: () throws -> T) rethrows -> T {
        registryLock.lock()
        let writerLock: NSLock
        if let existing = locks[key] {
            writerLock = existing
        } else {
            let created = NSLock()
            locks[key] = created
            writerLock = created
        }
        registryLock.unlock()
        writerLock.lock()
        defer { writerLock.unlock() }
        return try body()
    }
}

enum AnalysisPhysicalRealAudioBridgeConsumptionWriterLock {
    static let lockDirectoryName = ".writer-locks"

    static func withExclusiveLock<T>(
        ledgerID: String,
        rootURL: URL,
        body: (AnalysisPhysicalRealAudioBridgeConsumptionWriterLease) throws -> T
    ) throws -> T {
        guard safeComponent(ledgerID) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.unsafeLedgerID
        }
        let normalizedRoot = rootURL.standardizedFileURL
        let registryKey = normalizedRoot.path + "\n" + ledgerID
        return try AnalysisPhysicalRealAudioBridgeConsumptionInProcessWriterRegistry.shared.withLock(key: registryKey) {
            let lockURL = try prepareLockURL(ledgerID: ledgerID, rootURL: normalizedRoot)
            let flags = O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW
            let fd = open(lockURL.path, flags, mode_t(S_IRUSR | S_IWUSR))
            guard fd >= 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockOpenFailed(errno)
            }
            defer { _ = close(fd) }

            while flock(fd, LOCK_EX) != 0 {
                if errno == EINTR { continue }
                throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockAcquireFailed(errno)
            }
            defer { _ = flock(fd, LOCK_UN) }

            var descriptorStat = stat()
            guard fstat(fd, &descriptorStat) == 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockAcquireFailed(errno)
            }
            let token = UUID().uuidString.lowercased()
            let bytes = Array((token + "\n").utf8)
            guard ftruncate(fd, 0) == 0, lseek(fd, 0, SEEK_SET) >= 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenWriteFailed(errno)
            }
            var written = 0
            while written < bytes.count {
                let result = bytes.withUnsafeBytes { raw -> Int in
                    let base = raw.baseAddress!.advanced(by: written)
                    return write(fd, base, bytes.count - written)
                }
                if result < 0 {
                    if errno == EINTR { continue }
                    throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenWriteFailed(errno)
                }
                if result == 0 {
                    throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenWriteFailed(EIO)
                }
                written += result
            }
            guard fsync(fd) == 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenWriteFailed(errno)
            }
            let lease = AnalysisPhysicalRealAudioBridgeConsumptionWriterLease(
                fileDescriptor: fd,
                lockURL: lockURL,
                token: token,
                device: UInt64(descriptorStat.st_dev),
                inode: UInt64(descriptorStat.st_ino)
            )
            try validateLease(lease)
            do {
                let result = try body(lease)
                try validateLease(lease)
                return result
            } catch {
                try validateLease(lease)
                throw error
            }
        }
    }

    static func validateLease(_ lease: AnalysisPhysicalRealAudioBridgeConsumptionWriterLease) throws {
        var descriptorStat = stat()
        guard fstat(lease.fileDescriptor, &descriptorStat) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenMismatch
        }
        var pathStat = stat()
        guard lstat(lease.lockURL.path, &pathStat) == 0,
              UInt64(descriptorStat.st_dev) == lease.device,
              UInt64(descriptorStat.st_ino) == lease.inode,
              UInt64(pathStat.st_dev) == lease.device,
              UInt64(pathStat.st_ino) == lease.inode else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenMismatch
        }
        var buffer = [UInt8](repeating: 0, count: 128)
        let readCount: Int = buffer.withUnsafeMutableBytes { rawBuffer in
            pread(lease.fileDescriptor, rawBuffer.baseAddress, rawBuffer.count, 0)
        }
        guard readCount > 0,
              let text = String(bytes: buffer.prefix(readCount), encoding: .utf8),
              text.trimmingCharacters(in: .whitespacesAndNewlines) == lease.token else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.lockTokenMismatch
        }
    }

    static func lockURL(ledgerID: String, rootURL: URL) -> URL {
        rootURL.standardizedFileURL
            .appendingPathComponent("w49-bridge-consumption", isDirectory: true)
            .appendingPathComponent(lockDirectoryName, isDirectory: true)
            .appendingPathComponent("\(ledgerID).lock", isDirectory: false)
    }

    private static func prepareLockURL(ledgerID: String, rootURL: URL) throws -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: rootURL.path) {
            try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
        try validateDirectory(rootURL, within: rootURL)

        let bridgeRoot = rootURL.appendingPathComponent("w49-bridge-consumption", isDirectory: true)
        if !fm.fileExists(atPath: bridgeRoot.path) {
            try fm.createDirectory(at: bridgeRoot, withIntermediateDirectories: false)
        }
        try validateDirectory(bridgeRoot, within: rootURL)

        let lockDirectory = bridgeRoot.appendingPathComponent(lockDirectoryName, isDirectory: true)
        if !fm.fileExists(atPath: lockDirectory.path) {
            try fm.createDirectory(at: lockDirectory, withIntermediateDirectories: false)
        }
        try validateDirectory(lockDirectory, within: bridgeRoot)
        return lockDirectory.appendingPathComponent("\(ledgerID).lock", isDirectory: false)
    }

    private static func validateDirectory(_ url: URL, within root: URL) throws {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard path == rootPath || path.hasPrefix(prefix) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.unsafeLockDirectory
        }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.unsafeLockDirectory
        }
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedPrefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : resolvedRoot + "/"
        guard resolvedPath == resolvedRoot || resolvedPath.hasPrefix(resolvedPrefix) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError.unsafeLockDirectory
        }
    }

    private static func safeComponent(_ value: String) -> Bool {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.contains("/"), !value.contains("\\"),
              value != ".", value != ".." else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 95, 97...122: return true
            default: return false
            }
        }
    }
}
