import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget: String, Codable, Equatable, Sendable {
    case pendingMarker = "PENDING_MARKER"
    case immutableRecord = "IMMUTABLE_RECORD"
    case ledgerHead = "LEDGER_HEAD"
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint: String, Codable, Equatable, Sendable {
    case beforeDataSync = "BEFORE_DATA_SYNC"
    case afterDataSyncBeforePublish = "AFTER_DATA_SYNC_BEFORE_PUBLISH"
    case afterPublishBeforeDirectorySync = "AFTER_PUBLISH_BEFORE_DIRECTORY_SYNC"
    case afterDirectorySync = "AFTER_DIRECTORY_SYNC"
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault: Equatable, Sendable {
    public let target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget
    public let point: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint

    public init(
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        point: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint
    ) {
        self.target = target
        self.point = point
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode: String, Codable, Equatable, Sendable {
    case darwinFullFSync = "DARWIN_F_FULLFSYNC"
    case darwinFSyncFallback = "DARWIN_FSYNC_FALLBACK"
    case posixFSync = "POSIX_FSYNC"
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget
    public let byteCount: Int
    public let dataSyncMode: AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode
    public let atomicPublish: Bool
    public let parentDirectorySynced: Bool

    public init(
        schemaVersion: Int = 1,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        byteCount: Int,
        dataSyncMode: AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode,
        atomicPublish: Bool,
        parentDirectorySynced: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.target = target
        self.byteCount = byteCount
        self.dataSyncMode = dataSyncMode
        self.atomicPublish = atomicPublish
        self.parentDirectorySynced = parentDirectorySynced
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError: Error, Equatable, Sendable {
    case pathOutsideLedgerRoot
    case symbolicLinkRejected
    case nonRegularTargetRejected
    case oversizedFile
    case targetCollision
    case temporaryOpenFailed(Int32)
    case writeFailed(Int32)
    case dataSyncFailed(Int32)
    case publishFailed(Int32)
    case temporaryCleanupFailed(Int32)
    case directoryOpenFailed(Int32)
    case directorySyncFailed(Int32)
    case postPublishVerificationFailed
    case injectedFault(AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault)
}

enum AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication {
    static let temporaryPrefix = ".w53-pub-"
    static let temporarySuffix = ".tmp"
    static let maximumInterruptedTemporaryFilesPerDirectory = 32

    static func isInterruptedTemporaryFileName(_ name: String) -> Bool {
        name.hasPrefix(temporaryPrefix) && name.hasSuffix(temporarySuffix) && name.count > temporaryPrefix.count + temporarySuffix.count
    }

    @discardableResult
    static func replaceAtomically(
        _ data: Data,
        to destinationURL: URL,
        within rootURL: URL,
        maximumBytes: Int,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault? = nil
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationReceipt {
        try validateRequest(
            data: data,
            destinationURL: destinationURL,
            rootURL: rootURL,
            maximumBytes: maximumBytes
        )
        try validateExistingDestination(destinationURL)

        let parent = destinationURL.deletingLastPathComponent()
        let temporaryURL = parent.appendingPathComponent(
            temporaryPrefix + UUID().uuidString.lowercased() + temporarySuffix,
            isDirectory: false
        )
        let fd = openTemporaryFile(temporaryURL)
        var temporaryPublished = false
        var preserveTemporary = false
        defer {
            if !temporaryPublished && !preserveTemporary {
                _ = unlink(temporaryURL.path)
            }
        }

        do {
            try writeAll(data, to: fd)
            try injectIfRequested(injectedFault, target: target, point: .beforeDataSync, preserveTemporary: &preserveTemporary)
            let syncMode = try syncFileDescriptor(fd)
            try injectIfRequested(injectedFault, target: target, point: .afterDataSyncBeforePublish, preserveTemporary: &preserveTemporary)
            _ = close(fd)

            guard rename(temporaryURL.path, destinationURL.path) == 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.publishFailed(errno)
            }
            temporaryPublished = true
            try injectIfRequested(injectedFault, target: target, point: .afterPublishBeforeDirectorySync, preserveTemporary: &preserveTemporary)
            try syncDirectory(parent)
            try injectIfRequested(injectedFault, target: target, point: .afterDirectorySync, preserveTemporary: &preserveTemporary)

            let reopened = try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.readRegularFile(
                destinationURL,
                within: rootURL,
                maximumBytes: maximumBytes
            )
            guard reopened == data else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.postPublishVerificationFailed
            }
            return .init(
                target: target,
                byteCount: data.count,
                dataSyncMode: syncMode,
                atomicPublish: true,
                parentDirectorySynced: true
            )
        } catch {
            _ = close(fd)
            throw error
        }
    }

    @discardableResult
    static func createExclusive(
        _ data: Data,
        at destinationURL: URL,
        within rootURL: URL,
        maximumBytes: Int,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault? = nil
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationReceipt {
        try validateRequest(
            data: data,
            destinationURL: destinationURL,
            rootURL: rootURL,
            maximumBytes: maximumBytes
        )
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.targetCollision
        }

        let parent = destinationURL.deletingLastPathComponent()
        let temporaryURL = parent.appendingPathComponent(
            temporaryPrefix + UUID().uuidString.lowercased() + temporarySuffix,
            isDirectory: false
        )
        let fd = openTemporaryFile(temporaryURL)
        var targetPublished = false
        var preserveTemporary = false
        defer {
            if !preserveTemporary {
                _ = unlink(temporaryURL.path)
            }
        }

        do {
            try writeAll(data, to: fd)
            try injectIfRequested(injectedFault, target: target, point: .beforeDataSync, preserveTemporary: &preserveTemporary)
            let syncMode = try syncFileDescriptor(fd)
            try injectIfRequested(injectedFault, target: target, point: .afterDataSyncBeforePublish, preserveTemporary: &preserveTemporary)
            _ = close(fd)

            guard link(temporaryURL.path, destinationURL.path) == 0 else {
                if errno == EEXIST {
                    throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.targetCollision
                }
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.publishFailed(errno)
            }
            targetPublished = true
            try injectIfRequested(injectedFault, target: target, point: .afterPublishBeforeDirectorySync, preserveTemporary: &preserveTemporary)
            guard unlink(temporaryURL.path) == 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.temporaryCleanupFailed(errno)
            }
            preserveTemporary = true
            try syncDirectory(parent)
            try injectIfRequested(injectedFault, target: target, point: .afterDirectorySync, preserveTemporary: &preserveTemporary)

            let reopened = try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.readRegularFile(
                destinationURL,
                within: rootURL,
                maximumBytes: maximumBytes
            )
            guard targetPublished, reopened == data else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.postPublishVerificationFailed
            }
            return .init(
                target: target,
                byteCount: data.count,
                dataSyncMode: syncMode,
                atomicPublish: true,
                parentDirectorySynced: true
            )
        } catch {
            _ = close(fd)
            throw error
        }
    }

    static func removeDurably(
        _ url: URL,
        within rootURL: URL
    ) throws {
        guard AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.lexicallyContained(url, within: rootURL) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.pathOutsideLedgerRoot
        }
        let parent = url.deletingLastPathComponent()
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateDirectory(parent, within: rootURL)
        if FileManager.default.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.symbolicLinkRejected
            }
            guard values.isRegularFile == true else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.nonRegularTargetRejected
            }
            guard unlink(url.path) == 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.publishFailed(errno)
            }
            try syncDirectory(parent)
        }
    }

    static func syncDirectoryMetadata(_ directoryURL: URL, within rootURL: URL) throws {
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateDirectory(directoryURL, within: rootURL)
        try syncDirectory(directoryURL)
    }

    static func validateInterruptedTemporaryFile(
        _ url: URL,
        within rootURL: URL,
        maximumBytes: Int
    ) throws {
        guard isInterruptedTemporaryFileName(url.lastPathComponent) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.postPublishVerificationFailed
        }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.readRegularFile(
            url,
            within: rootURL,
            maximumBytes: maximumBytes
        )
    }

    private static func validateRequest(
        data: Data,
        destinationURL: URL,
        rootURL: URL,
        maximumBytes: Int
    ) throws {
        guard data.count <= maximumBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.oversizedFile
        }
        guard AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.lexicallyContained(destinationURL, within: rootURL) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.pathOutsideLedgerRoot
        }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateDirectory(
            destinationURL.deletingLastPathComponent(),
            within: rootURL
        )
    }

    private static func validateExistingDestination(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.symbolicLinkRejected
        }
        guard values.isRegularFile == true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.nonRegularTargetRejected
        }
    }

    private static func openTemporaryFile(_ url: URL) -> Int32 {
        let flags = O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW
        return open(url.path, flags, mode_t(S_IRUSR | S_IWUSR))
    }

    private static func writeAll(_ data: Data, to fd: Int32) throws {
        guard fd >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.temporaryOpenFailed(errno)
        }
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let result = write(fd, base.advanced(by: offset), rawBuffer.count - offset)
                if result < 0 {
                    if errno == EINTR { continue }
                    throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.writeFailed(errno)
                }
                if result == 0 {
                    throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.writeFailed(EIO)
                }
                offset += result
            }
        }
    }

    private static func syncFileDescriptor(_ fd: Int32) throws -> AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode {
        guard fd >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.temporaryOpenFailed(errno)
        }
        #if canImport(Darwin)
        if fcntl(fd, F_FULLFSYNC) == 0 {
            return .darwinFullFSync
        }
        guard fsync(fd) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.dataSyncFailed(errno)
        }
        return .darwinFSyncFallback
        #else
        guard fsync(fd) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.dataSyncFailed(errno)
        }
        return .posixFSync
        #endif
    }

    private static func syncDirectory(_ directoryURL: URL) throws {
        let flags = O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW
        let fd = open(directoryURL.path, flags)
        guard fd >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.directoryOpenFailed(errno)
        }
        defer { _ = close(fd) }
        guard fsync(fd) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.directorySyncFailed(errno)
        }
    }

    private static func injectIfRequested(
        _ injection: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault?,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        point: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint,
        preserveTemporary: inout Bool
    ) throws {
        guard let injection, injection.target == target, injection.point == point else { return }
        if point != .afterDirectorySync {
            preserveTemporary = true
        }
        throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.injectedFault(injection)
    }
}
