import AssimpBinary
import Foundation
import ModelIO
import XCTest

final class MeshThirdPartyReaderCompatibilityTests: XCTestCase {
    func testExportedMeshFormatsReopenThroughIndependentAssimpImporter() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)

        for format in [
            MeshExportService.Format.obj,
            .fbx,
            .glb,
            .stl,
            .ply,
        ] {
            let output = try await MeshExportService.export(
                sourceURL: source,
                format: format,
                destinationDirectory: root
            )

            let scene: UnsafePointer<aiScene>? = output.path.withCString { path in
                aiImportFile(path, 0)
            }
            guard let scene else {
                let detail = aiGetErrorString().map { String(cString: $0) } ?? "Assimp returned no error detail"
                return XCTFail("Independent Assimp importer could not reopen \(format.rawValue): \(detail)")
            }
            defer { aiReleaseImport(scene) }

            XCTAssertGreaterThan(
                scene.pointee.mNumMeshes,
                0,
                "\(format.rawValue) parsed but contained no mesh/point-cloud payload"
            )
        }
    }

    func testUSDZReopensThroughModelIOWhenAdvertised() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)

        let capability = try XCTUnwrap(
            MeshExportService.capabilities(for: source).first(where: { $0.format == .usdz })
        )
        guard capability.isAvailable else { return }

        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .usdz,
            destinationDirectory: root
        )
        let reopened = MDLAsset(url: output)
        XCTAssertGreaterThan(reopened.count, 0, "USDZ was written but Model I/O could not reopen it")
    }

    private func writeTriangleOBJ(in root: URL) throws -> URL {
        let source = root.appendingPathComponent("third-party-reader-triangle.obj")
        try """
        o Triangle
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vn 0 0 1
        vn 0 0 1
        vn 0 0 1
        f 1//1 2//2 3//3
        """.write(to: source, atomically: true, encoding: .utf8)
        return source
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-third-party-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
