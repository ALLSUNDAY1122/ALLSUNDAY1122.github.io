import Foundation
import XCTest

final class MeshPLYContainerValidationTests: XCTestCase {
    func testPLYPassthroughRejectsTruncatedBinaryVertexPayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-ply-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let header = """
        ply
        format binary_little_endian 1.0
        element vertex 2
        property float x
        property float y
        property float z
        end_header
        """ + "\n"
        var bytes = Data(header.utf8)
        bytes.append(Data(repeating: 0, count: 12)) // one vertex only; header declares two
        let source = root.appendingPathComponent("truncated.ply")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .ply, destinationDirectory: root)
            XCTFail("Expected truncated PLY vertex payload to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("ply") = error else {
                return XCTFail("Expected invalidContainer(ply), got \(error)")
            }
        }
    }

    func testPLYPassthroughAcceptsExactBinaryVertexPayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-ply-valid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let header = """
        ply
        format binary_little_endian 1.0
        element vertex 2
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        end_header
        """ + "\n"
        var bytes = Data(header.utf8)
        bytes.append(Data(repeating: 0, count: 30)) // 2 * (xyz Float32 + rgb UInt8)
        let source = root.appendingPathComponent("valid.ply")
        try bytes.write(to: source, options: .atomic)

        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .ply,
            destinationDirectory: root
        )
        XCTAssertEqual(try Data(contentsOf: output), bytes)
    }

    func testPLYPassthroughRejectsListPropertyPointCloudSchema() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-ply-list-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let header = """
        ply
        format binary_little_endian 1.0
        element vertex 1
        property float x
        property float y
        property float z
        property list uchar int neighbors
        end_header
        """ + "\n"
        var bytes = Data(header.utf8)
        bytes.append(Data(repeating: 0, count: 12))
        let source = root.appendingPathComponent("list-property.ply")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .ply, destinationDirectory: root)
            XCTFail("Expected variable-length PLY list property to be rejected by point-cloud validator")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("ply") = error else {
                return XCTFail("Expected invalidContainer(ply), got \(error)")
            }
        }
    }
}
