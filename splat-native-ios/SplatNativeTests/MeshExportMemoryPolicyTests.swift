import XCTest

final class MeshExportMemoryPolicyTests: XCTestCase {
    private let mib: UInt64 = 1_048_576

    func testExactFormatPassthroughDoesNotScaleMemoryWithAssetSize() {
        let estimate = MeshExportMemoryPolicy.estimate(
            sourceBytes: 600 * mib,
            sourceExtension: "obj",
            format: .obj,
            physicalMemoryBytes: 4 * 1_024 * mib
        )

        XCTAssertEqual(estimate.estimatedPeakBytes, 32 * mib)
        XCTAssertLessThan(estimate.estimatedPeakBytes, estimate.budgetBytes)
    }

    func testOBJPointCloudExpansionIsBudgetedMoreConservatively() {
        let small = MeshExportMemoryPolicy.estimate(
            sourceBytes: 24 * mib,
            sourceExtension: "obj",
            format: .ply,
            physicalMemoryBytes: 4 * 1_024 * mib
        )
        let large = MeshExportMemoryPolicy.estimate(
            sourceBytes: 80 * mib,
            sourceExtension: "obj",
            format: .ply,
            physicalMemoryBytes: 4 * 1_024 * mib
        )

        XCTAssertGreaterThan(large.estimatedPeakBytes, small.estimatedPeakBytes)
        XCTAssertLessThanOrEqual(small.estimatedPeakBytes, small.budgetBytes)
        XCTAssertGreaterThan(large.estimatedPeakBytes, large.budgetBytes)
    }

    func testNonOBJBridgeReservesMoreMemoryThanDirectOBJConversion() {
        let obj = MeshExportMemoryPolicy.estimate(
            sourceBytes: 40 * mib,
            sourceExtension: "obj",
            format: .glb,
            physicalMemoryBytes: 6 * 1_024 * mib
        )
        let usdzSource = MeshExportMemoryPolicy.estimate(
            sourceBytes: 40 * mib,
            sourceExtension: "usdz",
            format: .glb,
            physicalMemoryBytes: 6 * 1_024 * mib
        )

        XCTAssertGreaterThan(usdzSource.estimatedPeakBytes, obj.estimatedPeakBytes)
    }

    func testSaturatedEstimateCanBeReportedWithoutOverflow() {
        let estimate = MeshExportMemoryPolicy.estimate(
            sourceBytes: UInt64.max,
            sourceExtension: "obj",
            format: .ply,
            physicalMemoryBytes: 3 * 1_024 * mib
        )

        XCTAssertEqual(estimate.estimatedPeakBytes, UInt64.max)
        XCTAssertGreaterThan(estimate.estimatedPeakMegabytes, 0)
        XCTAssertLessThanOrEqual(estimate.budgetMegabytes, 768)
    }

    func testPreflightRejectsOversizedConversionForConstrainedDevice() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("large.obj")
        let created = FileManager.default.createFile(atPath: source.path, contents: Data("v 0 0 0\n".utf8))
        XCTAssertTrue(created)
        let fileHandle = try FileHandle(forWritingTo: source)
        try fileHandle.truncate(atOffset: 80 * mib)
        try fileHandle.close()

