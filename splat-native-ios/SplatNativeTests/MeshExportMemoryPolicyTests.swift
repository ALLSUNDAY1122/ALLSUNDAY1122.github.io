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
            sourceBytes: 72 * mib,
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

    func testPreflightRejectsOversizedConversionForConstrainedDevice() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-mesh-memory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("large.obj")
        let handle = FileManager.default.createFile(atPath: source.path, contents: Data("v 0 0 0\n".utf8))
        XCTAssertTrue(handle)
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
}
