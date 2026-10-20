import Foundation
import XCTest

final class BoundedFileReaderTests: XCTestCase {
    private func temporaryFile(_ data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("metadata.bin")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return url
    }

    func testReadsEmptyFileWithPositiveLimit() throws {
        let url = try temporaryFile(Data())
        XCTAssertEqual(try BoundedFileReader.read(url, maximumBytes: 1), Data())
    }

    func testReadsFileAtLimit() throws {
        let payload = Data(repeating: 0x41, count: 64)
        let url = try temporaryFile(payload)
        XCTAssertEqual(try BoundedFileReader.read(url, maximumBytes: 64), payload)
    }

    func testReadsAcrossInternalChunkBoundary() throws {
        let payload = Data((0..<(64 * 1024 + 37)).map { UInt8(truncatingIfNeeded: $0) })
        let url = try temporaryFile(payload)
        XCTAssertEqual(try BoundedFileReader.read(url, maximumBytes: payload.count), payload)
    }

    func testRejectsOversizeAcrossInternalChunkBoundary() throws {
        let payload = Data(repeating: 0x7f, count: 64 * 1024 + 1)
        let url = try temporaryFile(payload)
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 64 * 1024)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .fileTooLarge)
        }
    }

    func testRejectsHardLink() throws {
        let payload = Data([1, 2, 3, 4])
        let target = try temporaryFile(payload)
        let link = target.deletingLastPathComponent().appendingPathComponent("hardlink.bin")
        try FileManager.default.linkItem(at: target, to: link)
        XCTAssertThrowsError(try BoundedFileReader.read(link, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }

    func testRejectsFileLargerThanLimit() throws {
        let url = try temporaryFile(Data(repeating: 0x42, count: 65))
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .fileTooLarge)
        }
    }

    func testRejectsNonPositiveLimit() throws {
        let url = try temporaryFile(Data())
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 0)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .invalidLimit)
        }
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: -1)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .invalidLimit)
        }
    }

    func testRejectsUnreasonablyLargeLimit() throws {
        let url = try temporaryFile(Data())
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 256 * 1024 * 1024 + 1)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .invalidLimit)
        }
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: Int.max)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .invalidLimit)
        }
    }

    func testRejectsSymlink() throws {
        let target = try temporaryFile(Data([1, 2, 3]))
        let link = target.deletingLastPathComponent().appendingPathComponent("link.bin")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try BoundedFileReader.read(link, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }

    func testRejectsDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try BoundedFileReader.read(directory, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }

    func testRejectsNonFileURL() {
        let url = URL(string: "https://example.invalid/metadata.bin")!
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }

    func testRejectsFileURLWithQueryOrFragment() throws {
        let target = try temporaryFile(Data([1, 2, 3]))
        var query = URLComponents(url: target, resolvingAgainstBaseURL: false)!
        query.query = "version=1"
        XCTAssertThrowsError(try BoundedFileReader.read(query.url!, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
        var fragment = URLComponents(url: target, resolvingAgainstBaseURL: false)!
        fragment.fragment = "metadata"
        XCTAssertThrowsError(try BoundedFileReader.read(fragment.url!, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }

    func testRejectsFileURLWithAuthorityComponents() {
        for raw in ["file://user@localhost/tmp/metadata.bin", "file://localhost:123/tmp/metadata.bin"] {
            guard let url = URL(string: raw) else { return XCTFail("invalid test URL") }
            XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 64)) { error in
                XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
            }
        }
    }

    func testRejectsRelativeFileURLWithBaseURL() throws {
        let target = try temporaryFile(Data([1, 2, 3]))
        let relative = URL(fileURLWithPath: target.lastPathComponent, relativeTo: target.deletingLastPathComponent())
        XCTAssertNotNil(relative.baseURL)
        XCTAssertThrowsError(try BoundedFileReader.read(relative, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }

    func testRejectsNonCanonicalFilePath() throws {
        let target = try temporaryFile(Data([1, 2, 3]))
        let url = target.deletingLastPathComponent().appendingPathComponent("subdir/../metadata.bin")
        XCTAssertThrowsError(try BoundedFileReader.read(url, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedFileReaderError, .unsafeFile)
        }
    }
}
