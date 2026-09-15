import XCTest

final class MeshOBJShareBundleHaloTests: XCTestCase {
    func testMapDHaloCopiesAlphaTextureAndCountsItForStorageAdmission() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-share-halo-\(UUID().uuidString)", isDirectory: true)
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let obj = root.appendingPathComponent("mesh.obj")
        let mtl = root.appendingPathComponent("mesh.mtl")
        let alpha = root.appendingPathComponent("alpha mask.png")
        let mtlText = "newmtl scan\nmap_d -halo \"alpha mask.png\"\n"
        let alphaData = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a])

        try "mtllib mesh.mtl\nv 0 0 0\n".write(to: obj, atomically: true, encoding: .utf8)
        try mtlText.write(to: mtl, atomically: true, encoding: .utf8)
        try alphaData.write(to: alpha)

        let companions = try MeshOBJShareBundle.copyCompanions(sourceOBJ: obj, workspace: workspace)
        XCTAssertEqual(Set(companions.map(\.lastPathComponent)), Set(["mesh.mtl", "alpha mask.png"]))
        XCTAssertEqual(try Data(contentsOf: workspace.appendingPathComponent("alpha mask.png")), alphaData)
        XCTAssertEqual(
            try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: obj),
            Int64(Data(mtlText.utf8).count + alphaData.count)
        )
    }
}
