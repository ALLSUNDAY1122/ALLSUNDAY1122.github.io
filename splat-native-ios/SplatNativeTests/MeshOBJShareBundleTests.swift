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

    func testCopiesLowercaseMaterialAndTextureCommands() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        try "MTLLIB mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_kd atlas.png\n".write(to: mtl, atomically: true, encoding: .utf8)
        let textureData = Data([0x89, 0x50, 0x4e, 0x47, 0x08])
        try textureData.write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(Set(companions.map(\.lastPathComponent)), Set(["mesh.mtl", "atlas.png"]))
        XCTAssertEqual(try Data(contentsOf: workspace.appendingPathComponent("atlas.png")), textureData)
    }

    func testCopiesMaterialAndTextureWhenMtllibUsesTabs() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        let materialText = "newmtl scan\nmap_Kd atlas.png\n"
        let textureData = Data([0x89, 0x50, 0x4e, 0x47, 0x0a])
        try "mtllib\tmesh.mtl\t# exported material\nv 0 0 0\n"
            .write(to: obj, atomically: true, encoding: .utf8)
        try materialText.write(to: mtl, atomically: true, encoding: .utf8)
        try textureData.write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(Set(companions.map(\.lastPathComponent)), Set(["mesh.mtl", "atlas.png"]))
        XCTAssertEqual(try Data(contentsOf: workspace.appendingPathComponent("atlas.png")), textureData)

        let expectedCompanionBytes = Int64(Data(materialText.utf8).count + textureData.count)
        XCTAssertEqual(
            try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: obj),
            expectedCompanionBytes,
            "Storage admission must count the same tab-separated companions that exact sharing copies"
        )
    }

    func testStreamingScanKeepsMtllibAcrossReadChunkBoundary() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        let prefix = String(repeating: "# filler\n", count: 7_280)
        try (prefix + "mtllib mesh.mtl\nv 0 0 0\n")
            .write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd atlas.png\n".write(to: mtl, atomically: true, encoding: .utf8)
        let textureData = Data([0x89, 0x50, 0x4e, 0x47, 0x55])
        try textureData.write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(Set(companions.map(\.lastPathComponent)), Set(["mesh.mtl", "atlas.png"]))
        XCTAssertEqual(try Data(contentsOf: workspace.appendingPathComponent("atlas.png")), textureData)
    }

    func testCancelledTaskDoesNotStartCompanionCopy() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        try "mtllib mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\n".write(to: mtl, atomically: true, encoding: .utf8)

        let error: Error? = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
                return nil
            } catch {
                return error
            }
        }.value

        XCTAssertTrue(error is CancellationError)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: workspace.path), [])
    }

    func testDeduplicatesRepeatedMaterialAndTextureReferences() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        try "mtllib mesh.mtl mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl one\nmap_Kd atlas.png\nnewmtl two\nmap_Kd atlas.png\n"
            .write(to: mtl, atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4e, 0x47, 0x09]).write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(companions.map(\.lastPathComponent), ["mesh.mtl", "atlas.png"])
    }

    func testCopiesQuotedMaterialAndOptionedTextureWithSpaces() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let textures = root.appendingPathComponent("textures", isDirectory: true)
        try FileManager.default.createDirectory(at: textures, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("scan material.mtl")
        let texture = textures.appendingPathComponent("base color.png")
        try "mtllib \"scan material.mtl\" # exported material\nv 0 0 0\n"
            .write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd -s 1 1 1 \"textures/base color.png\" # albedo\n"
            .write(to: mtl, atomically: true, encoding: .utf8)
        let textureData = Data([0x89, 0x50, 0x4e, 0x47, 0x02])
        try textureData.write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(
            Set(companions.map { $0.path.replacingOccurrences(of: workspace.path + "/", with: "") }),
            Set(["scan material.mtl", "textures/base color.png"])
        )
        XCTAssertEqual(
            try Data(contentsOf: workspace.appendingPathComponent("textures/base color.png")),
            textureData
        )
    }

    func testCopiesWindowsStyleRelativeMaterialAndTexturePaths() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let materials = root.appendingPathComponent("materials", isDirectory: true)
        let textures = root.appendingPathComponent("textures", isDirectory: true)
        try FileManager.default.createDirectory(at: materials, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: textures, withIntermediateDirectories: true)

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = materials.appendingPathComponent("scan.mtl")
        let texture = textures.appendingPathComponent("base.png")
        try "mtllib materials\\scan.mtl\nv 0 0 0\n"
            .write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd ..\\textures\\base.png\n"
            .write(to: mtl, atomically: true, encoding: .utf8)
        let textureData = Data([0x89, 0x50, 0x4e, 0x47, 0x03])
        try textureData.write(to: texture)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(
            Set(companions.map { $0.path.replacingOccurrences(of: workspace.path + "/", with: "") }),
            Set(["materials/scan.mtl", "textures/base.png"])
        )
        XCTAssertEqual(
            try Data(contentsOf: workspace.appendingPathComponent("textures/base.png")),
            textureData
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

    func testAllowsSymlinkOnlyAboveProjectRoot() throws {
        let parent = try makeRoot()
        defer { try? FileManager.default.removeItem(at: parent) }
        let realRoot = parent.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
        let alias = parent.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: realRoot)
        let workspace = parent.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let obj = alias.appendingPathComponent("mesh.obj")
        let mtl = alias.appendingPathComponent("mesh.mtl")
        try "mtllib mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try "newmtl scan\n".write(to: mtl, atomically: true, encoding: .utf8)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(companions.map(\.lastPathComponent), ["mesh.mtl"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("mesh.mtl").path))
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

    func testRejectsWindowsAbsoluteMaterialPathWithoutCopying() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let obj = root.appendingPathComponent("mesh.obj")
        try "mtllib C:\\outside\\secret.mtl\nv 0 0 0\n"
            .write(to: obj, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: workspace.path), [])
    }

    func testRejectsSymlinkEscapeWithoutCopyingExternalMaterial() throws {
        let parent = try makeRoot()
        defer { try? FileManager.default.removeItem(at: parent) }
        let sourceRoot = parent.appendingPathComponent("source", isDirectory: true)
        let workspace = parent.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let external = parent.appendingPathComponent("external.mtl")
        try "newmtl secret\n".write(to: external, atomically: true, encoding: .utf8)
        let link = sourceRoot.appendingPathComponent("linked.mtl")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
        let obj = sourceRoot.appendingPathComponent("mesh.obj")
        try "mtllib linked.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)

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
