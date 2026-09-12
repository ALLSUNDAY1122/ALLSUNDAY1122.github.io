import XCTest

final class ScanTrashLifecycleTests: XCTestCase {
    func testPermanentDeleteRemovesTrashProjectAndReleasesTrackedStorage() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Delete me")
        try Data(repeating: 0xAB, count: 2 * 1_024 * 1_024)
            .write(to: projectURL.appendingPathComponent("raw.bin"))

        let beforeDelete = store.storageBytes(includeTrash: true)
        XCTAssertGreaterThan(beforeDelete, 2 * 1_024 * 1_024)

        try store.moveToTrash(projectURL: projectURL)
        XCTAssertTrue(store.listProjects().isEmpty)
        XCTAssertEqual(store.listTrash().map(\.id), [manifest.id])
        XCTAssertGreaterThanOrEqual(store.storageBytes(includeTrash: true), beforeDelete)

        try store.permanentlyDeleteFromTrash(id: manifest.id)
        XCTAssertTrue(store.listTrash().isEmpty)
        XCTAssertLessThan(store.storageBytes(includeTrash: true), beforeDelete)
    }

    func testRestoreReturnsProjectBeforePermanentDelete() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Restore me")
        try Data("keep".utf8).write(to: projectURL.appendingPathComponent("marker.txt"))

        try store.moveToTrash(projectURL: projectURL)
        try store.restoreFromTrash(id: manifest.id)

        let restored = try store.loadProject(id: manifest.id)
        XCTAssertEqual(restored.manifest.title, "Restore me")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: restored.projectURL.appendingPathComponent("marker.txt").path
        ))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-trash-lifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
