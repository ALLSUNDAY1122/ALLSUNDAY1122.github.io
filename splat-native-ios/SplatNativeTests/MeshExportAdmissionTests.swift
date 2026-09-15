import XCTest

final class MeshExportAdmissionTests: XCTestCase {
    func testExactFormatPassthroughNeedsLessDiskThanConvertedPointCloud() {
        let sourceBytes: Int64 = 80 * 1_024 * 1_024
        let passthrough = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .obj
        )
        let pointCloud = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .ply
        )

        XCTAssertGreaterThan(passthrough, sourceBytes)
        XCTAssertGreaterThan(pointCloud, passthrough)
    }

    func testEstimateSaturatesInsteadOfOverflowing() {
        let required = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: Int64.max,
            sourceExtension: "obj",
            format: .las
        )
        XCTAssertEqual(required, Int64.max)
    }

    func testPreflightRejectsBeforeWorkspaceWhenFreeSpaceIsInsufficient() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-low-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("mesh.obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n".write(
            to: source,
            atomically: true,
            encoding: .utf8
        )

        do {
            _ = try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .glb,
                availableCapacityOverride: 0
            )
            XCTFail("Expected low-storage rejection")
        } catch let error as MeshExportAdmission.AdmissionError {
            guard case .insufficientStorage(let required, let available) = error else {
                return XCTFail("Expected insufficientStorage, got \(error)")
            }
            XCTAssertGreaterThan(required, 0)
            XCTAssertEqual(available, 0)
        }

        let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertEqual(children.map(\.lastPathComponent), ["mesh.obj"])
    }
}
