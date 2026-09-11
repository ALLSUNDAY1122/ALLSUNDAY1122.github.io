import XCTest

final class MeshAssetContractDurabilityTests: XCTestCase {
    func testSidecarRoundTripsAndLeavesNoCandidate() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshAssetContractDurability-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let assetURL = root.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: assetURL, options: .atomic)
        let descriptor = try XCTUnwrap(
            MeshAssetContract.descriptor(for: assetURL, source: .lidarSceneReconstruction)
        )

        let sidecarURL = try MeshAssetContract.writeSidecar(for: descriptor)
        let persisted = try Data(contentsOf: sidecarURL)
        let decoded = try JSONDecoder().decode(MeshAssetDescriptor.self, from: persisted)

        XCTAssertEqual(decoded, descriptor)
        let siblings = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertFalse(siblings.contains { $0.lastPathComponent.contains(".candidate-") })
    }

    func testSecondWriteReplacesExistingSidecarWithVerifiedDescriptor() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshAssetContractReplace-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let assetURL = root.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: assetURL, options: .atomic)
        let first = try XCTUnwrap(
            MeshAssetContract.descriptor(for: assetURL, source: .lidarSceneReconstruction)
        )
        let second = try XCTUnwrap(
            MeshAssetContract.descriptor(for: assetURL, source: .refined)
        )

        let sidecarURL = try MeshAssetContract.writeSidecar(for: first)
        XCTAssertEqual(
            try JSONDecoder().decode(MeshAssetDescriptor.self, from: Data(contentsOf: sidecarURL)),
            first
        )

        let replacedURL = try MeshAssetContract.writeSidecar(for: second)
        XCTAssertEqual(replacedURL, sidecarURL)
        XCTAssertEqual(
            try JSONDecoder().decode(MeshAssetDescriptor.self, from: Data(contentsOf: sidecarURL)),
            second
        )
    }

    func testTexturedTrimGenerationRemainsTexturedAndMetric() throws {
        let trimmedURL = URL(fileURLWithPath: "/tmp/mesh-textured-trimmed-1234.obj")
        let descriptor = try XCTUnwrap(MeshAssetContract.descriptor(for: trimmedURL))

        XCTAssertEqual(descriptor.source, .trimmed)
        XCTAssertEqual(descriptor.format, .obj)
        XCTAssertTrue(descriptor.isTextured)
        XCTAssertTrue(descriptor.hasMetricScale)
        XCTAssertEqual(descriptor.linearUnit, "meter")
    }
}