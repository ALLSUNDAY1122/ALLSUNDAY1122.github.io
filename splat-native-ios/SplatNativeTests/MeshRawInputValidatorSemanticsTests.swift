import XCTest

final class MeshRawInputValidatorSemanticsTests: XCTestCase {
    func testRetainedBytesAndReprocessEligibilityRemainDistinct() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshRawInputValidatorSemanticsTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        for index in 0..<19 {
            try png.write(to: root.appendingPathComponent("frame-\(index).png"))
        }
        try Data(repeating: 0x7f, count: 64).write(to: root.appendingPathComponent("corrupt.jpg"))

        XCTAssertTrue(MeshRawInputValidator.hasAnyRawImageBytes(in: root))
        XCTAssertEqual(MeshRawInputValidator.rawImageFileCount(in: root), 20)
        XCTAssertFalse(MeshRawInputValidator.hasMinimumUsableImages(in: root))
    }

    func testHeaderOnlyImageIsRetainedButNotReprocessable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshRawInputValidatorDecodeTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        for index in 0..<19 {
            try png.write(to: root.appendingPathComponent("frame-\(index).png"))
        }

        // Keep PNG signature + complete IHDR + IEND while removing IDAT pixel payload. ImageIO can
        // still discover dimensions from the header, but a real thumbnail decode must fail.
        let headerOnlyPNG = Data(png.prefix(33)) + Data(png.suffix(12))
        try headerOnlyPNG.write(to: root.appendingPathComponent("frame-header-only.png"))

        XCTAssertTrue(MeshRawInputValidator.hasAnyRawImageBytes(in: root))
        XCTAssertEqual(MeshRawInputValidator.rawImageFileCount(in: root), 20)
        XCTAssertEqual(MeshRawInputValidator.usableImageCount(in: root), 19)
        XCTAssertFalse(MeshRawInputValidator.hasMinimumUsableImages(in: root))
    }
}
