import XCTest

final class MeshExportBridgedPointCloudMemoryTests: XCTestCase {
    private let mib: UInt64 = 1_048_576

    func testNonOBJPointCloudReservesBridgeExpansionBeyondSceneConversion() {
        let sourceBytes: UInt64 = 20 * mib
        let pointCloud = MeshExportMemoryPolicy.estimate(
            sourceBytes: sourceBytes,
            sourceExtension: "glb",
            format: .ply,
            physicalMemoryBytes: 6 * 1_024 * mib
        )
        let scene = MeshExportMemoryPolicy.estimate(
            sourceBytes: sourceBytes,
            sourceExtension: "glb",
            format: .fbx,
            physicalMemoryBytes: 6 * 1_024 * mib
        )

        XCTAssertEqual(pointCloud.estimatedPeakBytes, 24 * sourceBytes + 160 * mib)
        XCTAssertEqual(scene.estimatedPeakBytes, 10 * sourceBytes + 160 * mib)
        XCTAssertGreaterThan(pointCloud.estimatedPeakBytes, scene.estimatedPeakBytes)
    }

    func testBridgedPointCloudRejectsCompactSourceThatCanExpandPastBudget() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-bridged-pointcloud-memory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("compact.glb")
        XCTAssertTrue(FileManager.default.createFile(atPath: source.path, contents: Data([0x67])))
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: 24 * mib)
        try handle.close()

        XCTAssertThrowsError(
            try MeshExportMemoryPolicy.preflight(
                sourceURL: source,
                format: .ply,
                physicalMemoryBytes: 3 * 1_024 * mib
            )
        ) { error in
            guard case MeshExportMemoryPolicy.PolicyError.conversionTooLarge = error else {
                return XCTFail("Expected conversionTooLarge, got \(error)")
            }
        }
    }
}
