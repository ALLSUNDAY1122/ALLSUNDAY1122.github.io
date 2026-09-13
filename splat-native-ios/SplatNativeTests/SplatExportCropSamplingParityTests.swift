import XCTest
import SplatIO
import simd

final class SplatExportCropSamplingParityTests: XCTestCase {
    func testSynchronousExportMaterializerMatchesViewerSamplingAcrossStrideBoundary() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-export-crop-parity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

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

        let synchronous = try SplatPersistedEditMaterializer.materializeInMemory(
            sourceURL: source,
            points: points
        )
        let viewerParity = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: source,
            points: points
        )

        XCTAssertEqual(synchronous.count, viewerParity.count)
        XCTAssertEqual(synchronous.first?.position.x, viewerParity.first?.position.x)
        XCTAssertEqual(synchronous.last?.position.x, viewerParity.last?.position.x)
        XCTAssertGreaterThan(synchronous.count, 3_000)
        XCTAssertLessThan(synchronous.count, 5_000)
        XCTAssertTrue(synchronous.allSatisfy { $0.position.x < 1 })
    }
}
