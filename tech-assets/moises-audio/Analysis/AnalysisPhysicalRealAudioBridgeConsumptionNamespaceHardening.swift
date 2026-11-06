import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity: Equatable, Sendable {
    public let device: UInt64
    public let inode: UInt64
    public let mode: UInt32
    public let size: Int64
    public let linkCount: UInt64

    public init(device: UInt64, inode: UInt64, mode: UInt32, size: Int64, linkCount: UInt64) {
        self.device = device
        self.inode = inode
        self.mode = mode
        self.size = size
        self.linkCount = linkCount
    }

    public var isRegularFile: Bool {
        (mode & UInt32(S_IFMT)) == UInt32(S_IFREG)
    }

    public var isSymbolicLink: Bool {
        (mode & UInt32(S_IFMT)) == UInt32(S_IFLNK)
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionInterruptedTempGCReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let removedLedgerTemporaryCount: Int
    public let removedRecordTemporaryCount: Int
    public let synchronizedDirectories: [String]

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        removedLedgerTemporaryCount: Int,
        removedRecordTemporaryCount: Int,
        synchronizedDirectories: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.removedLedgerTemporaryCount = removedLedgerTemporaryCount
        self.removedRecordTemporaryCount = removedRecordTemporaryCount
        self.synchronizedDirectories = synchronizedDirectories.sorted()
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError: Error, Equatable, Sendable {
    case pathOutsideRoot
    case unsafeDirectory
    case directoryOpenFailed(Int32)
    case directoryIdentityChanged
    case unsafeEntryName
    case symbolicLinkRejected
    case nonRegularFileRejected
    case oversizedTemporary
    case excessiveInterruptedTemporaries
    case entryIdentityChanged
    case entryInspectionFailed(Int32)
    case entryOpenFailed(Int32)
    case entryRemovalFailed(Int32)
    case entryRenameFailed(Int32)
    case entryLinkFailed(Int32)
    case directoryEnumerationFailed
    case directorySyncFailed(Int32)
}

struct AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory {
    let fileDescriptor: Int32
    let url: URL
    let device: UInt64
    let inode: UInt64
}

enum AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening {
    private static let maximumEntryNameBytes = 255

    static func withPinnedDirectory<T>(
        _ directoryURL: URL,
        within rootURL: URL,
        body: (AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory) throws -> T
    ) throws -> T {
        let handle = try openPinnedDirectory(directoryURL, within: rootURL)
        defer { _ = close(handle.fileDescriptor) }
        let result = try body(handle)
        try validateDirectoryPathStillMatches(handle, within: rootURL)
        return result
    }

    static func openPinnedDirectory(
        _ directoryURL: URL,
        within rootURL: URL
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory {
        let root = rootURL.standardizedFileURL
        let directory = directoryURL.standardizedFileURL
        guard lexicallyContained(directory, within: root) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.pathOutsideRoot
        }

        let rootFD = open(root.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard rootFD >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directoryOpenFailed(errno)
        }
        var currentFD = rootFD
        var ownsCurrent = true
        defer {
            if ownsCurrent { _ = close(currentFD) }
        }

        var rootStat = stat()
        guard fstat(rootFD, &rootStat) == 0,
              isDirectoryMode(UInt32(rootStat.st_mode)) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeDirectory
        }

        let relative = relativeComponents(of: directory, within: root)
        for component in relative {
            guard safeEntryName(component) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
            }
            let nextFD = openat(currentFD, component, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            guard nextFD >= 0 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directoryOpenFailed(errno)
            }
            if currentFD != rootFD { _ = close(currentFD) }
            currentFD = nextFD
        }
        if currentFD != rootFD { _ = close(rootFD) }

        var directoryStat = stat()
        guard fstat(currentFD, &directoryStat) == 0,
              isDirectoryMode(UInt32(directoryStat.st_mode)) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeDirectory
        }
        ownsCurrent = false
        let handle = AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory(
            fileDescriptor: currentFD,
            url: directory,
            device: UInt64(directoryStat.st_dev),
            inode: UInt64(directoryStat.st_ino)
        )
        try validateDirectoryPathStillMatches(handle, within: root)
        return handle
    }

    static func validateDirectoryPathStillMatches(
        _ handle: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory,
        within rootURL: URL
    ) throws {
        let reopened = try openPinnedDirectoryWithoutRecursiveValidation(handle.url, within: rootURL)
        defer { _ = close(reopened.fileDescriptor) }
        guard reopened.device == handle.device, reopened.inode == handle.inode else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directoryIdentityChanged
        }
    }

    static func entryIdentity(
        name: String,
        in directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity? {
        guard safeEntryName(name) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
        }
        var item = stat()
        if fstatat(directory.fileDescriptor, name, &item, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { return nil }
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryInspectionFailed(errno)
        }
        return identity(item)
    }

    static func validateRegularEntry(
        _ identity: AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity,
        maximumBytes: Int? = nil
    ) throws {
        if identity.isSymbolicLink {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.symbolicLinkRejected
        }
        guard identity.isRegularFile else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.nonRegularFileRejected
        }
        if let maximumBytes, identity.size < 0 || identity.size > Int64(maximumBytes) {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.oversizedTemporary
        }
    }

    static func openExclusiveRegularFile(
        name: String,
        in directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory,
        mode: mode_t = mode_t(S_IRUSR | S_IWUSR)
    ) throws -> Int32 {
        guard safeEntryName(name) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
        }
        let fd = openat(
            directory.fileDescriptor,
            name,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode
        )
        guard fd >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryOpenFailed(errno)
        }
        return fd
    }

    static func openRegularFileForRead(
        name: String,
        in directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory
    ) throws -> Int32 {
        guard safeEntryName(name) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
        }
        let fd = openat(directory.fileDescriptor, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryOpenFailed(errno)
        }
        var item = stat()
        guard fstat(fd, &item) == 0 else {
            let saved = errno
            _ = close(fd)
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryInspectionFailed(saved)
        }
        let observed = identity(item)
        do {
            try validateRegularEntry(observed)
            return fd
        } catch {
            _ = close(fd)
            throw error
        }
    }

    static func renameEntry(
        sourceName: String,
        destinationName: String,
        expectedDestinationIdentity: AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity?,
        in directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory
    ) throws {
        guard safeEntryName(sourceName), safeEntryName(destinationName) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
        }
        let currentDestination = try entryIdentity(name: destinationName, in: directory)
        guard currentDestination == expectedDestinationIdentity else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryIdentityChanged
        }
        if let currentDestination {
            try validateRegularEntry(currentDestination)
        }
        guard renameat(
            directory.fileDescriptor, sourceName,
            directory.fileDescriptor, destinationName
        ) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryRenameFailed(errno)
        }
    }

    static func linkEntryExclusive(
        sourceName: String,
        destinationName: String,
        in directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory
    ) throws {
        guard safeEntryName(sourceName), safeEntryName(destinationName) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
        }
        guard try entryIdentity(name: destinationName, in: directory) == nil else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryIdentityChanged
        }
        guard linkat(
            directory.fileDescriptor, sourceName,
            directory.fileDescriptor, destinationName,
            0
        ) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryLinkFailed(errno)
        }
    }

    static func unlinkExpectedEntry(
        name: String,
        expectedIdentity: AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity,
        in directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory,
        requireRegular: Bool = true
    ) throws {
        if expectedIdentity.isSymbolicLink {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.symbolicLinkRejected
        }
        if requireRegular && !expectedIdentity.isRegularFile {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.nonRegularFileRejected
        }
        guard let current = try entryIdentity(name: name, in: directory),
              current == expectedIdentity else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryIdentityChanged
        }
        guard unlinkat(directory.fileDescriptor, name, 0) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryRemovalFailed(errno)
        }
    }

    static func synchronizeDirectory(
        _ directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory
    ) throws {
        guard fsync(directory.fileDescriptor) == 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directorySyncFailed(errno)
        }
    }

    static func directoryEntryNames(
        _ directory: AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory
    ) throws -> [String] {
        let duplicateFD = dup(directory.fileDescriptor)
        guard duplicateFD >= 0, let stream = fdopendir(duplicateFD) else {
            if duplicateFD >= 0 { _ = close(duplicateFD) }
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directoryEnumerationFailed
        }
        defer { _ = closedir(stream) }
        var result: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer -> String in
                pointer.withMemoryRebound(to: CChar.self, capacity: maximumEntryNameBytes + 1) { chars in
                    String(cString: chars)
                }
            }
            if name != "." && name != ".." { result.append(name) }
        }
        return result.sorted()
    }

    static func garbageCollectInterruptedPublicationTemps(
        ledgerID: String,
        rootURL: URL,
        lease: AnalysisPhysicalRealAudioBridgeConsumptionWriterLease,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionInterruptedTempGCReceipt {
        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
        let ledgerURL = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: ledgerID,
            rootURL: rootURL
        )
        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)

        var synchronized: [String] = []
        let ledgerRemoved = try collectInterruptedTemps(
            directoryURL: ledgerURL,
            rootURL: rootURL,
            maximumBytes: max(
                AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.maxHeadBytes,
                AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.maxPendingBytes
            )
        )
        if ledgerRemoved > 0 { synchronized.append("ledger") }

        let recordRemoved = try collectInterruptedTemps(
            directoryURL: recordsURL,
            rootURL: rootURL,
            maximumBytes: AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.maxRecordBytes
        )
        if recordRemoved > 0 { synchronized.append("records") }

        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateLedgerTopology(
            ledgerURL: ledgerURL,
            rootURL: rootURL,
            fileManager: fileManager
        )
        return .init(
            ledgerID: ledgerID,
            removedLedgerTemporaryCount: ledgerRemoved,
            removedRecordTemporaryCount: recordRemoved,
            synchronizedDirectories: synchronized
        )
    }

    private static func collectInterruptedTemps(
        directoryURL: URL,
        rootURL: URL,
        maximumBytes: Int
    ) throws -> Int {
        try withPinnedDirectory(directoryURL, within: rootURL) { directory in
            let names = try directoryEntryNames(directory).filter {
                AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.isInterruptedTemporaryFileName($0)
            }
            guard names.count <= AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.excessiveInterruptedTemporaries
            }
            var identities: [(String, AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity)] = []
            identities.reserveCapacity(names.count)
            for name in names {
                guard let observed = try entryIdentity(name: name, in: directory) else {
                    throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryIdentityChanged
                }
                try validateRegularEntry(observed, maximumBytes: maximumBytes)
                identities.append((name, observed))
            }
            for (name, observed) in identities {
                try unlinkExpectedEntry(name: name, expectedIdentity: observed, in: directory)
            }
            if !identities.isEmpty { try synchronizeDirectory(directory) }
            return identities.count
        }
    }

    private static func openPinnedDirectoryWithoutRecursiveValidation(
        _ directoryURL: URL,
        within rootURL: URL
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionPinnedDirectory {
        let root = rootURL.standardizedFileURL
        let directory = directoryURL.standardizedFileURL
        guard lexicallyContained(directory, within: root) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.pathOutsideRoot
        }
        let rootFD = open(root.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard rootFD >= 0 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directoryOpenFailed(errno)
        }
        var currentFD = rootFD
        var finalFD = rootFD
        let relative = relativeComponents(of: directory, within: root)
        for component in relative {
            guard safeEntryName(component) else {
                if currentFD != rootFD { _ = close(currentFD) }
                _ = close(rootFD)
                throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeEntryName
            }
            let nextFD = openat(currentFD, component, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            guard nextFD >= 0 else {
                if currentFD != rootFD { _ = close(currentFD) }
                _ = close(rootFD)
                throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.directoryOpenFailed(errno)
            }
            if currentFD != rootFD { _ = close(currentFD) }
            currentFD = nextFD
            finalFD = nextFD
        }
        if finalFD != rootFD { _ = close(rootFD) }
        var item = stat()
        guard fstat(finalFD, &item) == 0, isDirectoryMode(UInt32(item.st_mode)) else {
            _ = close(finalFD)
            throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.unsafeDirectory
        }
        return .init(
            fileDescriptor: finalFD,
            url: directory,
            device: UInt64(item.st_dev),
            inode: UInt64(item.st_ino)
        )
    }

    private static func identity(_ item: stat) -> AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity {
        .init(
            device: UInt64(item.st_dev),
            inode: UInt64(item.st_ino),
            mode: UInt32(item.st_mode),
            size: Int64(item.st_size),
            linkCount: UInt64(item.st_nlink)
        )
    }

    private static func isDirectoryMode(_ mode: UInt32) -> Bool {
        (mode & UInt32(S_IFMT)) == UInt32(S_IFDIR)
    }

    private static func safeEntryName(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= maximumEntryNameBytes,
              value != ".", value != "..",
              !value.contains("/"), !value.contains("\\"),
              !value.contains("\0") else { return false }
        return true
    }

    private static func relativeComponents(of url: URL, within root: URL) -> [String] {
        let rootPath = root.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        guard targetPath != rootPath else { return [] }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let suffix = String(targetPath.dropFirst(prefix.count))
        return suffix.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private static func lexicallyContained(_ url: URL, within root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        if targetPath == rootPath { return true }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return targetPath.hasPrefix(prefix)
    }
}
