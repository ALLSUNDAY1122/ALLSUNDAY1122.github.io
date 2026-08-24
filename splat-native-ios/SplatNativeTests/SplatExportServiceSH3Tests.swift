import XCTest
import SplatIO
import simd

extension SplatExportServiceTests {
    /// This method intentionally extends the existing SplatExportServiceTests class so the
    /// repository's current `only-testing:SplatNativeTests/SplatExportServiceTests` CI gate
    /// executes SH3 preservation without requiring a shared workflow edit.
    func testSH3CanonicalAssetRoundTripsThroughCurrentExportCIGate() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s7-sh3-export-ci-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coefficients = (0..<16).map { index -> SIMD3<Float> in
            let value = Float(index + 1) * 0.006
            return SIMD3<Float>(value, -value * 0.7, value * 0.4)
        }
        let points = [
            SplatPoint(
                position: SIMD3<Float>(-0.2, 0.1, 0.5),
                color: .sphericalHarmonicFloat(coefficients),
                opacity: .linearFloat(0.82),
                scale: .linearFloat(SIMD3<Float>(0.02, 0.025, 0.03)),
                rotation: simd_quatf(angle: 0.15, axis: SIMD3<Float>(0, 1, 0))
            ),
            SplatPoint(
                position: SIMD3<Float>(0.25, -0.08, 0.7),
                color: .sphericalHarmonicFloat(coefficients.map { $0 * 0.75 }),
                opacity: .linearFloat(0.71),
                scale: .linearFloat(SIMD3<Float>(0.03, 0.02, 0.027)),
                rotation: simd_quatf(angle: -0.2, axis: SIMD3<Float>(1, 0, 0))
            )
        ]

        let legacyURL = root.appendingPathComponent("result.splat")
        let legacyWriter = try DotSplatSceneWriter(toFileAtPath: legacyURL.path)
        try await legacyWriter.write(points)
        try await legacyWriter.close()

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: legacyURL)
        let canonicalWriter = try SplatPLYSceneWriter(toFileAtPath: canonicalURL.path)
        try await canonicalWriter.start(sphericalHarmonicDegree: 3, binary: true, pointCount: points.count)
        try await canonicalWriter.write(points)
        try await canonicalWriter.close()

        XCTAssertEqual(try SplatCanonicalSHAsset.inspectPLY(canonicalURL).shDegree, 3)

        for format in SplatExportService.Format.allCases {
            let output = try await SplatExportService.export(
                sourceURL: legacyURL,
                format: format,
                destinationDirectory: root,
                outputBaseName: "ci-\(format.rawValue)"
            )
            let decoded = try await AutodetectSceneReader(output).readAll()
            XCTAssertEqual(decoded.count, points.count)
            XCTAssertTrue(decoded.allSatisfy { $0.color.shDegree == .sh3 })
            XCTAssertTrue(decoded.allSatisfy { $0.color.higherOrderSHCoefficients.count == 45 })
            XCTAssertTrue(decoded.allSatisfy {
                $0.color.higherOrderSHCoefficients.contains { abs($0) > 0.0001 }
            })
        }
    }
}
