import Foundation
import XCTest

final class ScanRawDataPreservationTests: XCTestCase {
    private var rootURL: URL!
    private var store: ScanProjectStore!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanRawDataPreservationTests-\(UUID().uuidString)", isDirectory: true)
        store = ScanProjectStore(rootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL { try? FileManager.default.removeItem(at: rootURL) }
        store = nil
        rootURL = nil
    }

    func testClearRawDataRemovesInputsButPreservesDerivedResultSidecars() throws {
        let fileManager = FileManager.default
        let created = try store.createProject(title: "keep derived assets")
        let projectURL = created.0

        let depth = projectURL.appendingPathComponent("depth", isDirectory: true)
        try fileManager.createDirectory(at: depth, withIntermediateDirectories: true)
        try Data("depth".utf8).write(to: depth.appendingPathComponent("0001.bin"))
        try Data("transforms".utf8).write(to: projectURL.appendingPathComponent("transforms.json"))
        try Data("ply".utf8).write(to: projectURL.appendingPathComponent("points3D.ply"))
        try Data("checkpoint".utf8).write(to: projectURL.appendingPathComponent("training.msplat-checkpoint"))
        try Data("worldmap".utf8).write(to: projectURL.appendingPathComponent(ScanProjectStore.worldMapFileName))
        try Data("recipe".utf8).write(to: projectURL.appendingPathComponent("s14-seed-recipe.json"))

        let derivedNames = [
            "result.viewer.json",
            "result.viewer.json.bak",
            "result.sh3-deadbeef.ply",
            "mesh-textured.mtl",
            "mesh-texture.jpg",
            "reconstruction-run-07000.json"
        ]
        for name in derivedNames {
            try Data("derived-\(name)".utf8).write(to: projectURL.appendingPathComponent(name))
        }

        try store.clearRawData(projectURL: projectURL)

        XCTAssertFalse(fileManager.fileExists(atPath: projectURL.appendingPathComponent("images").path))
        XCTAssertFalse(fileManager.fileExists(atPath: depth.path))
        XCTAssertFalse(fileManager.fileExists(atPath: projectURL.appendingPathComponent("transforms.json").path))
        XCTAssertFalse(fileManager.fileExists(atPath: projectURL.appendingPathComponent("points3D.ply").path))
        XCTAssertFalse(fileManager.fileExists(atPath: projectURL.appendingPathComponent("training.msplat-checkpoint").path))
        XCTAssertFalse(fileManager.fileExists(atPath: projectURL.appendingPathComponent(ScanProjectStore.worldMapFileName).path))
        XCTAssertFalse(fileManager.fileExists(atPath: projectURL.appendingPathComponent("s14-seed-recipe.json").path))

        for name in derivedNames {
            XCTAssertTrue(fileManager.fileExists(atPath: projectURL.appendingPathComponent(name).path), name)
        }
        XCTAssertFalse(try store.loadManifest(projectURL: projectURL).rawDataRetained)
    }

    func testReprocessRequestRejectsFutureManifestWithoutChangingProjectBytes() throws {
        let created = try store.createProject(title: "future reprocess")
        let projectURL = created.0
        let primary = projectURL.appendingPathComponent(ScanProjectStore.manifestFileName)
        try Data("transforms".utf8).write(to: projectURL.appendingPathComponent("transforms.json"))
        try Data("ply".utf8).write(to: projectURL.appendingPathComponent("points3D.ply"))

        let original = try Data(contentsOf: primary)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object["schemaVersion"] = ScanProjectManifest.currentSchemaVersion + 1
        object["futureOnlyField"] = ["preserve": true]
        let future = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try future.write(to: primary, options: .atomic)

        XCTAssertThrowsError(try store.reprocessRequest(projectURL: projectURL, representation: .splat)) { error in
            guard case ScanProjectStoreError.unsupportedManifestSchemaVersion(let version) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(version, ScanProjectManifest.currentSchemaVersion + 1)
        }
        XCTAssertEqual(try Data(contentsOf: primary), future)
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("transforms.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("points3D.ply").path))
    }
}
