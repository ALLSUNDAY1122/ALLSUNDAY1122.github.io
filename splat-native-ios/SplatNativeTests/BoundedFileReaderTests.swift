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
    }

    func testRejectsOverflowingLimit() throws {
        let url = try temporaryFile(Data())
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
}