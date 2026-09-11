import XCTest

final class MeshOBJShareBundleTests: XCTestCase {
    func testCopiesMTLAndTextureForTexturedOBJShare() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        try "mtllib mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd atlas.png\n".write(to: mtl, atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4e, 0x47]).write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(Set(companions.map(\.lastPathComponent)), Set(["mesh.mtl", "atlas.png"]))
        XCTAssertEqual(
            try Data(contentsOf: workspace.appendingPathComponent("mesh.mtl")),
            try Data(contentsOf: mtl)
        )
        XCTAssertEqual(
            try Data(contentsOf: workspace.appendingPathComponent("atlas.png")),
            try Data(contentsOf: texture)
        )
    }

    func testConvertedOBJCompanionsAlreadyInWorkspaceAreNotDestroyed() throws {
        let workspace = try makeRoot()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let obj = workspace.appendingPathComponent("converted.obj")
        let mtl = workspace.appendingPathComponent("converted.mtl")
        let texture = workspace.appendingPathComponent("converted.png")
        let mtlData = Data("newmtl scan\nmap_Kd converted.png\n".utf8)
        let textureData = Data([0x89, 0x50, 0x4e, 0x47, 0x01])
        try Data("mtllib converted.mtl\nv 0 0 0\n".utf8).write(to: obj)
        try mtlData.write(to: mtl)
        try textureData.write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(Set(companions.map(\.lastPathComponent)), Set(["converted.mtl", "converted.png"]))
        XCTAssertEqual(try Data(contentsOf: mtl), mtlData)
        XCTAssertEqual(try Data(contentsOf: texture), textureData)
    }

    func testRejectsParentTraversalWithoutCopyingSecret() throws {
        let parent = try makeRoot()
        defer { try? FileManager.default.removeItem(at: parent) }
        let sourceRoot = parent.appendingPathComponent("source", isDirectory: true)
        let workspace = parent.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try "secret".write(
            to: parent.appendingPathComponent("secret.mtl"),
            atomically: true,
            encoding: .utf8
        )
        let obj = sourceRoot.appendingPathComponent("mesh.obj")
        try "mtllib ../secret.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: workspace.path), [])
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("obj-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
