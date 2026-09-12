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

    private func writeOBJ(_ lines: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTrimEditorSafety-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("mesh.obj")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
