import Foundation
import XCTest

final class MeshDetailSimplifierSafetyTests: XCTestCase {
    func testRejectsOutOfRangeFaceIndexBeforeUnionFind() throws {
        let url = try writeOBJ(
            vertices: (0..<10).map { "v \($0) 0 0" },
            faces: ["f 1 2 999999"]
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6)) { error in
            XCTAssertEqual((error as NSError).domain, "ScanLab.MeshDetailSimplifier")
        }
    }

    func testRejectsNonFiniteVertexBeforeGridIntegerConversion() throws {
        var vertices = (0..<9).map { "v \($0) 0 0" }
        vertices.append("v nan 1 2")
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6)) { error in
            XCTAssertEqual((error as NSError).domain, "ScanLab.MeshDetailSimplifier")
        }
    }

    private func writeOBJ(vertices: [String], faces: [String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshDetailSimplifierSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("input.obj")
        let text = (vertices + faces).joined(separator: "\n") + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
