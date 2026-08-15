import XCTest

final class MeshProjectStoreTests: XCTestCase {
    private var rootURL: URL!
    private var store: MeshProjectStore!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshProjectStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        store = MeshProjectStore(appRootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL { try? FileManager.default.removeItem(at: rootURL) }
        store = nil
        rootURL = nil
    }

    func testArchiveSurvivesWorkingProjectDeletionWithRawImages() throws {
        let live = try makeLiveProject(mode: "lidar", resultName: "mesh.obj", marker: 0x11)
        let result = live.appendingPathComponent("mesh.obj")

        let archived = try store.archiveFinishedProject(resultURL: result)
        XCTAssertEqual(archived.captureMode, "lidar")
        XCTAssertTrue(archived.rawDataRetained)
        XCTAssertFalse(archived.reprocessSupported)
        XCTAssertEqual(try Data(contentsOf: archived.resultURL), Data(repeating: 0x11, count: 256))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: archived.projectURL.appendingPathComponent("images/mesh_00000.jpg").path
        ))

        try FileManager.default.removeItem(at: live)

        let relaunched = MeshProjectStore(appRootURL: rootURL)
        let saved = try XCTUnwrap(relaunched.listProjects().first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.resultURL.path))
        XCTAssertEqual(try Data(contentsOf: saved.resultURL), Data(repeating: 0x11, count: 256))
        XCTAssertTrue(saved.rawDataRetained)
    }

    func testPhotogrammetryArchiveMarksRawReprocessSupported() throws {
        let live = try makeLiveProject(
            mode: "photogrammetry",
            resultName: "mesh-textured.usdz",
            marker: 0x22
        )
        let summary = try store.archiveFinishedProject(
            resultURL: live.appendingPathComponent("mesh-textured.usdz")
        )

        XCTAssertEqual(summary.title, "写真からメッシュ")
        XCTAssertTrue(summary.rawDataRetained)
        XCTAssertTrue(summary.reprocessSupported)
    }

    func testArchiveRefreshesWhenFinishedResultChanges() throws {
        let live = try makeLiveProject(mode: "lidar", resultName: "mesh.obj", marker: 0x33)
        _ = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))

        let cropped = live.appendingPathComponent("mesh-cropped.obj")
        try Data(repeating: 0x44, count: 384).write(to: cropped, options: .atomic)
        let refreshed = try store.archiveFinishedProject(resultURL: cropped)

        XCTAssertEqual(refreshed.resultURL.lastPathComponent, "mesh-cropped.obj")
        XCTAssertEqual(try Data(contentsOf: refreshed.resultURL), Data(repeating: 0x44, count: 384))
        XCTAssertEqual(store.listProjects().count, 1)
    }

    func testTrashRestoreAndPermanentDeleteSurviveStoreRecreation() throws {
        let live = try makeLiveProject(mode: "lidar", resultName: "mesh.obj", marker: 0x55)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))
        try store.moveToTrash(projectURL: archived.projectURL)

        var relaunched = MeshProjectStore(appRootURL: rootURL)
        XCTAssertTrue(relaunched.listProjects().isEmpty)
        XCTAssertEqual(relaunched.listTrash().count, 1)

        try relaunched.restoreFromTrash(id: archived.id)
        XCTAssertEqual(relaunched.listProjects().count, 1)
        XCTAssertTrue(relaunched.listTrash().isEmpty)

        let restored = try XCTUnwrap(relaunched.listProjects().first)
        try relaunched.moveToTrash(projectURL: restored.projectURL)
        relaunched = MeshProjectStore(appRootURL: rootURL)
        try relaunched.permanentlyDeleteFromTrash(id: restored.id)
        XCTAssertTrue(relaunched.listTrash().isEmpty)
    }

    func testAdoptsLegacyCompletedWorkingProjectButIgnoresIncompleteOne() throws {
        let completed = try makeLiveProject(mode: "lidar", resultName: "mesh.obj", marker: 0x66)
        let incomplete = rootURL.appendingPathComponent("incomplete.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(
            at: incomplete.appendingPathComponent("images", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: incomplete.appendingPathComponent("images/mesh_00000.jpg"))

        store.adoptLegacyCompletedProjects()
        let projects = store.listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].id, completed.deletingPathExtension().lastPathComponent)
    }

    func testRejectsNonMeshProjectResult() throws {
        let directory = rootURL.appendingPathComponent("wrong", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let result = directory.appendingPathComponent("mesh.obj")
        try Data(repeating: 1, count: 64).write(to: result)

        XCTAssertThrowsError(try store.archiveFinishedProject(resultURL: result)) { error in
            guard case MeshProjectStoreError.invalidProject = error else {
                return XCTFail("Expected invalidProject, got \(error)")
            }
        }
    }

    private func makeLiveProject(
        mode: String,
        resultName: String,
        marker: UInt8
    ) throws -> URL {
        let id = UUID().uuidString
        let project = rootURL.appendingPathComponent(id).appendingPathExtension("meshproject")
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data(repeating: 0xA5, count: 128).write(to: images.appendingPathComponent("mesh_00000.jpg"))

        let manifest: [String: Any] = [
            "schemaVersion": 1,
            "captureMode": mode,
            "scanSize": "medium",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "frames": [],
            "lidarMeshAvailable": mode == "lidar",
            "texturedModelAvailable": mode == "photogrammetry",
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: project.appendingPathComponent("mesh-project.json"), options: .atomic)
        try Data(repeating: marker, count: mode == "photogrammetry" ? 512 : 256)
            .write(to: project.appendingPathComponent(resultName), options: .atomic)
        return project
    }
}
