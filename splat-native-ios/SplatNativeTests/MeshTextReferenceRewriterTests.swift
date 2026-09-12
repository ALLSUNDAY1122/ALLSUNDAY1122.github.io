import Foundation
import XCTest

final class MeshTextReferenceRewriterTests: XCTestCase {
    func testFindsIndentedReferenceAndRewritesWithoutMaterializingWholeFile() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.obj")
        let output = root.appendingPathComponent("output.obj")
        let payload = "# obj\n   mtllib original material.mtl\nv 0 0 0\nf 1 1 1\n"
        try Data(payload.utf8).write(to: source)

        XCTAssertEqual(try MeshTextReferenceRewriter.firstReference(in: source, directive: "mtllib"), "original material.mtl")
        XCTAssertTrue(try MeshTextReferenceRewriter.rewrite(
            sourceURL: source,
            destinationURL: output,
            directive: "mtllib",
            replacement: "edited.mtl"
        ))
        let rewritten = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(rewritten.contains("mtllib edited.mtl\n"))
        XCTAssertTrue(rewritten.contains("v 0 0 0\n"))
        XCTAssertFalse(rewritten.contains("original material.mtl"))
    }

    func testRejectsSymlinkedSource() throws {
        let root = try makeRoot()
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside-\(UUID().uuidString).obj")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try Data("mtllib outside.mtl\n".utf8).write(to: outside)
        let link = root.appendingPathComponent("source.obj")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        XCTAssertThrowsError(try MeshTextReferenceRewriter.firstReference(in: link, directive: "mtllib"))
    }

    func testFailedRewriteLeavesNoPartialOutput() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.obj")
        let output = root.appendingPathComponent("output.obj")
        try Data("v 0 0 0\n".utf8).write(to: source)

        XCTAssertThrowsError(try MeshTextReferenceRewriter.rewrite(
            sourceURL: source,
            destinationURL: output,
            directive: "mtllib",
            replacement: "edited.mtl"
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testRewriteCannotOverwriteSourceOrExistingDestination() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.obj")
        let existing = root.appendingPathComponent("existing.obj")
        let payload = Data("mtllib original.mtl\nv 0 0 0\n".utf8)
        try payload.write(to: source)
        try Data("sentinel".utf8).write(to: existing)

        XCTAssertThrowsError(try MeshTextReferenceRewriter.rewrite(
            sourceURL: source,
            destinationURL: source,
            directive: "mtllib",
            replacement: "edited.mtl"
        ))
        XCTAssertEqual(try Data(contentsOf: source), payload)

        XCTAssertThrowsError(try MeshTextReferenceRewriter.rewrite(
            sourceURL: source,
            destinationURL: existing,
            directive: "mtllib",
            replacement: "edited.mtl"
        ))
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "sentinel")
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshTextReferenceRewriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
