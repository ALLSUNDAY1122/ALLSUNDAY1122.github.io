import Foundation
import XCTest

final class ScanProjectIDContainmentTests: XCTestCase {
    func testTraversalIDCannotLoadRestoreOrDeleteOutsideStorageRoots() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectIDContainmentTests-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let victim = parent.appendingPathComponent("victim").appendingPathExtension(ScanProjectStore.projectExtension)
        try FileManager.default.createDirectory(at: victim, withIntermediateDirectories: true)
        let sentinel = victim.appendingPathComponent("sentinel")
        try Data([0xA5]).write(to: sentinel)

        let store = ScanProjectStore(rootURL: root)
        for id in ["../victim", "..\\victim", "", ".", ".."] {
            XCTAssertThrowsError(try store.loadProject(id: id))
            XCTAssertThrowsError(try store.restoreFromTrash(id: id))
            XCTAssertThrowsError(try store.permanentlyDeleteFromTrash(id: id))
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: victim.path))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([0xA5]))
    }
}
