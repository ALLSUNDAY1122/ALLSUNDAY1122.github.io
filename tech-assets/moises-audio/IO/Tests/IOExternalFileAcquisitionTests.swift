import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOExternalFileAcquisitionTests: XCTestCase {
    private func makeFixture() throws -> (base: URL, root: URL, external: URL, acquirer: IOExternalFileAcquirer) {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("io-external-acquisition-\(UUID().uuidString)", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        let store = IOFileStore(rootURL: root)
        let acquirer = IOExternalFileAcquirer(
            fileStore: store,
            maximumFileBytes: 16,
            storageReserveBytes: 0
        )
        return (base, root, external, acquirer)
    }

    func testRejectsRemoteURLAtExternalFileBoundary() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.base) }

        XCTAssertThrowsError(
            try fixture.acquirer.stageExternalFile(
                at: URL(string: "https://example.com/song.mp3")!,
                accessMode: .direct
            )
        ) { error in
            XCTAssertEqual(error as? IOExternalFileAcquisitionError, .invalidSourceURL)
        }
    }

    func testRejectsMissingDirectoryEmptyAndOversizedSources() throws {
        let fm = FileManager.default
        let fixture = try makeFixture()
        defer { try? fm.removeItem(at: fixture.base) }

        let missing = fixture.external.appendingPathComponent("missing.mp3")
        XCTAssertThrowsError(try fixture.acquirer.stageExternalFile(at: missing, accessMode: .direct)) { error in
            XCTAssertEqual(error as? IOExternalFileAcquisitionError, .sourceMissing)
        }

        let directory = fixture.external.appendingPathComponent("directory", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertThrowsError(try fixture.acquirer.stageExternalFile(at: directory, accessMode: .direct)) { error in
            XCTAssertEqual(error as? IOExternalFileAcquisitionError, .sourceNotRegularFile)
        }

        let empty = fixture.external.appendingPathComponent("empty.wav")
        try Data().write(to: empty)
        XCTAssertThrowsError(try fixture.acquirer.stageExternalFile(at: empty, accessMode: .direct)) { error in
            XCTAssertEqual(error as? IOExternalFileAcquisitionError, .sourceEmpty)
        }

        let oversized = fixture.external.appendingPathComponent("large.flac")
        try Data(repeating: 1, count: 17).write(to: oversized)
        XCTAssertThrowsError(try fixture.acquirer.stageExternalFile(at: oversized, accessMode: .direct)) { error in
            XCTAssertEqual(
                error as? IOExternalFileAcquisitionError,
                .sourceTooLarge(limitBytes: 16, actualBytes: 17)
            )
        }
    }

    func testCopiesCompleteFileAndPreservesDescriptorWithoutNameCollision() throws {
        let fm = FileManager.default
        let fixture = try makeFixture()
        defer { try? fm.removeItem(at: fixture.base) }

        let source = fixture.external.appendingPathComponent("song.MP3")
        try Data([1, 2, 3, 4, 5]).write(to: source)

        let first = try fixture.acquirer.stageExternalFile(at: source, accessMode: .direct)
        let second = try fixture.acquirer.stageExternalFile(at: source, accessMode: .direct)

        XCTAssertEqual(first.descriptor.byteCount, 5)
        XCTAssertEqual(first.descriptor.preferredName, "song")
        XCTAssertEqual(first.descriptor.pathExtension, "mp3")
        XCTAssertNotEqual(first.stagingURL, second.stagingURL)
        XCTAssertEqual(try Data(contentsOf: first.stagingURL), Data([1, 2, 3, 4, 5]))
        XCTAssertTrue(first.stagingURL.path.contains("/Staging/"))
    }

    func testRejectsAlreadyAppOwnedSourceToPreventAmbiguousOwnership() throws {
        let fm = FileManager.default
        let fixture = try makeFixture()
        defer { try? fm.removeItem(at: fixture.base) }

        try fm.createDirectory(at: fixture.root, withIntermediateDirectories: true)
        let owned = fixture.root.appendingPathComponent("owned.m4a")
        try Data([9]).write(to: owned)

        XCTAssertThrowsError(try fixture.acquirer.stageExternalFile(at: owned, accessMode: .direct)) { error in
            XCTAssertEqual(error as? IOExternalFileAcquisitionError, .sourceInsideAppRoot)
        }
    }

    #if !(os(iOS) || os(macOS) || os(tvOS) || os(visionOS))
    func testSecurityScopedModeFailsClosedWhereSecurityScopesDoNotExist() throws {
        let fm = FileManager.default
        let fixture = try makeFixture()
        defer { try? fm.removeItem(at: fixture.base) }

        let source = fixture.external.appendingPathComponent("song.wav")
        try Data([1]).write(to: source)

        XCTAssertThrowsError(try fixture.acquirer.stageExternalFile(at: source, accessMode: .securityScoped)) { error in
            XCTAssertEqual(error as? IOExternalFileAcquisitionError, .securityScopeDenied)
        }
    }
    #endif
}
