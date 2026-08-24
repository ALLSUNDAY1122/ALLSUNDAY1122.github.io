import XCTest
import SplatIO
import simd

final class SplatSH3PreservationTests: XCTestCase {
    func testCanonicalSH3PLYDrivesPLYAndSPZWithoutCollapsingToSH0() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sh3-preservation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let points = makeSH3Points()
        let legacy = root.appendingPathComponent("result.splat")
        let legacyWriter = try DotSplatSceneWriter(toFileAtPath: legacy.path)
        try await legacyWriter.write(points)
        try await legacyWriter.close()

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: legacy)
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
                sourceURL: legacy,
                format: format,
                destinationDirectory: root,
                outputBaseName: "retained-\(format.rawValue)"
            )
            let decoded = try await readAll(output)
            XCTAssertEqual(decoded.count, points.count)
            assertBoundingBoxEqual(points, decoded, accuracy: format == .spz ? 0.01 : 0.00001)

            for point in decoded {
                XCTAssertEqual(point.color.shDegree, .sh3)
                XCTAssertEqual(point.color.asSphericalHarmonicFloat.count, 16)
                XCTAssertEqual(point.color.higherOrderSHCoefficients.count, 45)
                XCTAssertTrue(point.color.higherOrderSHCoefficients.contains { abs($0) > 0.0001 })
            }
        }
    }

    func testSH3CoefficientFixtureRoundTripsThroughSPZ() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sh3-coefficients-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourcePoints = makeSH3Points()
        let legacy = root.appendingPathComponent("result.splat")
        let legacyWriter = try DotSplatSceneWriter(toFileAtPath: legacy.path)
        try await legacyWriter.write(sourcePoints)
        try await legacyWriter.close()

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: legacy)
        let canonicalWriter = try SplatPLYSceneWriter(toFileAtPath: canonicalURL.path)
        try await canonicalWriter.start(sphericalHarmonicDegree: 3, binary: true, pointCount: sourcePoints.count)
        try await canonicalWriter.write(sourcePoints)
        try await canonicalWriter.close()

        let spz = try await SplatExportService.export(
            sourceURL: legacy,
            format: .spz,
            destinationDirectory: root,
            outputBaseName: "fixture"
        )
        let decoded = try await readAll(spz)
        XCTAssertEqual(decoded.count, sourcePoints.count)

        for (expected, actual) in zip(sourcePoints, decoded) {
            let expectedSH = expected.color.asSphericalHarmonicFloat
            let actualSH = actual.color.asSphericalHarmonicFloat
            XCTAssertEqual(actualSH.count, 16)
            XCTAssertEqual(actual.color.shDegree, .sh3)

            // SPZ intentionally quantizes coefficients; verify the signal survives rather than
            // demanding bit-identical floats from a compressed format.
            for index in 1..<16 {
                XCTAssertEqual(actualSH[index].x, expectedSH[index].x, accuracy: 0.025)
                XCTAssertEqual(actualSH[index].y, expectedSH[index].y, accuracy: 0.025)
                XCTAssertEqual(actualSH[index].z, expectedSH[index].z, accuracy: 0.025)
            }
        }
    }

    func testLegacyDotSplatRemainsSupportedWhenCanonicalAssetIsAbsent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sh3-legacy-fallback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("result.splat")
        let writer = try DotSplatSceneWriter(toFileAtPath: legacy.path)
        try await writer.write(makeSH3Points())
        try await writer.close()

        XCTAssertNil(
            SplatCanonicalSHAsset.existingAsset(
                forLegacySplat: legacy,
                expectedPointCount: makeSH3Points().count
            )
        )

        let output = try await SplatExportService.export(
            sourceURL: legacy,
            format: .spz,
            destinationDirectory: root,
            outputBaseName: "legacy"
        )
        let decoded = try await readAll(output)
        XCTAssertFalse(decoded.isEmpty)
        XCTAssertTrue(decoded.allSatisfy { $0.color.shDegree == .sh0 })
    }

    private func makeSH3Points() -> [SplatPoint] {
        (0..<4).map { pointIndex in
            let coefficients = (0..<16).map { coefficientIndex -> SIMD3<Float> in
                let base = Float((pointIndex + 1) * (coefficientIndex + 1)) * 0.0035
                return SIMD3<Float>(base, -base * 0.75, base * 0.5)
            }
            return SplatPoint(
                position: SIMD3<Float>(
                    -0.3 + Float(pointIndex) * 0.2,
                    -0.1 + Float(pointIndex) * 0.08,
                    0.4 + Float(pointIndex) * 0.1
                ),
                color: .sphericalHarmonicFloat(coefficients),
                opacity: .linearFloat(0.65 + Float(pointIndex) * 0.07),
                scale: .linearFloat(SIMD3<Float>(
                    0.02 + Float(pointIndex) * 0.002,
                    0.025,
                    0.03
                )),
                rotation: simd_quatf(
                    angle: 0.08 * Float(pointIndex + 1),
                    axis: simd_normalize(SIMD3<Float>(1, 1, 0.5))
                )
            )
        }
    }

    private func readAll(_ url: URL) async throws -> [SplatPoint] {
        let reader = try AutodetectSceneReader(url)
        let stream = try await reader.read()
        var result: [SplatPoint] = []
        for try await points in stream {
            result.append(contentsOf: points)
        }
        return result
    }

    private func assertBoundingBoxEqual(
        _ expected: [SplatPoint],
        _ actual: [SplatPoint],
        accuracy: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectedBounds = bounds(expected)
        let actualBounds = bounds(actual)
        for axis in 0..<3 {
            XCTAssertEqual(actualBounds.min[axis], expectedBounds.min[axis], accuracy: accuracy, file: file, line: line)
            XCTAssertEqual(actualBounds.max[axis], expectedBounds.max[axis], accuracy: accuracy, file: file, line: line)
        }
    }

    private func bounds(_ points: [SplatPoint]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for point in points {
            minimum = simd_min(minimum, point.position)
            maximum = simd_max(maximum, point.position)
        }
        return (minimum, maximum)
    }
}
