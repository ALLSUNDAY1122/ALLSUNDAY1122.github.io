import XCTest
import SplatIO
import simd

final class SplatExportCropSamplingParityTests: XCTestCase {
    func testSynchronousExportMaterializerMatchesViewerSamplingAcrossStrideBoundary() async throws {
        let fixture = try makeFixture(prefix: "splat-export-crop-parity")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let synchronous = try SplatPersistedEditMaterializer.materializeInMemory(
            sourceURL: fixture.source,
            points: fixture.points
        )
        let viewerParity = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: fixture.source,
            points: fixture.points
        )

        assertViewerParity(synchronous, viewerParity)
    }

    func testStreamingExportPlanMatchesViewerSamplingAcrossStrideBoundary() async throws {
        let fixture = try makeFixture(prefix: "splat-export-streaming-crop-parity")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let writer = try DotSplatSceneWriter(toFileAtPath: fixture.source.path)
        try await writer.write(fixture.points)
        try await writer.close()

        let streaming = try await SplatPersistedEditMaterializer.materializeStreamingCancellable(
            sourceURL: fixture.source,
            assetURL: fixture.source,
            sourcePointCount: fixture.points.count
        )
        let viewerParity = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: fixture.source,
            points: fixture.points
        )

        assertViewerParity(streaming, viewerParity)
    }

    private func makeFixture(prefix: String) throws -> (
        root: URL,
        source: URL,
        points: [SplatPoint]
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0, count: 32).write(to: source)

        let pointCount = 12_001
        let viewerSamples = Set(SplatCameraGeometry.framingSampleIndices(
            pointCount: pointCount,
            targetSampleCount: 8_000
        ))
        let points = (0..<pointCount).map { index in
            let x = viewerSamples.contains(index)
                ? Float(index) / Float(pointCount - 1)
                : 1_000
            return SplatPoint(
                position: SIMD3<Float>(x, 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(45, 80, 120)),
                opacity: .linearFloat(0.8),
                scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        }
        try SplatViewerEditStore.save(
            SplatEditSettings(cropXMax: 0.5),
            sourceURL: source
        )
        return (root, source, points)
    }

    private func assertViewerParity(_ actual: [SplatPoint], _ expected: [SplatPoint]) {
        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual.first?.position.x, expected.first?.position.x)
        XCTAssertEqual(actual.last?.position.x, expected.last?.position.x)
        XCTAssertGreaterThan(actual.count, 3_000)
        XCTAssertLessThan(actual.count, 5_000)
        XCTAssertTrue(actual.allSatisfy { $0.position.x < 1 })
    }
}
