import Foundation

enum BoundedFileReaderError: Error, Equatable {
    case invalidLimit
    case unsafeFile
    case fileTooLarge
    case fileChangedDuringRead
}

enum BoundedFileReader {
    static func read(_ url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0 else { throw BoundedFileReaderError.invalidLimit }
        guard url.isFileURL else { throw BoundedFileReaderError.unsafeFile }

        let before = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard before.isRegularFile == true, before.isSymbolicLink != true else {
            throw BoundedFileReaderError.unsafeFile
        }
        if let size = before.fileSize, size > maximumBytes {
            throw BoundedFileReaderError.fileTooLarge
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw BoundedFileReaderError.fileTooLarge }

        let after = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard after.isRegularFile == true, after.isSymbolicLink != true else {
            throw BoundedFileReaderError.unsafeFile
        }
        guard before.fileSize == after.fileSize, after.fileSize == data.count else {
            throw BoundedFileReaderError.fileChangedDuringRead
        }
        return data
    }
}