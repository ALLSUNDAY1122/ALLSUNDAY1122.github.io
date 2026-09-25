import Foundation
import XCTest

final class MeshDetailSimplifierSafetyTests: XCTestCase {
    func testRejectsOutOfRangeFaceIndexBeforeUnionFind() throws {
        let url = try writeOBJ(vertices: (0..<10).map { "v \($0) 0 0" }, faces: ["f 1 2 999999"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    func testRejectsMalformedFaceTokenInsteadOfInventingTriangle() throws {
        let url = try writeOBJ(vertices: (0..<10).map { "v \($0) \($0 % 2) 0" }, faces: ["f 1 broken 3 4"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    func testAllowsInlineCommentAfterValidFace() throws {
        let vertices = ["v 0 0 0", "v 1 0 0", "v 0 1 0", "v 1 1 0", "v 0 0 1", "v 1 0 1", "v 0 1 1", "v 1 1 1", "v 2 0 0", "v 2 1 0"]
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3 # front triangle"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertNoThrow(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    func testAcceptsTabAndLeadingWhitespaceInOBJRecords() throws {
        let vertices = ["\tv\t0\t0\t0", "v\t1\t0\t0", " v 0 1 0", "v\t1\t1\t0", "v 0 0 1", "v 1 0 1", "v 0 1 1", "v 1 1 1", "v 2 0 0", "v 2 1 0"]
        let url = try writeOBJ(vertices: vertices, faces: ["\tf\t1\t2\t3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertNoThrow(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    func testRejectsTexturedOBJInsteadOfSilentlyDroppingUVAndMaterial() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("textured.obj")
        let vertices = (0..<10).map { "v \($0) \($0 % 2) 0" }
        let text = (["mtllib mesh.mtl"] + vertices + ["vt 0 0", "vt 1 0", "vt 0 1", "usemtl scan", "f 1/1 2/2 3/3"]).joined(separator: "\n") + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6)) { error in
            XCTAssertTrue(error.localizedDescription.contains("テクスチャ"))
        }
    }

    func testPreservesPerVertexRGBColors() throws {
        let vertices = [
            "v 0 0 0 1 0 0", "v 1 0 0 0 1 0", "v 0 1 0 0 0 1", "v 1 1 0 1 1 0", "v 0 0 1 1 0 1",
            "v 1 0 1 0 1 1", "v 0 1 1 0.5 0.5 0.5", "v 1 1 1 1 1 1", "v 2 0 0 0.2 0.3 0.4", "v 2 1 0 0.4 0.3 0.2"
        ]
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3", "f 2 4 3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6)
        let output = try String(contentsOf: result.url, encoding: .utf8)
        let vertexLines = output.split(whereSeparator: \.isNewline).filter { $0.hasPrefix("v ") }
        XCTAssertFalse(vertexLines.isEmpty)
        XCTAssertTrue(vertexLines.allSatisfy { $0.split(whereSeparator: \.isWhitespace).count == 7 })
    }

    func testRejectsMixedColoredAndUncoloredVerticesInsteadOfPartiallyDroppingColor() throws {
        var vertices = (0..<10).map { "v \($0) 0 0 1 0 0" }
        vertices[5] = "v 5 0 0"
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6)) { error in
            XCTAssertTrue(error.localizedDescription.contains("頂点色"))
        }
    }

    func testRejectsMalformedVertexInsteadOfShiftingSubsequentIndices() throws {
        var vertices = (0..<9).map { "v \($0) 0 0" }
        vertices.insert("v broken 1 2", at: 3)
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    func testRejectsNonFiniteVertexBeforeGridIntegerConversion() throws {
        var vertices = (0..<9).map { "v \($0) 0 0" }; vertices.append("v nan 1 2")
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    func testRejectsFiniteCoordinatesWhoseExtentOverflowsFloat() throws {
        let huge = Float.greatestFiniteMagnitude
        var vertices = ["v \(-huge) 0 0", "v \(huge) 0 0"]; vertices.append(contentsOf: (0..<8).map { "v \($0) 1 0" })
        let url = try writeOBJ(vertices: vertices, faces: ["f 1 2 3"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: 0.6))
    }

    private func writeOBJ(vertices: [String], faces: [String]) throws -> URL {
        let directory = try makeRoot(); let url = directory.appendingPathComponent("input.obj")
        try ((vertices + faces).joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeRoot() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MeshDetailSimplifierSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
