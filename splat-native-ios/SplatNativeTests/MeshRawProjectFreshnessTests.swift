import Foundation
import XCTest

final class MeshRawProjectFreshnessTests: XCTestCase {
    func testDiscoveryIgnoresZeroByteImagePlaceholders() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("mesh-raw-freshness-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let project = root.appendingPathComponent("sample.meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        try Data().write(to: images.appendingPathComponent("mesh_00000.jpg"))

        XCTAssertTrue(MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager).isEmpty)

        try Data([0xFF]).write(to: images.appendingPathComponent("mesh_00000.jpg"))
        let discovered = MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager)
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered.first?.imageCount, 1)
    }

    func testPrepareRejectsRawRemovedAfterDiscovery() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("mesh-raw-stale-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let project = root.appendingPathComponent("sample.meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        let imageURL = images.appendingPathComponent("mesh_00000.jpg")
        try Data([0xFF]).write(to: imageURL)

        let discovered = try XCTUnwrap(
            MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager).first
        )
        try fileManager.removeItem(at: imageURL)

        XCTAssertThrowsError(
            try MeshRawProjectBridge.prepareWorkingProject(for: discovered, fileManager: fileManager)
        ) { error in
            XCTAssertNotNil(error as? MeshRawProjectBridgeError)
        }
    }
}
