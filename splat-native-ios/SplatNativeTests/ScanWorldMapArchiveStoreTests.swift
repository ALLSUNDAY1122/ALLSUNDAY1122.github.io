import Foundation
import XCTest

final class ScanWorldMapArchiveStoreTests: XCTestCase {
    func testWritePersistsExactArchiveBytes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("worldmap.bin")
        let expected = Data((0..<4096).map { UInt8(truncatingIfNeeded: $0) })

        try ScanWorldMapArchiveStore.write(expected, to: target)

        XCTAssertEqual(try Data(contentsOf: target), expected)
    }

    func testWriteReplacesExistingArchiveOnlyAfterCandidateValidation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("worldmap.bin")
        let previous = Data(repeating: 0x11, count: 2048)
        let replacement = Data((0..<8192).map { UInt8(truncatingIfNeeded: $0 * 31) })
        try previous.write(to: target, options: .atomic)

        try ScanWorldMapArchiveStore.write(replacement, to: target)

        XCTAssertEqual(try Data(contentsOf: target), replacement)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names, ["worldmap.bin"])
    }

    func testWriteRejectsEmptyArchiveWithoutCreatingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("worldmap.bin")

        XCTAssertThrowsError(try ScanWorldMapArchiveStore.write(Data(), to: target)) { error in
            guard case ScanWorldMapArchiveStoreError.emptyArchive = error else {
                return XCTFail("Expected emptyArchive, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testWriteRejectsMissingParentDirectory() {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = parent.appendingPathComponent("worldmap.bin")

        XCTAssertThrowsError(try ScanWorldMapArchiveStore.write(Data([1, 2, 3]), to: target)) { error in
            guard case ScanWorldMapArchiveStoreError.missingParentDirectory = error else {
                return XCTFail("Expected missingParentDirectory, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
}
