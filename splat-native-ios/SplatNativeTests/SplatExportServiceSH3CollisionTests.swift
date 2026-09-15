import XCTest
import SplatIO
import simd

extension SplatExportServiceTests {
    func testCanonicalSH3NeverOverwritesDifferentHigherOrderDataForSameLegacyFingerprint() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s7-sh3-collision-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // The legacy fingerprint intentionally cannot distinguish SH1-3 because `.splat` does not
        // serialize them. Keep these bytes fixed while constructing two different SH3 candidates.
        let legacy = root.appendingPathComponent("result.pending.splat")
        try Data(repeating: 0x2a, count: 32).write(to: legacy, options: .atomic)
        let target = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: legacy)

        let original = makeCollisionPoint(higherOrderScale: 1)
        let replacement = makeCollisionPoint(higherOrderScale: -1)
        try await writeSH3PLY([original], to: target)
        let originalHash = try SplatExportService.sha256Hex(fileURL: target)

        let candidate = root.appendingPathComponent("candidate.ply")
        try await writeSH3PLY([replacement], to: candidate)
        XCTAssertNotEqual(
            try SplatExportService.sha256Hex(fileURL: candidate),
            originalHash,
            "Fixture must differ only in the lossless canonical payload"
        )

        XCTAssertThrowsError(
            try SplatCanonicalSHAsset.installCollisionSafeTemporaryPLY(
                candidate,
                targetURL: target,
                expectedPointCount: 1
            )
        ) { error in
            guard case SplatCanonicalSHAsset.DurabilityError.lossyFingerprintCollision = error else {
                return XCTFail("Expected lossyFingerprintCollision, got \(error)")
            }
        }

        XCTAssertEqual(try SplatExportService.sha256Hex(fileURL: target), originalHash)
        let decoded = try await AutodetectSceneReader(target).readAll()
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].color.shDegree, .sh3)
        XCTAssertEqual(decoded[0].color.higherOrderSHCoefficients.count, 45)
        XCTAssertGreaterThan(decoded[0].color.higherOrderSHCoefficients[0], 0)
    }

    func testIdenticalCanonicalSH3PayloadIsSafelyReused() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s7-sh3-reuse-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("result.pending.splat")
        try Data(repeating: 0x19, count: 32).write(to: legacy, options: .atomic)
        let target = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: legacy)
        let point = makeCollisionPoint(higherOrderScale: 0.5)
        try await writeSH3PLY([point], to: target)
        let originalHash = try SplatExportService.sha256Hex(fileURL: target)

        let candidate = root.appendingPathComponent("candidate-identical.ply")
        try await writeSH3PLY([point], to: candidate)
        let asset = try SplatCanonicalSHAsset.installCollisionSafeTemporaryPLY(
            candidate,
            targetURL: target,
            expectedPointCount: 1
        )

        XCTAssertEqual(asset.url, target)
        XCTAssertEqual(asset.descriptor.shDegree, 3)
        XCTAssertEqual(try SplatExportService.sha256Hex(fileURL: target), originalHash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidate.path))
    }

    private func makeCollisionPoint(higherOrderScale: Float) -> SplatPoint {
        var coefficients: [SIMD3<Float>] = [SIMD3<Float>(0.15, -0.08, 0.05)]
        for index in 1..<16 {
            let value = Float(index) * 0.004 * higherOrderScale
            coefficients.append(SIMD3<Float>(value, value * 0.6, -value * 0.3))
        }
        return SplatPoint(
            position: SIMD3<Float>(0.1, -0.2, 0.6),
            color: .sphericalHarmonicFloat(coefficients),
            opacity: .linearFloat(0.8),
            scale: .linearFloat(SIMD3<Float>(0.02, 0.025, 0.03)),
            rotation: simd_quatf(angle: 0.12, axis: SIMD3<Float>(0, 1, 0))
        )
    }

    private func writeSH3PLY(_ points: [SplatPoint], to url: URL) async throws {
        let writer = try SplatPLYSceneWriter(toFileAtPath: url.path)
        try await writer.start(sphericalHarmonicDegree: 3, binary: true, pointCount: points.count)
        try await writer.write(points)
        try await writer.close()
    }
}
