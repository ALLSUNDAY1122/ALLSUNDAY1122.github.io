import XCTest

final class MeshTextReferenceOptionTests: XCTestCase {
    func testOptionedQuotedDiffuseMapReturnsActualTexturePath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-text-reference-options-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let mtl = root.appendingPathComponent("mesh.mtl")
        try "newmtl scan\nmap_Kd -s 1 1 1 -o 0.25 0.5 0 \"textures/base color.jpg\" # diffuse\n"
            .write(to: mtl, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            try MeshTextReferenceRewriter.firstReference(in: mtl, directive: "map_Kd"),
            "textures/base color.jpg"
        )
    }

    func testMapKdRewriteStillReplacesWholeDirectiveWithEditedTexture() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-text-reference-rewrite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.mtl")
        let output = root.appendingPathComponent("edited.mtl")
        try "newmtl scan\nmap_Kd -s 1 1 1 \"old texture.jpg\"\n"
            .write(to: source, atomically: true, encoding: .utf8)

        XCTAssertTrue(try MeshTextReferenceRewriter.rewrite(
            sourceURL: source,
            destinationURL: output,
            directive: "map_Kd",
            replacement: "edited.jpg"
        ))
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(text.contains("map_Kd edited.jpg\n"))
        XCTAssertFalse(text.contains("old texture.jpg"))
    }
}
