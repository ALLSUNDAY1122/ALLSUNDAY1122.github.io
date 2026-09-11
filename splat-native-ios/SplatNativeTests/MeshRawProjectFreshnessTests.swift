import Foundation
import XCTest

final class MeshRawProjectFreshnessTests: XCTestCase {
    private let usablePNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATUlEQVR42u3PQQ0AAAgEIDX5RTeFDzdoQCepz6aeExAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQELi3oiwCAJt186UAAAAASUVORK5CYII=")!

    func testDiscoveryIgnoresZeroByteAndUndecodableImagePlaceholders() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("mesh-raw-freshness-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let project = root.appendingPathComponent("sample.meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        try Data().write(to: images.appendingPathComponent("mesh_00000.jpg"))
        try Data([0xFF]).write(to: images.appendingPathComponent("mesh_00001.jpg"))

        XCTAssertTrue(MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager).isEmpty)

        try writeMinimumUsableImages(to: images)
        let discovered = MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager)
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered.first?.imageCount, MeshRawInputValidator.minimumPhotogrammetryImageCount)
    }

    func testPrepareRejectsRawRemovedAfterDiscovery() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("mesh-raw-stale-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let project = root.appendingPathComponent("sample.meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        try writeMinimumUsableImages(to: images)

        let discovered = try XCTUnwrap(
            MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager).first
        )
        try fileManager.removeItem(at: images.appendingPathComponent("frame_00000.png"))

        XCTAssertThrowsError(
            try MeshRawProjectBridge.prepareWorkingProject(for: discovered, fileManager: fileManager)
        ) { error in
            XCTAssertNotNil(error as? MeshRawProjectBridgeError)
        }
    }

    private func writeMinimumUsableImages(to directory: URL) throws {
        for index in 0..<MeshRawInputValidator.minimumPhotogrammetryImageCount {
            try usablePNG.write(
                to: directory.appendingPathComponent(String(format: "frame_%05d.png", index)),
                options: .atomic
            )
        }
    }
}
