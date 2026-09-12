import Foundation
import XCTest

final class ScanProjectTrashLifecycleContainmentTests: XCTestCase {
    func testMoveRejectsProjectOutsideLibraryRoot() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectTrashLifecycleContainmentTests-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("library", isDirectory: true)
        let outside = parent.appendingPathComponent("outside.splatproject", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("sentinel")
        try Data([0x41]).write(to: sentinel)
        defer { try? FileManager.default.removeItem(at: parent) }

        let store = ScanProjectStore(rootURL: root)
        XCTAssertThrowsError(try store.moveToTrash(projectURL: outside))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([0x41]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testTrashSymlinkProjectCannotBeRestoredOrPermanentlyDeleted() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectTrashLifecycleContainmentTests-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("library", isDirectory: true)
        let outside = parent.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let sentinel = outside.appendingPathComponent("sentinel")
        try Data([0x42]).write(to: sentinel)
        let store = ScanProjectStore(rootURL: root)
        let trashLink = store.trashURL.appendingPathComponent("evil").appendingPathExtension(ScanProjectStore.projectExtension)
        try FileManager.default.createSymbolicLink(at: trashLink, withDestinationURL: outside)

        XCTAssertThrowsError(try store.restoreFromTrash(id: "evil"))
        XCTAssertThrowsError(try store.permanentlyDeleteFromTrash(id: "evil"))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([0x42]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashLink.path))
    }
}
