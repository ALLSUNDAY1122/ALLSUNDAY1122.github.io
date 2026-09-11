import Foundation
import XCTest

final class MeshRawInputValidatorTests: XCTestCase {
    private let usablePNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATUlEQVR42u3PQQ0AAAgEIDX5RTeFDzdoQCepz6aeExAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQELi3oiwCAJt186UAAAAASUVORK5CYII=")!
    private let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

    func testRejectsRenamedCorruptImageBytes() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([0xFF]).write(to: directory.appendingPathComponent("broken.jpg"))

        XCTAssertFalse(
            MeshRawInputValidator.hasMinimumUsableImages(in: directory, minimumCount: 1)
        )
    }

    func testRejectsStructurallyReadableButImplausiblyTinyImage() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try onePixelPNG.write(to: directory.appendingPathComponent("tiny.png"))

        XCTAssertFalse(
            MeshRawInputValidator.hasMinimumUsableImages(in: directory, minimumCount: 1)
        )
    }

    func testAcceptsStructurallyReadableImageAboveMinimumDimensions() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try usablePNG.write(to: directory.appendingPathComponent("valid.png"))

        XCTAssertTrue(
            MeshRawInputValidator.hasMinimumUsableImages(in: directory, minimumCount: 1)
        )
    }

    func testPhotogrammetryGateRequiresTwentyUsableImages() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<19 {
            try usablePNG.write(to: directory.appendingPathComponent("frame_\(index).png"))
        }
        XCTAssertFalse(MeshRawInputValidator.hasMinimumUsableImages(in: directory))

        try usablePNG.write(to: directory.appendingPathComponent("frame_19.png"))
        XCTAssertTrue(MeshRawInputValidator.hasMinimumUsableImages(in: directory))
        XCTAssertEqual(MeshRawInputValidator.minimumPhotogrammetryImageCount, 20)
    }

    func testSymlinkedExternalImageIsNotRetainedRawOrReprocessInput() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let images = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        let external = root.appendingPathComponent("external.png")
        try usablePNG.write(to: external)
        let linked = images.appendingPathComponent("linked.png")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: external)

        XCTAssertEqual(MeshRawInputValidator.rawImageFileCount(in: images), 0)
        XCTAssertEqual(MeshRawInputValidator.usableImageCount(in: images), 0)
        XCTAssertFalse(MeshRawInputValidator.hasAnyRawImageBytes(in: images))
        XCTAssertFalse(MeshRawInputValidator.hasMinimumUsableImages(in: images, minimumCount: 1))
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-raw-validator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
