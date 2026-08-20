import AssimpBinary
import Foundation
import ModelIO
import XCTest

final class MeshThirdPartyReaderCompatibilityTests: XCTestCase {
    func testOBJReopensThroughAssimp() async throws {
        try await assertAssimpCanReopen(.obj)
    }

    /// The pinned iOS Assimp binary exposes the FBX exporter but does not include an FBX importer.
    /// Stream the real exported FBX bytes through XCTest stdout so the macOS host-side Assimp CLI in
    /// `scripts/run_mesh_reader_compat_test.sh` can independently reopen exactly what the app emitted.
    /// This avoids depending on CoreSimulator's private host/container path mapping.
    func testFBXReopensThroughAssimp() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)
        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .fbx,
            destinationDirectory: root
        )

        let payload = try Data(contentsOf: output)
        XCTAssertGreaterThan(payload.count, 100, "FBX exporter produced no useful payload for host reader")
        print("SCANLAB_HOST_FBX_BASE64=\(payload.base64EncodedString())")
    }

    func testGLBReopensThroughAssimp() async throws {
        try await assertAssimpCanReopen(.glb)
    }

    func testSTLReopensThroughAssimp() async throws {
        try await assertAssimpCanReopen(.stl)
    }

    func testPLYReopensThroughAssimp() async throws {
        try await assertAssimpCanReopen(.ply)
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

    private func assertAssimpCanReopen(_ format: MeshExportService.Format) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try writeTriangleOBJ(in: root)
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
            return XCTFail("Assimp could not reopen \(format.rawValue): \(detail)")
        }
        defer { aiReleaseImport(scene) }

        XCTAssertGreaterThan(
            scene.pointee.mNumMeshes,
            0,
            "\(format.rawValue) parsed but contained no mesh/point-cloud payload"
        )
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
