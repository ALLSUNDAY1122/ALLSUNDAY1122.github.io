import XCTest
import SplatIO
import simd

extension SplatExportServiceTests {
    /// This method intentionally extends the existing SplatExportServiceTests class so the
    /// repository's current `only-testing:SplatNativeTests/SplatExportServiceTests` CI gate
    /// executes the complete synthetic SH3 acceptance without requiring a shared workflow edit.
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

        let descriptor = try SplatCanonicalSHAsset.inspectPLY(canonicalURL)
        XCTAssertEqual(descriptor.pointCount, points.count)
        XCTAssertEqual(descriptor.shDegree, 3)
        XCTAssertEqual(descriptor.higherOrderPropertyCount, 45)

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

            for (expected, actual) in zip(points, decoded) {
                let expectedSH = expected.color.asSphericalHarmonicFloat
                let actualSH = actual.color.asSphericalHarmonicFloat
                XCTAssertEqual(actualSH.count, 16)
                for index in 1..<16 {
                    if format == .spz {
                        // SPZ v3 intentionally quantizes SH1 to 5 bits and SH2/SH3 to 4 bits.
                        // Compare against the format-defined quantized value rather than weakening
                        // the gate with a broad absolute tolerance that can hide coefficient loss.
                        let expectedQuantized = SIMD3<Float>(
                            spzQuantizedSH(expectedSH[index].x, coefficientIndex: index),
                            spzQuantizedSH(expectedSH[index].y, coefficientIndex: index),
                            spzQuantizedSH(expectedSH[index].z, coefficientIndex: index)
                        )
                        XCTAssertEqual(actualSH[index].x, expectedQuantized.x, accuracy: 0.000001)
                        XCTAssertEqual(actualSH[index].y, expectedQuantized.y, accuracy: 0.000001)
                        XCTAssertEqual(actualSH[index].z, expectedQuantized.z, accuracy: 0.000001)
                    } else {
                        XCTAssertEqual(actualSH[index].x, expectedSH[index].x, accuracy: 0.00001)
                        XCTAssertEqual(actualSH[index].y, expectedSH[index].y, accuracy: 0.00001)
                        XCTAssertEqual(actualSH[index].z, expectedSH[index].z, accuracy: 0.00001)
                    }
                }
            }

            let bboxAccuracy: Float = format == .spz ? 0.01 : 0.00001
            assertSH3BoundingBox(points, decoded, accuracy: bboxAccuracy)
        }
    }

    /// Mirrors the SPZ v3 SH packing rule used by the pinned spz-swift dependency:
    /// SH1 uses 5 effective bits (bucket 8), while SH2/SH3 use 4 (bucket 16).
    /// The helper is deliberately local to the acceptance test so production export code
    /// remains independent from a test-only representation of the codec.
    private func spzQuantizedSH(_ value: Float, coefficientIndex: Int) -> Float {
        let bucketSize = coefficientIndex <= 3 ? 8 : 16
        var quantized = Int((value * 128.0).rounded() + 128.0)
        quantized = ((quantized + bucketSize / 2) / bucketSize) * bucketSize
        quantized = min(max(quantized, 0), 255)
        return (Float(quantized) - 128.0) / 128.0
    }

    private func assertSH3BoundingBox(
        _ expected: [SplatPoint],
        _ actual: [SplatPoint],
        accuracy: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectedBounds = sh3Bounds(expected)
        let actualBounds = sh3Bounds(actual)
        XCTAssertEqual(actualBounds.min.x, expectedBounds.min.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBounds.min.y, expectedBounds.min.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBounds.min.z, expectedBounds.min.z, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBounds.max.x, expectedBounds.max.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBounds.max.y, expectedBounds.max.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBounds.max.z, expectedBounds.max.z, accuracy: accuracy, file: file, line: line)
    }

    private func sh3Bounds(_ points: [SplatPoint]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for point in points {
            minimum = simd_min(minimum, point.position)
            maximum = simd_max(maximum, point.position)
        }
        return (minimum, maximum)
    }
}
