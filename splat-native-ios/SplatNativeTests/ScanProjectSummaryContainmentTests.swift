import Foundation
import XCTest

final class ScanProjectSummaryContainmentTests: XCTestCase {
    func testTraversalAndSymlinkAssetsAreNotExposedBySummary() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectSummaryContainmentTests-\(UUID().uuidString)", isDirectory: true)
        let project = parent.appendingPathComponent("project.splatproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let outsideSplat = parent.appendingPathComponent("outside.splat")
        let outsideJPG = parent.appendingPathComponent("outside.jpg")
        try Data(repeating: 0x53, count: 64).write(to: outsideSplat)
        try Data(repeating: 0x4A, count: 16).write(to: outsideJPG)

        var traversalManifest = ScanProjectManifest(id: "project")
        traversalManifest.outputs[ScanRepresentationKind.splat.rawValue] = "../outside.splat"
        traversalManifest.thumbnailFileName = "../outside.jpg"
        let traversal = ScanProjectSummary(manifest: traversalManifest, projectURL: project, storageBytes: 0)
        XCTAssertNil(traversal.resultURL)
        XCTAssertNil(traversal.thumbnailURL)

        let resultLink = project.appendingPathComponent("result.splat")
        let thumbnailLink = project.appendingPathComponent("thumbnail.jpg")
        try FileManager.default.createSymbolicLink(at: resultLink, withDestinationURL: outsideSplat)
        try FileManager.default.createSymbolicLink(at: thumbnailLink, withDestinationURL: outsideJPG)
        var symlinkManifest = ScanProjectManifest(id: "project")
        symlinkManifest.outputs[ScanRepresentationKind.splat.rawValue] = "result.splat"
        symlinkManifest.thumbnailFileName = "thumbnail.jpg"
        let symlink = ScanProjectSummary(manifest: symlinkManifest, projectURL: project, storageBytes: 0)
        XCTAssertNil(symlink.resultURL)
        XCTAssertNil(symlink.thumbnailURL)
    }

    func testRegularContainedAssetsRemainAvailable() throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectSummaryContainmentTests-\(UUID().uuidString).splatproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }

        let result = project.appendingPathComponent("result.splat")
        let thumbnail = project.appendingPathComponent("thumbnail.jpg")
        try Data(repeating: 0x53, count: 64).write(to: result)
        try Data(repeating: 0x4A, count: 16).write(to: thumbnail)

        var manifest = ScanProjectManifest(id: "project")
        manifest.outputs[ScanRepresentationKind.splat.rawValue] = "result.splat"
        manifest.thumbnailFileName = "thumbnail.jpg"
        let summary = ScanProjectSummary(manifest: manifest, projectURL: project, storageBytes: 80)
        XCTAssertEqual(summary.resultURL, result.standardizedFileURL)
        XCTAssertEqual(summary.thumbnailURL, thumbnail.standardizedFileURL)
    }
}
