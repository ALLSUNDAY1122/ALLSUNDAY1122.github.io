import Foundation
import XCTest

final class MeshTrimEditorSafetyTests: XCTestCase {
    func testAcceptsTabsAndLeadingWhitespaceWithoutLosingFaces() throws {
        let url = try writeOBJ([
            "\tv\t0\t0\t0", "v\t1\t0\t0", " v 0 1 0", "v 1 1 0",
            "\tf\t1\t2\t3", " f 2 4 3"
        ])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1)
        XCTAssertEqual(result.faceCount, 2)
        XCTAssertEqual(result.usedVertexCount, 4)
    }

    func testNegativeFaceIndicesResolveAtFaceAndUnusedVerticesAreCompacted() throws {
        let url = try writeOBJ([
            "v 0 0 0", "v 1 0 0", "v 0 1 0",
            "f -3 -2 -1",
            "v 100 100 100"
        ])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let result = try MeshTrimEngine.trim(url: url, x: 0...0.1, y: 0...0.1, z: 0...1)
        XCTAssertEqual(result.faceCount, 1)
        XCTAssertEqual(result.usedVertexCount, 3)
        let output = try String(contentsOf: result.url, encoding: .utf8)
        XCTAssertTrue(output.contains("f 1 2 3\n"))
        XCTAssertFalse(output.contains("v 100 100 100\n"))
        XCTAssertEqual(output.split(whereSeparator: \.isNewline).filter { $0.hasPrefix("v ") }.count, 3)
    }

    func testRejectsSymlinkMeshSource() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTrimEditorSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let actual = root.appendingPathComponent("actual.obj")
        let link = root.appendingPathComponent("mesh.obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n".write(to: actual, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: actual)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try MeshTrimEngine.trim(url: link, x: 0...1, y: 0...1, z: 0...1)) { error in
            XCTAssertTrue(error.localizedDescription.contains("安全な通常ファイル"))
        }
    }

    func testVertexBitsetCountsAcrossWordBoundary() throws {
        var lines = (0..<65).map { index in
            "v \(index) \(index % 2) 0"
        }
        lines.append("f 1 64 65")
        let url = try writeOBJ(lines)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let result = try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1)
        XCTAssertEqual(result.faceCount, 1)
        XCTAssertEqual(result.usedVertexCount, 3)
    }

    func testRejectsMalformedVertexInsteadOfShiftingFaceIndices() throws {
        let url = try writeOBJ(["v 0 0 0", "v broken 0 0", "v 0 1 0", "v 1 0 0", "f 1 3 4"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1))
    }

    func testRejectsMalformedFaceTokenInsteadOfCroppingInventedPolygon() throws {
        let url = try writeOBJ(["v 0 0 0", "v 1 0 0", "v 0 1 0", "v 1 1 0", "f 1 broken 3 4"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1))
    }

    func testRejectsNonFiniteVertexBeforeBoundsMath() throws {
        let url = try writeOBJ(["v 0 0 0", "v 1 0 0", "v nan 1 0", "v 1 1 0", "f 1 2 4"])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1))
    }

    func testStreamedTrimPreservesMaterialLibraryAndFaces() throws {
        let url = try writeOBJ([
            "mtllib material.mtl",
            "v 0 0 0", "v 1 0 0", "v 0 1 0",
            "vt 0 0", "vt 1 0", "vt 0 1",
            "usemtl material0",
            "f 1/1 2/2 3/3"
        ])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let result = try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1)
        let output = try String(contentsOf: result.url, encoding: .utf8)
        XCTAssertTrue(result.url.lastPathComponent.hasPrefix("mesh-textured-trimmed-"))
        XCTAssertTrue(output.contains("mtllib material.mtl\n"))
        XCTAssertTrue(output.contains("usemtl material0\n"))
        XCTAssertTrue(output.contains("f 1/1 2/2 3/3\n"))
    }

    func testChunkedReaderHandlesLineCrossingReadBoundary() throws {
        let longComment = "#" + String(repeating: "x", count: 300_000)
        let url = try writeOBJ([
            "v 0 0 0", "v 1 0 0", longComment, "v 0 1 0", "f 1 2 3"
        ])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let result = try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1)
        let output = try String(contentsOf: result.url, encoding: .utf8)
        XCTAssertEqual(result.faceCount, 1)
        XCTAssertEqual(result.usedVertexCount, 3)
        XCTAssertTrue(output.contains(longComment))
        XCTAssertTrue(output.contains("f 1 2 3\n"))
    }

    func testChunkedReaderRejectsOverLimitLineBeforeDecoding() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTrimEditorSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("mesh.obj")
        defer { try? FileManager.default.removeItem(at: root) }

        var data = Data("v 0 0 0\nv 1 0 0\n".utf8)
        data.append(contentsOf: "#".utf8)
        data.append(Data(repeating: 0x78, count: 8 * 1024 * 1024 + 1))
        data.append(contentsOf: "\nv 0 1 0\nf 1 2 3\n".utf8)
        try data.write(to: url)

        XCTAssertThrowsError(try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1)) { error in
            XCTAssertTrue(error.localizedDescription.contains("1行が大きすぎます"))
        }
        let leftovers = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("trimmed-") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testChunkedReaderAcceptsCRLFWithoutCarriageReturnLeakage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTrimEditorSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("mesh.obj")
        try "v 0 0 0\r\nv 1 0 0\r\nv 0 1 0\r\nf 1 2 3\r\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1)
        let output = try String(contentsOf: result.url, encoding: .utf8)
        XCTAssertEqual(result.faceCount, 1)
        XCTAssertFalse(output.contains("\r"))
        XCTAssertTrue(output.contains("f 1 2 3\n"))
    }

    func testFailedStreamedTrimRemovesPartialOutput() throws {
        let url = try writeOBJ([
            "v 0 0 0", "v 1 0 0", "v 0 1 0",
            "f 1 2 broken"
        ])
        let root = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try MeshTrimEngine.trim(url: url, x: 0...1, y: 0...1, z: 0...1))
        let leftovers = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("trimmed-") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    private func writeOBJ(_ lines: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTrimEditorSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("mesh.obj")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
