import Foundation

enum BoundedFileReaderError: Error, Equatable {
    case invalidLimit
    case unsafeFile
    case fileTooLarge
    case fileChangedDuringRead
}

enum BoundedFileReader {
    static func read(_ url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0, maximumBytes < Int.max else {
            throw BoundedFileReaderError.invalidLimit
        }
        guard url.isFileURL else { throw BoundedFileReaderError.unsafeFile }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let before = try url.resourceValues(forKeys: keys)
        guard before.isRegularFile == true, before.isSymbolicLink != true else {
            throw BoundedFileReaderError.unsafeFile
        }
        if let size = before.fileSize, size > maximumBytes {
            throw BoundedFileReaderError.fileTooLarge
        }
        let beforeIdentity = fileIdentity(at: url)

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw BoundedFileReaderError.fileTooLarge }

        let after = try url.resourceValues(forKeys: keys)
        guard after.isRegularFile == true, after.isSymbolicLink != true else {
            throw BoundedFileReaderError.unsafeFile
        }
        guard let beforeIdentity,
              let afterIdentity = fileIdentity(at: url),
              beforeIdentity == afterIdentity,
              before.fileSize == after.fileSize,
              after.fileSize == data.count else {
            throw BoundedFileReaderError.fileChangedDuringRead
        }
        return data
    }

    private static func fileIdentity(at url: URL) -> FileIdentity? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let systemNumber = attributes[.systemNumber] as? NSNumber,
              let fileNumber = attributes[.systemFileNumber] as? NSNumber else { return nil }
        return FileIdentity(systemNumber: systemNumber.uint64Value, fileNumber: fileNumber.uint64Value)
    }

    private struct FileIdentity: Equatable {
        let systemNumber: UInt64
        let fileNumber: UInt64
    }
}