import ModelIO
import XCTest

final class MeshExportServiceTests: XCTestCase {
    func testOBJPassthroughKeepsRealGeometryBytes() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("mesh.obj")
        let obj = """
        # minimal triangle
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vn 0 0 1
        vn 0 0 1
        vn 0 0 1
        f 1//1 2//2 3//3
        """
        try obj.write(to: source, atomically: true, encoding: .utf8)

        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .obj,
            destinationDirectory: root
        )

        XCTAssertEqual(output.pathExtension, "obj")
        XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: source))
    }

    func testOBJToSTLIsOnlyAdvertisedWhenRuntimeCanExportIt() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("mesh.obj")
        let obj = """
        v 0 0 0
        v 1 0 0
        v 0 1 0
        f 1 2 3
        """
        try obj.write(to: source, atomically: true, encoding: .utf8)

        let capability = try XCTUnwrap(
            MeshExportService.capabilities(for: source).first(where: { $0.format == .stl })
        )
        XCTAssertEqual(capability.isAvailable, MDLAsset.canExportFileExtension("stl"))

        guard capability.isAvailable else { return }
        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .stl,
            destinationDirectory: root
        )
        XCTAssertEqual(output.pathExtension, "stl")
        XCTAssertGreaterThan(try byteCount(output), 0)
        XCTAssertTrue(MDLAsset.canImportFileExtension("stl"))
        let decoded = MDLAsset(url: output)
        XCTAssertGreaterThan(decoded.count, 0)
    }

    func testUnavailableFormatsAreNotFalselyAdvertised() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("mesh.obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n".write(
            to: source,
            atomically: true,
            encoding: .utf8
        )

        let capabilities = MeshExportService.capabilities(for: source)
        for capability in capabilities where capability.format != .obj {
            XCTAssertEqual(
                capability.isAvailable,
                MDLAsset.canImportFileExtension("obj") &&
                    MDLAsset.canExportFileExtension(capability.format.rawValue)
            )
            if !capability.isAvailable {
                XCTAssertNotNil(capability.reason)
            }
        }
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
}
