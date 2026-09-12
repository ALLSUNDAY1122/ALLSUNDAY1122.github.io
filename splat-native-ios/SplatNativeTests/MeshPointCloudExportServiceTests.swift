import CoreGraphics
import Foundation
import ImageIO
import XCTest

final class MeshPointCloudExportServiceTests: XCTestCase {
    func testPLYKeepsTextureColorWhenMapKdUsesOptionsAndQuotedPath() throws {
        let root = try temporaryRoot("mesh-pointcloud-map-options")
        defer { try? FileManager.default.removeItem(at: root) }

        let texture = root.appendingPathComponent("captured color.png")
        try writeSolidPNG(to: texture, rgba: [255, 0, 0, 255])
        try """
        newmtl capture
        map_Kd -clamp on -s 1 1 1 "captured color.png" # real captured atlas
        """.write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)
        let obj = root.appendingPathComponent("capture.obj")
        try """
        mtllib capture.mtl
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vt 0 0
        vt 1 0
        vt 0 1
        usemtl capture
        f 1/1 2/2 3/3
        """.write(to: obj, atomically: true, encoding: .utf8)

        let output = root.appendingPathComponent("capture.ply")
        try MeshPointCloudExportService.exportPLY(sourceOBJ: obj, outputURL: output)
        let data = try Data(contentsOf: output)
        let marker = Data("end_header\n".utf8)
        guard let range = data.range(of: marker) else { return XCTFail("Missing PLY header terminator") }
        let header = String(decoding: data[..<range.upperBound], as: UTF8.self)
        XCTAssertTrue(header.contains("property uchar red"), "Texture-backed PLY must retain RGB fields")
        XCTAssertTrue(header.contains("element vertex 3"))

        let body = data[range.upperBound...]
        XCTAssertEqual(body.count, 45, "Three textured points should be 15 bytes each")
        for record in 0..<3 {
            let colorOffset = body.startIndex + record * 15 + 12
            XCTAssertEqual(body[colorOffset], 255)
            XCTAssertEqual(body[colorOffset + 1], 0)
            XCTAssertEqual(body[colorOffset + 2], 0)
        }
    }

    func testLASBoundsRemainExactAfterSinglePassComputation() throws {
        let root = try temporaryRoot("mesh-pointcloud-las-bounds")
        defer { try? FileManager.default.removeItem(at: root) }
        let obj = root.appendingPathComponent("bounds.obj")
        try """
        v -2.5 4 -8
        v 7.25 -3 2
        v 1 6.5 10.75
        """.write(to: obj, atomically: true, encoding: .utf8)

        let output = root.appendingPathComponent("bounds.las")
        try MeshPointCloudExportService.exportLAS12(sourceOBJ: obj, outputURL: output)
        let data = try Data(contentsOf: output)
        XCTAssertEqual(data.count, 227 + 3 * 20)
        XCTAssertEqual(readDoubleLE(data, at: 179), 7.25, accuracy: 0.000_000_1) // max X
        XCTAssertEqual(readDoubleLE(data, at: 187), -2.5, accuracy: 0.000_000_1) // min X
        XCTAssertEqual(readDoubleLE(data, at: 195), 6.5, accuracy: 0.000_000_1) // max Y
        XCTAssertEqual(readDoubleLE(data, at: 203), -3, accuracy: 0.000_000_1) // min Y
        XCTAssertEqual(readDoubleLE(data, at: 211), 10.75, accuracy: 0.000_000_1) // max Z
        XCTAssertEqual(readDoubleLE(data, at: 219), -8, accuracy: 0.000_000_1) // min Z
    }

    func testPLYDoesNotTreatMapOptionTokensAsTextureFilename() throws {
        let root = try temporaryRoot("mesh-pointcloud-map-clamp")
        defer { try? FileManager.default.removeItem(at: root) }
        let texture = root.appendingPathComponent("atlas.png")
        try writeSolidPNG(to: texture, rgba: [0, 255, 0, 255])
        try "map_Kd -o 0 0 0 -clamp on atlas.png\n"
            .write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)
        let obj = root.appendingPathComponent("capture.obj")
        try """
        mtllib capture.mtl
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vt 0.5 0.5
        vt 0.5 0.5
        vt 0.5 0.5
        f 1/1 2/2 3/3
        """.write(to: obj, atomically: true, encoding: .utf8)

        let output = root.appendingPathComponent("capture.ply")
        try MeshPointCloudExportService.exportPLY(sourceOBJ: obj, outputURL: output)
        let data = try Data(contentsOf: output)
        let marker = Data("end_header\n".utf8)
        guard let range = data.range(of: marker) else { return XCTFail("Missing PLY header terminator") }
        let header = String(decoding: data[..<range.upperBound], as: UTF8.self)
        XCTAssertTrue(header.contains("property uchar green"))
        let body = data[range.upperBound...]
        XCTAssertEqual(body[body.startIndex + 12], 0)
        XCTAssertEqual(body[body.startIndex + 13], 255)
        XCTAssertEqual(body[body.startIndex + 14], 0)
    }

    private func temporaryRoot(_ prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeSolidPNG(to url: URL, rgba: [UInt8]) throws {
        precondition(rgba.count == 4)
        let pixel = Data(rgba)
        guard let provider = CGDataProvider(data: pixel as CFData),
              let image = CGImage(
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw NSError(domain: "MeshPointCloudExportServiceTests", code: 1)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MeshPointCloudExportServiceTests", code: 2)
        }
    }

    private func readDoubleLE(_ data: Data, at offset: Int) -> Double {
        precondition(offset >= 0 && offset + 8 <= data.count)
        var bits: UInt64 = 0
        for index in 0..<8 {
            bits |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        return Double(bitPattern: bits)
    }
}
