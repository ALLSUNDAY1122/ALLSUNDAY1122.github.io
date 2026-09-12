import Foundation
import XCTest

final class ScanProjectRestoreCollisionTests: XCTestCase {
    func testRestoreIntoOccupiedLibraryGeneratesNewIDAndPreservesExistingProject() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectRestoreCollisionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let original = try store.createProject(title: "trashed")
        let originalID = original.1.id
        try store.moveToTrash(projectURL: original.0)

        let occupied = root.appendingPathComponent(originalID).appendingPathExtension(ScanProjectStore.projectExtension)
        try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: true)
        var occupiedManifest = ScanProjectManifest(id: originalID, title: "occupied")
        occupiedManifest.updatedAt = Date()
        try store.writeManifest(occupiedManifest, to: occupied)
        let sentinel = occupied.appendingPathComponent("sentinel")
        try Data([0x7A]).write(to: sentinel)

        try store.restoreFromTrash(id: originalID)

        let projects = ScanProjectStore(rootURL: root).listProjects()
        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([0x7A]))
        XCTAssertTrue(projects.contains { $0.manifest.id == originalID && $0.manifest.title == "occupied" })
        let restored = try XCTUnwrap(projects.first { $0.manifest.id != originalID })
        XCTAssertEqual(restored.manifest.title, "trashed")
        XCTAssertEqual(restored.projectURL.deletingPathExtension().lastPathComponent, restored.manifest.id)
        XCTAssertTrue(ScanProjectStore(rootURL: root).listTrash().isEmpty)
    }
}
