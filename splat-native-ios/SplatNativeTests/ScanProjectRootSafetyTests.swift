import Foundation
import XCTest

final class ScanProjectRootSafetyTests: XCTestCase {
    func testSymlinkProjectRootIsNotLoadedOrWritten() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectRootSafetyTests-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("library", isDirectory: true)
        let outside = parent.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let sentinel = outside.appendingPathComponent("sentinel")
        try Data([0x53]).write(to: sentinel)
        let link = root.appendingPathComponent("evil").appendingPathExtension(ScanProjectStore.projectExtension)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        let store = ScanProjectStore(rootURL: root)
        XCTAssertFalse(store.listProjects().contains { $0.projectURL == link })
        XCTAssertThrowsError(try store.loadProject(id: "evil"))

        let manifest = ScanProjectManifest(id: "evil")
        XCTAssertThrowsError(try store.writeManifest(manifest, to: link))
        let checkpoint = ScanCaptureCheckpoint(
            frames: [], featurePoints: [], coverageSectors: [], estimatedTargetCenter: nil,
            lastAcceptedTransform: nil, lastAcceptedTimestamp: 0
        )
        XCTAssertThrowsError(try store.saveCheckpoint(checkpoint, projectURL: link))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([0x53]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent(ScanProjectStore.manifestFileName).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent(ScanProjectStore.checkpointFileName).path))
    }
}
