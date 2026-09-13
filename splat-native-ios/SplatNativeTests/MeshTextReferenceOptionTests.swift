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

    func testQuotedMaterialLibraryWithInlineCommentReturnsActualFilename() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-material-reference-options-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let obj = root.appendingPathComponent("mesh.obj")
        try "mtllib \"scan material.mtl\" # exported material\nv 0 0 0\n"
            .write(to: obj, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            try MeshTextReferenceRewriter.firstReference(in: obj, directive: "mtllib"),
            "scan material.mtl"
        )
    }

    func testReferenceLookupMatchesDirectiveCasingUsedByThirdPartyExporters() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-reference-casing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        try "MTLLIB mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_kd texture.jpg\n".write(to: mtl, atomically: true, encoding: .utf8)

        XCTAssertEqual(try MeshTextReferenceRewriter.firstReference(in: obj, directive: "mtllib"), "mesh.mtl")
        XCTAssertEqual(try MeshTextReferenceRewriter.firstReference(in: mtl, directive: "map_Kd"), "texture.jpg")
    }

    func testWindowsRelativeReferencesAreNormalizedForIOSFileLookup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-reference-windows-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        try "mtllib materials\\scan.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd textures\\base.jpg\n".write(to: mtl, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            try MeshTextReferenceRewriter.firstReference(in: obj, directive: "mtllib"),
            "materials/scan.mtl"
        )
        XCTAssertEqual(
            try MeshTextReferenceRewriter.firstReference(in: mtl, directive: "map_Kd"),
            "textures/base.jpg"
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
