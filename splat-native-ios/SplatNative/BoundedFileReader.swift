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

    static func read(_ url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0, maximumBytes < Int.max else { throw BoundedFileReaderError.invalidLimit }
        guard url.isFileURL else { throw BoundedFileReaderError.unsafeFile }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let before = try url.resourceValues(forKeys: keys)
        guard before.isRegularFile == true, before.isSymbolicLink != true else { throw BoundedFileReaderError.unsafeFile }
        if let size = before.fileSize, size > maximumBytes { throw BoundedFileReaderError.fileTooLarge }
        guard let beforeIdentity = pathIdentity(at: url) else { throw BoundedFileReaderError.fileChangedDuringRead }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let openedIdentity = handleIdentity(handle), openedIdentity == beforeIdentity else { throw BoundedFileReaderError.fileChangedDuringRead }

        var data = Data()
        if let size = before.fileSize { data.reserveCapacity(min(size, maximumBytes)) }
        while data.count <= maximumBytes {
            try Task.checkCancellation()
            let remainingProbe = maximumBytes - data.count + 1
            let requestBytes = min(Self.readChunkBytes, remainingProbe)
            guard requestBytes > 0 else { break }
            let chunk = try handle.read(upToCount: requestBytes) ?? Data()
            try Task.checkCancellation()
            if chunk.isEmpty { break }
            data.append(chunk)
            if data.count > maximumBytes { throw BoundedFileReaderError.fileTooLarge }
        }

        try Task.checkCancellation()
        let after = try url.resourceValues(forKeys: keys)
        guard after.isRegularFile == true, after.isSymbolicLink != true else { throw BoundedFileReaderError.unsafeFile }
        guard let afterIdentity = pathIdentity(at: url),
              let finalOpenedIdentity = handleIdentity(handle),
              beforeIdentity == afterIdentity,
              openedIdentity == finalOpenedIdentity,
              before.fileSize == after.fileSize,
              after.fileSize == data.count,
              finalOpenedIdentity.byteCount == Int64(data.count) else { throw BoundedFileReaderError.fileChangedDuringRead }
        return data
    }

    private static func pathIdentity(at url: URL) -> FileIdentity? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let systemNumber = attributes[.systemNumber] as? NSNumber,
              let fileNumber = attributes[.systemFileNumber] as? NSNumber,
              let size = attributes[.size] as? NSNumber else { return nil }
        return FileIdentity(systemNumber: systemNumber.uint64Value, fileNumber: fileNumber.uint64Value, byteCount: size.int64Value)
    }

    private static func handleIdentity(_ handle: FileHandle) -> FileIdentity? {
        var info = stat()
        guard fstat(handle.fileDescriptor, &info) == 0 else { return nil }
        guard (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return FileIdentity(systemNumber: UInt64(info.st_dev), fileNumber: UInt64(info.st_ino), byteCount: Int64(info.st_size))
    }

    private struct FileIdentity: Equatable {
        let systemNumber: UInt64
        let fileNumber: UInt64
        let byteCount: Int64
    }
}
