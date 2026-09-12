import XCTest
import UIKit

final class SplatSoftwareDepthSeedSafetyTests: XCTestCase {
    func testTraversalImagesOutsideProjectAreNotLoaded() throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let project = parent.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeImage(to: parent.appendingPathComponent("outside.png"))

        let frames = (0..<4).map { _ in frame(filePath: "../outside.png") }
        let result = SplatSoftwareDepthSeedBuilder.makeSeedPoints(projectURL: project, frames: frames)

        XCTAssertEqual(result.framesUsed, 0)
        XCTAssertTrue(result.points.isEmpty)
        XCTAssertTrue(result.colors.isEmpty)
    }

    func testExternalSymlinkImagesAreNotLoaded() throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let project = parent.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let outside = parent.appendingPathComponent("outside.png")
        try writeImage(to: outside)
        try FileManager.default.createSymbolicLink(
            at: project.appendingPathComponent("linked.png"),
            withDestinationURL: outside
        )

        let frames = (0..<4).map { _ in frame(filePath: "linked.png") }
        let result = SplatSoftwareDepthSeedBuilder.makeSeedPoints(projectURL: project, frames: frames)

        XCTAssertEqual(result.framesUsed, 0)
        XCTAssertTrue(result.points.isEmpty)
    }

    func testNonFiniteCameraMatrixIsRejectedBeforeMVS() throws {
        let project = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        try writeImage(to: project.appendingPathComponent("frame.png"))
        var transform = identityMatrix
        transform[0][1] = .nan

        let frames = (0..<4).map { _ in frame(filePath: "frame.png", transform: transform) }
        let result = SplatSoftwareDepthSeedBuilder.makeSeedPoints(projectURL: project, frames: frames)

        XCTAssertEqual(result.framesUsed, 0)
        XCTAssertTrue(result.points.isEmpty)
    }

    func testThumbnailPrincipalPointPreservesPixelCenterConvention() throws {
        XCTAssertEqual(
            try XCTUnwrap(SplatSoftwareDepthSeedBuilder.scaledPrincipalPointCoordinate(959.5, scale: 0.1)),
            95.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(SplatSoftwareDepthSeedBuilder.scaledPrincipalPointCoordinate(37, scale: 1)),
            37,
            accuracy: 0.0001
        )
    }

    func testThumbnailPrincipalPointRejectsInvalidScaleOrCoordinate() {
        XCTAssertNil(SplatSoftwareDepthSeedBuilder.scaledPrincipalPointCoordinate(.nan, scale: 0.1))
        XCTAssertNil(SplatSoftwareDepthSeedBuilder.scaledPrincipalPointCoordinate(100, scale: .infinity))
        XCTAssertNil(SplatSoftwareDepthSeedBuilder.scaledPrincipalPointCoordinate(100, scale: 0))
        XCTAssertNil(SplatSoftwareDepthSeedBuilder.scaledPrincipalPointCoordinate(100, scale: -1))
    }

    private var identityMatrix: [[Float]] {
        [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
    }

    private func frame(filePath: String, transform: [[Float]]? = nil) -> SplatSeedFrame {
        SplatSeedFrame(
            filePath: filePath,
            transformMatrix: transform ?? identityMatrix,
            flX: 500,
            flY: 500,
            cx: 16,
            cy: 16,
            w: 32,
            h: 32
        )
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeImage(to url: URL) throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            context.cgContext.fill(CGRect(x: 16, y: 16, width: 16, height: 16))
        }
        guard let data = image.pngData() else {
            XCTFail("Expected PNG data")
            return
        }
        try data.write(to: url)
    }
}
