import XCTest

final class MeshExportConvertedCompanionAdmissionTests: XCTestCase {
    func testConvertedScenePreflightCountsReferencedOBJCompanionBytes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-converted-companion-admission-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("mesh.obj")
        let material = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        try "mtllib mesh.mtl\nv 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"
            .write(to: source, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd atlas.png\n"
            .write(to: material, atomically: true, encoding: .utf8)
        try Data(repeating: 0x7a, count: 8 * 1_024 * 1_024).write(to: texture)

        let sourceBytes = Int64((try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.int64Value ?? 0)
        let companionBytes = try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: source)
        let baseRequired = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .glb
        )

        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .glb,
                availableCapacityOverride: baseRequired + companionBytes - 1
            )
        ) { error in
            guard case MeshExportAdmission.AdmissionError.insufficientStorage(let required, let available) = error else {
                return XCTFail("Expected insufficientStorage, got \(error)")
            }
            XCTAssertEqual(required, baseRequired + companionBytes)
            XCTAssertEqual(available, baseRequired + companionBytes - 1)
        }

        XCTAssertNoThrow(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .glb,
                availableCapacityOverride: baseRequired + companionBytes
            )
        )
    }
}
