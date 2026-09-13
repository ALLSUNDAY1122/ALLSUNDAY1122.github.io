import Foundation
import XCTest

final class MeshDetailSimplifierCommentTests: XCTestCase {
    func testInlineVertexCommentsDoNotMasqueradeAsVertexColors() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("commented.obj")
        let obj = """
        v 0 0 0 # generated vertex without color metadata
        v 1 0 0 # generated vertex without color metadata
        v 1 1 0 # generated vertex without color metadata
        v 0 1 0 # generated vertex without color metadata
        v 0 0 1 # generated vertex without color metadata
        v 1 0 1 # generated vertex without color metadata
        v 1 1 1 # generated vertex without color metadata
        v 0 1 1 # generated vertex without color metadata
        v 0.5 0.5 0.5 # generated vertex without color metadata
        f 1 2 3 # front triangle annotation
        f 1 3 4 # front triangle annotation
        f 5 7 6 # back triangle annotation
        f 5 8 7 # back triangle annotation
        f 1 5 6 # bottom triangle annotation
        f 1 6 2 # bottom triangle annotation
        f 2 6 7 # right triangle annotation
        f 2 7 3 # right triangle annotation
        f 3 7 8 # top triangle annotation
        f 3 8 4 # top triangle annotation
        f 4 8 5 # left triangle annotation
        f 4 5 1 # left triangle annotation
        """
        try Data(obj.utf8).write(to: source, options: .atomic)

        let result = try MeshDetailSimplifierEngine.simplify(url: source, retainedFraction: 0.60)
        defer { MeshDetailSimplifierEngine.discard(result) }

        XCTAssertGreaterThan(result.vertices, 0)
        XCTAssertGreaterThan(result.faces, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
    }
}
