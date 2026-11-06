import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOFileStoreTests: XCTestCase {
    func testTraversalIsRejected() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = IOFileStore(rootURL: root)
        XCTAssertThrowsError(try store.resolve(relativePath: "../escape.m4a"))
        XCTAssertThrowsError(try store.resolve(relativePath: "/absolute.m4a"))
    }

    func testStageAndFinalizeImportStayInsideRoot() throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let external = base.appendingPathComponent("external-source.m4a")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try Data([0, 1, 2, 3]).write(to: external)
        defer { try? fm.removeItem(at: base) }

        let root = base.appendingPathComponent("sandbox", isDirectory: true)
        let store = IOFileStore(rootURL: root)
        let staged = try store.stageCopy(from: external)
        XCTAssertTrue(staged.path.contains("/Staging/"))
        let final = try store.finalizeImport(stagingFile: staged, preferredName: "song")
        XCTAssertTrue(final.relativePath.hasPrefix("Imports/"))
        XCTAssertTrue(fm.fileExists(atPath: final.url.path))
        XCTAssertFalse(fm.fileExists(atPath: staged.path))
    }

    func testFilenameSanitizationRemovesPathCharacters() {
        XCTAssertEqual(IOFileStore.sanitizedFilenameStem("a/b:c?.wav"), "a_b_c_.wav")
        XCTAssertEqual(IOFileStore.sanitizedFilenameStem(".."), "audio")
    }
}
