import Foundation
import XCTest

final class ScanProjectTrashCollisionTests: XCTestCase {
    func testOccupiedTrashDestinationLeavesLiveAndTrashBytesUntouched() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectTrashCollisionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let created = try store.createProject(title: "live")
        let liveSentinel = created.0.appendingPathComponent("live-sentinel")
        try Data([0x53]).write(to: liveSentinel)

        let occupiedTrash = store.trashURL.appendingPathComponent(created.0.lastPathComponent)
        try FileManager.default.createDirectory(at: occupiedTrash, withIntermediateDirectories: true)
        let trashSentinel = occupiedTrash.appendingPathComponent("trash-sentinel")
        try Data([0xAC]).write(to: trashSentinel)

        XCTAssertThrowsError(try store.moveToTrash(projectURL: created.0))
        XCTAssertEqual(try Data(contentsOf: liveSentinel), Data([0x53]))
        XCTAssertEqual(try Data(contentsOf: trashSentinel), Data([0xAC]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.0.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: occupiedTrash.path))
    }
}
