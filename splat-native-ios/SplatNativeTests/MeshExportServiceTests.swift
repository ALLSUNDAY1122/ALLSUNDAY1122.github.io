import ModelIO
import XCTest

final class MeshExportServiceTests: XCTestCase {
    func testPinnedAssimpBuildContainsRequiredRealExporters() {
        let exporterIDs = MeshExportService.assimpExporterIDs()
        XCTAssertTrue(exporterIDs.contains("obj"))
        XCTAssertTrue(exporterIDs.contains("stlb"))
        XCTAssertTrue(exporterIDs.contains("glb2"))
        XCTAssertTrue(exporterIDs.contains("fbx"))
    }

    func testOBJPassthroughKeepsRealGeometryBytes() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)

        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .obj,
            destinationDirectory: root
        )

        XCTAssertEqual(output.pathExtension, "obj")
        XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: source))
    }

    func testOBJExportsAllSevenRealScaniverseMeshFormats() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)

        let capabilities = Dictionary(
            uniqueKeysWithValues: MeshExportService.capabilities(for: source).map { ($0.format, $0) }
        )
        for format in MeshExportService.Format.allCases where format != .usdz {
            XCTAssertEqual(capabilities[format]?.isAvailable, true, "Expected \(format.rawValue) to be available")
        }

        let fbx = try await MeshExportService.export(sourceURL: source, format: .fbx, destinationDirectory: root)
        let glb = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
        let stl = try await MeshExportService.export(sourceURL: source, format: .stl, destinationDirectory: root)
        let ply = try await MeshExportService.export(sourceURL: source, format: .ply, destinationDirectory: root)
        let las = try await MeshExportService.export(sourceURL: source, format: .las, destinationDirectory: root)

        XCTAssertGreaterThan(try byteCount(fbx), 100)
        XCTAssertGreaterThan(try byteCount(glb), 100)
        XCTAssertGreaterThan(try byteCount(stl), 84)
        XCTAssertGreaterThan(try byteCount(ply), 100)
        XCTAssertEqual(try byteCount(las), 227 + 3 * 20)

        let fbxPrefix = String(decoding: try Data(contentsOf: fbx).prefix(32), as: UTF8.self)
        XCTAssertTrue(fbxPrefix.contains("Kaydara FBX Binary"))

        let glbBytes = Array(try Data(contentsOf: glb).prefix(12))
        XCTAssertGreaterThanOrEqual(glbBytes.count, 12)
        XCTAssertEqual(Array(glbBytes.prefix(4)), [0x67, 0x6c, 0x54, 0x46])
        XCTAssertEqual(glbBytes[4], 0x02)
        XCTAssertEqual(glbBytes[5], 0x00)
        XCTAssertEqual(glbBytes[6], 0x00)
        XCTAssertEqual(glbBytes[7], 0x00)

        if MDLAsset.canImportFileExtension("stl") {
            let decodedSTL = MDLAsset(url: stl)
            XCTAssertGreaterThan(decodedSTL.count, 0)
        }

        let plyData = try Data(contentsOf: ply)
        let plyPrefix = String(decoding: plyData.prefix(min(512, plyData.count)), as: UTF8.self)
        XCTAssertTrue(plyPrefix.hasPrefix("ply\n"))
        XCTAssertTrue(plyPrefix.contains("format binary_little_endian 1.0"))
        XCTAssertTrue(plyPrefix.contains("element vertex 3"))
        XCTAssertTrue(plyPrefix.contains("element face 1"))

        let lasData = try Data(contentsOf: las)
        XCTAssertEqual(Array(lasData.prefix(4)), [0x4c, 0x41, 0x53, 0x46])
        XCTAssertEqual(lasData[24], 1)
        XCTAssertEqual(lasData[25], 2)
        XCTAssertEqual(lasData[104], 0) // no fabricated RGB when the OBJ has none
        XCTAssertEqual(readUInt16LE(lasData, 105), 20)
        XCTAssertEqual(readUInt32LE(lasData, 107), 3)
    }

    func testVertexColorsArePreservedInPLYAndLASInsteadOfInvented() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("colored.obj")
        let obj = """
        v 0 0 0 1 0 0
        v 1 0 0 0 1 0
        v 0 1 0 0 0 1
        f 1 2 3
        """
        try obj.write(to: source, atomically: true, encoding: .utf8)

        let ply = try await MeshExportService.export(sourceURL: source, format: .ply, destinationDirectory: root)
        let las = try await MeshExportService.export(sourceURL: source, format: .las, destinationDirectory: root)

        let plyData = try Data(contentsOf: ply)
        let plyPrefix = String(decoding: plyData.prefix(min(512, plyData.count)), as: UTF8.self)
        XCTAssertTrue(plyPrefix.contains("property uchar red"))
        XCTAssertTrue(plyPrefix.contains("property uchar green"))
        XCTAssertTrue(plyPrefix.contains("property uchar blue"))

        let lasData = try Data(contentsOf: las)
        XCTAssertEqual(lasData[104], 2)
        XCTAssertEqual(readUInt16LE(lasData, 105), 26)
        XCTAssertEqual(readUInt32LE(lasData, 107), 3)

        let firstPoint = 227
        XCTAssertEqual(readUInt16LE(lasData, firstPoint + 20), UInt16.max)
        XCTAssertEqual(readUInt16LE(lasData, firstPoint + 22), 0)
        XCTAssertEqual(readUInt16LE(lasData, firstPoint + 24), 0)
    }

    func testUSDZExportIsOnlyAdvertisedWhenModelIOCanActuallyProduceIt() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)
        let capability = try XCTUnwrap(
            MeshExportService.capabilities(for: source).first(where: { $0.format == .usdz })
        )
        let expected = MDLAsset.canImportFileExtension("obj") && MDLAsset.canExportFileExtension("usdz")
        XCTAssertEqual(capability.isAvailable, expected)

        guard capability.isAvailable else { return }
        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .usdz,
            destinationDirectory: root
        )
        XCTAssertEqual(output.pathExtension, "usdz")
        let prefix = Array(try Data(contentsOf: output).prefix(2))
        XCTAssertEqual(prefix, [0x50, 0x4b])
        XCTAssertGreaterThan(try byteCount(output), 100)
    }

    func testUnknownSourceDoesNotAdvertiseExtensionOnlyConversions() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("mesh.unknown3d")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: source)

        let capabilities = MeshExportService.capabilities(for: source)
        for capability in capabilities {
            XCTAssertFalse(capability.isAvailable)
            XCTAssertNotNil(capability.reason)
        }
    }

    private func writeTriangleOBJ(in root: URL) throws -> URL {
        let source = root.appendingPathComponent("mesh.obj")
        let obj = """
        # minimal triangle
        o Triangle
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vn 0 0 1
        vn 0 0 1
        vn 0 0 1
        f 1//1 2//2 3//3
        """
        try obj.write(to: source, atomically: true, encoding: .utf8)
        return source
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-mesh-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func byteCount(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.size] as? NSNumber).intValue
    }

    private func readUInt16LE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            (UInt32(data[offset + 1]) << 8) |
            (UInt32(data[offset + 2]) << 16) |
            (UInt32(data[offset + 3]) << 24)
    }
}
