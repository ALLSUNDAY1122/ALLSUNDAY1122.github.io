import Foundation
import XCTest

final class MeshPointCloudCorruptTextureFallbackTests: XCTestCase {
    func testCorruptMapKdFallsBackToGeometryOnlyPLY() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-pointcloud-corrupt-texture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

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
        try """
        newmtl capture
        map_Kd corrupt.png
        """.write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)
        try Data("not-an-image".utf8).write(to: root.appendingPathComponent("corrupt.png"))

        let output = root.appendingPathComponent("capture.ply")
        XCTAssertNoThrow(try MeshPointCloudExportService.exportPLY(sourceOBJ: obj, outputURL: output))

        let data = try Data(contentsOf: output)
        let marker = Data("end_header\n".utf8)
        guard let range = data.range(of: marker) else { return XCTFail("Missing PLY header terminator") }
        let header = String(decoding: data[..<range.upperBound], as: UTF8.self)
        XCTAssertFalse(header.contains("property uchar red"))
        XCTAssertTrue(header.contains("element vertex 3"))
        XCTAssertEqual(data[range.upperBound...].count, 36)
    }
}
