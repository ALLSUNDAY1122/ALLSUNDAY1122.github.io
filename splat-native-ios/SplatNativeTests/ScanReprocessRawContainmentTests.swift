import Foundation
import XCTest

final class ScanReprocessRawContainmentTests: XCTestCase {
    func testSymlinkedRawComponentsAreRejectedBeforeReprocess() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanReprocessRawContainmentTests-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("library", isDirectory: true)
        let outside = parent.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let store = ScanProjectStore(rootURL: root)
        let created = try store.createProject(title: "raw")
        let project = created.0
        let images = project.appendingPathComponent("images", isDirectory: true)
        let transforms = project.appendingPathComponent("transforms.json")
        let points = project.appendingPathComponent("points3D.ply")
        try Data("{}".utf8).write(to: transforms)
        try Data("ply".utf8).write(to: points)

        _ = try store.reprocessRequest(projectURL: project, representation: .splat)

        let outsideTransforms = outside.appendingPathComponent("transforms.json")
        try Data("{}".utf8).write(to: outsideTransforms)
        try FileManager.default.removeItem(at: transforms)
        try FileManager.default.createSymbolicLink(at: transforms, withDestinationURL: outsideTransforms)
        XCTAssertThrowsError(try store.reprocessRequest(projectURL: project, representation: .splat))

        try FileManager.default.removeItem(at: transforms)
        try Data("{}".utf8).write(to: transforms)
        let outsidePoints = outside.appendingPathComponent("points3D.ply")
        try Data("ply".utf8).write(to: outsidePoints)
        try FileManager.default.removeItem(at: points)
        try FileManager.default.createSymbolicLink(at: points, withDestinationURL: outsidePoints)
        XCTAssertThrowsError(try store.reprocessRequest(projectURL: project, representation: .splat))

        try FileManager.default.removeItem(at: points)
        try Data("ply".utf8).write(to: points)
        let outsideImages = outside.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideImages, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: images)
        try FileManager.default.createSymbolicLink(at: images, withDestinationURL: outsideImages)
        XCTAssertThrowsError(try store.reprocessRequest(projectURL: project, representation: .splat))
    }
}
