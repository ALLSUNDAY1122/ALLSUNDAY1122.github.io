import Foundation
import Darwin

enum BoundedFileReaderError: Error, Equatable {
    case invalidLimit
    case unsafeFile
    case fileTooLarge
    case fileChangedDuringRead
}

enum BoundedFileReader {
    private static let readChunkBytes = 64 * 1024
    private static let reserveCapacityCeilingBytes = 1024 * 1024
    private static let absoluteMaximumBytes = 256 * 1024 * 1024

    static func read(_ url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0,
              maximumBytes <= absoluteMaximumBytes else { throw BoundedFileReaderError.invalidLimit }
        guard url.isFileURL else { throw BoundedFileReaderError.unsafeFile }
        try Task.checkCancellation()

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let before = try url.resourceValues(forKeys: keys)
        guard before.isRegularFile == true, before.isSymbolicLink != true else { throw BoundedFileReaderError.unsafeFile }
        if let size = before.fileSize {
            guard size >= 0 else { throw BoundedFileReaderError.unsafeFile }
            if size > maximumBytes { throw BoundedFileReaderError.fileTooLarge }
        }
        guard let beforeIdentity = pathIdentity(at: url) else { throw BoundedFileReaderError.fileChangedDuringRead }
        guard beforeIdentity.byteCount >= 0, beforeIdentity.linkCount == 1 else { throw BoundedFileReaderError.unsafeFile }
        if beforeIdentity.byteCount > Int64(maximumBytes) { throw BoundedFileReaderError.fileTooLarge }
        if let size = before.fileSize, Int64(size) != beforeIdentity.byteCount {
            throw BoundedFileReaderError.fileChangedDuringRead
        }

        // O_NOFOLLOW closes the lstat->open symlink race. O_NONBLOCK also prevents a malicious
        // regular-file -> FIFO/device swap from hanging the reader before fstat can reject it;
        // regular-file reads ignore O_NONBLOCK on Darwin.
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw BoundedFileReaderError.unsafeFile }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        try Task.checkCancellation()
        guard let openedIdentity = handleIdentity(handle), openedIdentity == beforeIdentity else { throw BoundedFileReaderError.fileChangedDuringRead }
        guard openedIdentity.linkCount == 1 else { throw BoundedFileReaderError.unsafeFile }
        if openedIdentity.byteCount > Int64(maximumBytes) { throw BoundedFileReaderError.fileTooLarge }

        var data = Data()
        if let size = before.fileSize {
            data.reserveCapacity(min(size, maximumBytes, Self.reserveCapacityCeilingBytes))
        }
        while data.count <= maximumBytes {
            try Task.checkCancellation()
            let remainingProbe = maximumBytes - data.count + 1
            let requestBytes = min(Self.readChunkBytes, remainingProbe)
            guard requestBytes > 0 else { break }
            let chunk = try handle.read(upToCount: requestBytes) ?? Data()
            try Task.checkCancellation()
            if chunk.isEmpty { break }
            guard chunk.count <= maximumBytes - data.count else {
                throw BoundedFileReaderError.fileTooLarge
            }
            data.append(chunk)
        }

        try Task.checkCancellation()
        let after = try url.resourceValues(forKeys: keys)
        guard after.isRegularFile == true, after.isSymbolicLink != true else { throw BoundedFileReaderError.unsafeFile }
        guard let afterIdentity = pathIdentity(at: url),
              let finalOpenedIdentity = handleIdentity(handle),
              beforeIdentity == afterIdentity,
              openedIdentity == finalOpenedIdentity,
              afterIdentity.linkCount == 1,
              finalOpenedIdentity.linkCount == 1,
              before.fileSize == after.fileSize,
              after.fileSize == data.count,
              finalOpenedIdentity.byteCount == Int64(data.count) else { throw BoundedFileReaderError.fileChangedDuringRead }
        return data
    }

    private static func pathIdentity(at url: URL) -> FileIdentity? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return nil }
        guard (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return identity(from: info)
    }

    private static func handleIdentity(_ handle: FileHandle) -> FileIdentity? {
        var info = stat()
        guard fstat(handle.fileDescriptor, &info) == 0 else { return nil }
        guard (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return identity(from: info)
    }

    private static func identity(from info: stat) -> FileIdentity {
        FileIdentity(
            systemNumber: UInt64(info.st_dev),
            fileNumber: UInt64(info.st_ino),
            linkCount: UInt64(info.st_nlink),
            byteCount: Int64(info.st_size),
            modificationSeconds: Int64(info.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(info.st_mtimespec.tv_nsec),
            changeSeconds: Int64(info.st_ctimespec.tv_sec),
            changeNanoseconds: Int64(info.st_ctimespec.tv_nsec)
        )
    }

    private struct FileIdentity: Equatable {
        let systemNumber: UInt64
        let fileNumber: UInt64
        let linkCount: UInt64
        let byteCount: Int64
        let modificationSeconds: Int64
        let modificationNanoseconds: Int64
        let changeSeconds: Int64
        let changeNanoseconds: Int64
    }
}