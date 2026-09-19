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

    func testPointCloudEstimateReservesTwelveTimesSourceBeforeSafetyMargin() {
        let mib: Int64 = 1_024 * 1_024
        let sourceBytes: Int64 = 10 * mib
        let required = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .las
        )

        XCTAssertEqual(required, 12 * sourceBytes + 128 * mib)
    }

    func testBridgedPointCloudEstimateReservesForIntermediateOBJExpansion() {
        let mib: Int64 = 1_024 * 1_024
        let sourceBytes: Int64 = 10 * mib
        let bridged = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "glb",
            format: .ply
        )
        let directOBJ = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .ply
        )

        XCTAssertEqual(bridged, 24 * sourceBytes + 128 * mib)
        XCTAssertGreaterThan(bridged, directOBJ)
    }

    func testBridgedMeshEstimateReservesForIntermediateOBJ() {
        let mib: Int64 = 1_024 * 1_024
        let sourceBytes: Int64 = 10 * mib
        let bridged = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "usdz",
            format: .glb
        )
        let directOBJ = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .glb
        )
        let directUSDZ = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "glb",
            format: .usdz
        )

        XCTAssertEqual(bridged, 8 * sourceBytes + 128 * mib)
        XCTAssertEqual(directOBJ, 3 * sourceBytes + 128 * mib)
        XCTAssertEqual(directUSDZ, 3 * sourceBytes + 128 * mib)
    }

    func testEstimateSaturatesInsteadOfOverflowing() {
        let required = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: Int64.max,
            sourceExtension: "obj",
            format: .las
        )
        XCTAssertEqual(required, Int64.max)
    }

    func testPreflightCountsReferencedOBJMaterialAndTextureBytes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-obj-companions-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("mesh.obj")
        let material = root.appendingPathComponent("mesh.mtl")
        let texture = root.appendingPathComponent("atlas.png")
        try "mtllib mesh.mtl\nv 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"
            .write(to: source, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd atlas.png\n"
            .write(to: material, atomically: true, encoding: .utf8)
        try Data(repeating: 0x7a, count: 4_096).write(to: texture)

        let sourceBytes = Int64((try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.int64Value ?? 0)
        let companionBytes = try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: source)
        XCTAssertGreaterThan(companionBytes, 4_096)

        let baseRequired = MeshExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: "obj",
            format: .obj
        )
        let insufficientByOne = baseRequired + companionBytes - 1

        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .obj,
                availableCapacityOverride: insufficientByOne
            )
        ) { error in
            guard case MeshExportAdmission.AdmissionError.insufficientStorage(let required, let available) = error else {
                return XCTFail("Expected insufficientStorage, got \(error)")
            }
            XCTAssertEqual(required, baseRequired + companionBytes)
            XCTAssertEqual(available, insufficientByOne)
        }

        XCTAssertNoThrow(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .obj,
                availableCapacityOverride: baseRequired + companionBytes
            )
        )
    }

    func testPointCloudPreflightAllowsMissingTextureGeometryFallback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-pointcloud-missing-texture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("mesh.obj")
        let material = root.appendingPathComponent("mesh.mtl")
        try "mtllib mesh.mtl\nv 0 0 0\nv 1 0 0\nv 0 1 0\nvt 0 0\nvt 1 0\nvt 0 1\nusemtl scan\nf 1/1 2/2 3/3\n"
            .write(to: source, atomically: true, encoding: .utf8)
        try "newmtl scan\nmap_Kd missing.png\n"
            .write(to: material, atomically: true, encoding: .utf8)

        XCTAssertNoThrow(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .ply,
                availableCapacityOverride: Int64.max
            )
        )
        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .glb,
                availableCapacityOverride: Int64.max
            )
        ) { error in
            guard case MeshOBJShareBundle.BundleError.missingReference(let reference) = error else {
                return XCTFail("Expected missingReference for strict scene export, got \(error)")
            }
            XCTAssertEqual(reference, "missing.png")
        }
    }

    func testPreflightRejectsUnsafeOBJCompanionBeforeConvertedExport() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-obj-conversion-containment-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let source = root.appendingPathComponent("mesh.obj")
        let externalMaterial = parent.appendingPathComponent("outside.mtl")
        try "mtllib ../outside.mtl\nv 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"
            .write(to: source, atomically: true, encoding: .utf8)
        try "newmtl external\n".write(to: externalMaterial, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .glb,
                availableCapacityOverride: Int64.max
            )
        ) { error in
            guard case MeshOBJShareBundle.BundleError.unsafeReference(let reference) = error else {
                return XCTFail("Expected unsafeReference, got \(error)")
            }
            XCTAssertEqual(reference, "../outside.mtl")
        }
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
        XCTAssertEqual(children.map(\.lastPathComponent).sorted(), ["mesh.obj"])
    }

    func testPreflightFailsClosedWhenCapacityCannotBeRead() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-unknown-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("mesh.obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"
            .write(to: source, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .glb,
                capacityProvider: { _ in nil }
            )
        ) { error in
            guard case MeshExportAdmission.AdmissionError.storageCapacityUnavailable = error else {
                return XCTFail("Expected storageCapacityUnavailable, got \(error)")
            }
        }
    }

    func testPreflightRejectsDirectoryMasqueradingAsMeshFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-nonregular-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("fake.obj", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .obj,
                availableCapacityOverride: Int64.max
            )
        ) { error in
            guard case MeshExportAdmission.AdmissionError.sourceSizeUnavailable = error else {
                return XCTFail("Expected sourceSizeUnavailable, got \(error)")
            }
        }
    }
}