        XCTAssertThrowsError(
            try MeshExportMemoryPolicy.preflight(
                sourceURL: source,
                format: .glb,
                physicalMemoryBytes: 3 * 1_024 * mib
            )
        ) { error in
            guard case MeshExportMemoryPolicy.PolicyError.conversionTooLarge = error else {
                return XCTFail("Expected conversionTooLarge, got \(error)")
            }
        }
    }

    func testPreflightIncludesOBJCompanionTextureWorkingSetForSceneConversion() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-companion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("capture.obj")
        try """
        mtllib capture.mtl
        v 0 0 0
        v 1 0 0
        v 0 1 0
        f 1 2 3
        """.write(to: source, atomically: true, encoding: .utf8)
        try "map_Kd atlas.jpg\n"
            .write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)

        let texture = root.appendingPathComponent("atlas.jpg")
        XCTAssertTrue(FileManager.default.createFile(atPath: texture.path, contents: Data([0xff])))
        let textureHandle = try FileHandle(forWritingTo: texture)
        try textureHandle.truncate(atOffset: 100 * mib)
        try textureHandle.close()

        XCTAssertThrowsError(
            try MeshExportMemoryPolicy.preflight(
                sourceURL: source,
                format: .glb,
                physicalMemoryBytes: 3 * 1_024 * mib
            )
        ) { error in
            guard case MeshExportMemoryPolicy.PolicyError.conversionTooLarge = error else {
                return XCTFail("Expected companion-aware conversionTooLarge, got \(error)")
            }
        }
    }

    func testPointCloudAdmissionDoesNotScaleWithTotalCompanionTextureBytes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-pointcloud-bounded-textures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("capture.obj")
        try """
        mtllib capture.mtl
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vt 0 0
        vt 1 0
        vt 0 1
        usemtl capture
        f 1/1 2/2 3/3
        """.write(to: source, atomically: true, encoding: .utf8)
        try """
        newmtl capture
        map_Kd atlas.jpg
        """.write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)

        let texture = root.appendingPathComponent("atlas.jpg")
        XCTAssertTrue(FileManager.default.createFile(atPath: texture.path, contents: Data([0xff])))
        let textureHandle = try FileHandle(forWritingTo: texture)
        try textureHandle.truncate(atOffset: 100 * mib)
        try textureHandle.close()

        let estimate = try MeshExportMemoryPolicy.preflight(
            sourceURL: source,
            format: .ply,
            physicalMemoryBytes: 3 * 1_024 * mib
        )
        XCTAssertLessThan(estimate.estimatedPeakBytes, estimate.budgetBytes)
        XCTAssertGreaterThanOrEqual(estimate.estimatedPeakBytes, 160 * mib)
    }

    func testPointCloudPreflightKeepsGeometryFallbackWhenTextureIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-pointcloud-missing-texture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("capture.obj")
        try """
        mtllib capture.mtl
        v 0 0 0
        v 1 0 0
        v 0 1 0
        vt 0 0
        vt 1 0
        vt 0 1
        usemtl capture
        f 1/1 2/2 3/3
        """.write(to: source, atomically: true, encoding: .utf8)
        try """
        newmtl capture
        map_Kd missing-atlas.jpg
        """.write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)

        XCTAssertNoThrow(
            try MeshExportMemoryPolicy.preflight(
                sourceURL: source,
                format: .ply,
                physicalMemoryBytes: 3 * 1_024 * mib
            )
        )
    }

    func testExactOBJPassthroughDoesNotDecodeCompanionWorkingSet() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-companion-passthrough-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("capture.obj")
        try """
        mtllib capture.mtl
        v 0 0 0
        v 1 0 0
        v 0 1 0
        f 1 2 3
        """.write(to: source, atomically: true, encoding: .utf8)
        try "map_Kd atlas.jpg\n"
            .write(to: root.appendingPathComponent("capture.mtl"), atomically: true, encoding: .utf8)

        let texture = root.appendingPathComponent("atlas.jpg")
        XCTAssertTrue(FileManager.default.createFile(atPath: texture.path, contents: Data([0xff])))
        let textureHandle = try FileHandle(forWritingTo: texture)
        try textureHandle.truncate(atOffset: 100 * mib)
        try textureHandle.close()

        let estimate = try MeshExportMemoryPolicy.preflight(
            sourceURL: source,
            format: .obj,
            physicalMemoryBytes: 3 * 1_024 * mib
        )
        XCTAssertEqual(estimate.estimatedPeakBytes, 32 * mib)
    }

    func testPreflightRejectsDirectoryMasqueradingAsMeshFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-nonregular-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("fake.obj", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try MeshExportMemoryPolicy.preflight(
                sourceURL: source,
                format: .obj,
                physicalMemoryBytes: 4 * 1_024 * mib
            )
        ) { error in
            guard case MeshExportMemoryPolicy.PolicyError.sourceSizeUnavailable = error else {
                return XCTFail("Expected sourceSizeUnavailable, got \(error)")
            }
        }
    }
}
