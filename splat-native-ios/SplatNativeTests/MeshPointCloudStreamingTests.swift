import Foundation
import XCTest

final class MeshPointCloudStreamingTests: XCTestCase {
    func testPLYParsesOBJAcrossChunkBoundaryWithCRLFAndUTF8() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-pointcloud-streaming-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let objURL = root.appendingPathComponent("streamed.obj")
        var source = Data()
        source.append(contentsOf: "# ".utf8)
        source.append(contentsOf: Array(repeating: UInt8(ascii: "a"), count: 256 * 1024 - 4))
        source.append(contentsOf: "あ\r\n".utf8)
        source.append(contentsOf: "v 0 0 0\r\nv 1 0 0\r\nv 0 1 0\r\nf 1 2 3".utf8)
        try source.write(to: objURL, options: .atomic)

        let outputURL = root.appendingPathComponent("streamed.ply")
        try MeshPointCloudExportService.exportPLY(sourceOBJ: objURL, outputURL: outputURL)

        let output = try Data(contentsOf: outputURL)
        guard let headerEnd = output.range(of: Data("end_header\n".utf8)) else {
            return XCTFail("Missing PLY header terminator")
        }
        let header = String(decoding: output[..<headerEnd.upperBound], as: UTF8.self)
        XCTAssertTrue(header.contains("element vertex 3"))
        XCTAssertFalse(header.contains("property uchar red"))
        XCTAssertEqual(output[headerEnd.upperBound...].count, 36)
    }
}
