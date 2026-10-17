import XCTest

final class MeshArchivedRawEligibilityTests: XCTestCase {
    private let validRawPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAYElEQVR4nO3PQQ0AIBDAMED5SUcEj4ZkVbDtmVk/OzrgVQNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgPaBaIsAgBhHc02AAAAAElFTkSuQmCC")!
    private let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

    func testLibrarySummaryStopsAdvertisingReprocessWhenArchivedRawBecomesInsufficient() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshArchivedRawEligibilityTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let project = root.appendingPathComponent("source.meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        for index in 0..<MeshRawInputValidator.minimumPhotogrammetryImageCount {
            try validRawPNG.write(to: images.appendingPathComponent(String(format: "frame-%05d.png", index)))
        }

        let manifest: [String: Any] = [
            "schemaVersion": 1,
            "captureMode": "photogrammetry",
            "scanSize": "medium",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "frames": [],
            "lidarMeshAvailable": false,
            "texturedModelAvailable": true,
        ]
        try JSONSerialization.data(withJSONObject: manifest)
            .write(to: project.appendingPathComponent("mesh-project.json"), options: .atomic)
        let result = project.appendingPathComponent("mesh-textured.usdz")
        try Data(repeating: 0x55, count: 512).write(to: result, options: .atomic)

        let store = MeshProjectStore(appRootURL: root)
        let archived = try store.archiveFinishedProject(resultURL: result)
        XCTAssertTrue(archived.rawDataRetained)
        XCTAssertTrue(archived.reprocessSupported)

        let archivedImages = archived.projectURL.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.removeItem(at: archivedImages.appendingPathComponent("frame-00000.png"))

        let refreshed = try XCTUnwrap(store.listProjects().first)
        XCTAssertTrue(refreshed.rawDataRetained)
        XCTAssertFalse(refreshed.reprocessSupported)
    }

    func testReprocessDiscoveryReportsOnlyDecodableMeaningfulFrameCount() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshArchivedRawDiscoveryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let project = root.appendingPathComponent("source.meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        for index in 0..<MeshRawInputValidator.minimumPhotogrammetryImageCount {
            try validRawPNG.write(to: images.appendingPathComponent(String(format: "frame-%05d.png", index)))
        }
        try tinyPNG.write(to: images.appendingPathComponent("tiny-placeholder.png"))
        try Data(repeating: 0x7f, count: 64).write(to: images.appendingPathComponent("corrupt.jpg"))

        let discovered = MeshRawProjectBridge.discover(appRootURL: root)
        let summary = try XCTUnwrap(discovered.first(where: { $0.id == "mesh:source" }))
        XCTAssertEqual(summary.imageCount, MeshRawInputValidator.minimumPhotogrammetryImageCount)
    }

    func testTinyDecodableFramesDoNotEnableReprocess() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTinyRawEligibilityTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for index in 0..<MeshRawInputValidator.minimumPhotogrammetryImageCount {
            try tinyPNG.write(to: root.appendingPathComponent(String(format: "frame-%05d.png", index)))
        }

        XCTAssertEqual(MeshRawInputValidator.rawImageFileCount(in: root), MeshRawInputValidator.minimumPhotogrammetryImageCount)
        XCTAssertEqual(MeshRawInputValidator.usableImageCount(in: root), 0)
        XCTAssertFalse(MeshRawInputValidator.hasMinimumUsableImages(in: root))
    }
}
