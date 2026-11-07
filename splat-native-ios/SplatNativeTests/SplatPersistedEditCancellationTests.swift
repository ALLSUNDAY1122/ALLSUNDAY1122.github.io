import XCTest
import SplatIO
import simd

final class SplatPersistedEditCancellationTests: XCTestCase {
    func testCancellableMaterializerMatchesSynchronousEditResult() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-cancellable-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0, count: 32).write(to: source)
        let edits = SplatEditSettings(
            exposureEV: 0.75,
            contrast: 1.15,
            cropXMin: 0.2,
            cropXMax: 0.85,
            cropYMin: 0,
            cropYMax: 1,
            cropZMin: 0,
            cropZMax: 1
        )
        try JSONEncoder().encode(edits).write(
            to: source.deletingPathExtension().appendingPathExtension("viewer.json"),
            options: .atomic
        )

        let points = (0..<2_000).map { index in
            SplatPoint(
                position: SIMD3<Float>(Float(index) / 1_999, 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(45, 80, 120)),
                opacity: .linearFloat(0.8),
                scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        }

        let expected = try SplatPersistedEditMaterializer.materializeInMemory(
            sourceURL: source,
            points: points
        )
        let actual = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: source,
            points: points
        )

        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual.first?.position.x, expected.first?.position.x)
        XCTAssertEqual(actual.last?.position.x, expected.last?.position.x)
        let actualFirst = try XCTUnwrap(actual.first)
        let expectedFirst = try XCTUnwrap(expected.first)
        XCTAssertEqual(actualFirst.color.asSRGBFloat.x, expectedFirst.color.asSRGBFloat.x, accuracy: 0.0001)
    }

    func testStreamingMaterializerMatchesInMemoryCropAndColorEdits() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-streaming-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let points = (0..<2_000).map { index in
            SplatPoint(
                position: SIMD3<Float>(Float(index) / 1_999, 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(45, 80, 120)),
                opacity: .linearFloat(0.8),
                scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        }
        let writer = try DotSplatSceneWriter(toFileAtPath: source.path)
        try await writer.write(points)
        try await writer.close()

        let edits = SplatEditSettings(
            exposureEV: 0.75,
            contrast: 1.15,
            cropXMin: 0.2,
            cropXMax: 0.85,
            cropYMin: 0,
            cropYMax: 1,
            cropZMin: 0,
            cropZMax: 1
        )
        try SplatViewerEditStore.save(edits, sourceURL: source)

        let expected = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: source,
            points: points
        )
        let actual = try await SplatPersistedEditMaterializer.materializeStreamingCancellable(
            sourceURL: source,
            assetURL: source,
            sourcePointCount: points.count
        )

        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual.first?.position.x, expected.first?.position.x)
        XCTAssertEqual(actual.last?.position.x, expected.last?.position.x)
        let actualFirst = try XCTUnwrap(actual.first)
        let expectedFirst = try XCTUnwrap(expected.first)
        XCTAssertEqual(actualFirst.color.asSRGBFloat.x, expectedFirst.color.asSRGBFloat.x, accuracy: 0.0001)
        XCTAssertEqual(actualFirst.color.asSRGBFloat.y, expectedFirst.color.asSRGBFloat.y, accuracy: 0.0001)
        XCTAssertEqual(actualFirst.color.asSRGBFloat.z, expectedFirst.color.asSRGBFloat.z, accuracy: 0.0001)
    }

    func testCropBoundsFollowViewerEvenSamplingAcrossStrideBoundary() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-viewer-crop-sampling-\(UUID().uuidString)", isDirectory: true)
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
            // Non-viewer sample points are deliberate high outliers. The old floor-stride export
            // sampler consumed every point at this count and moved the 99th-percentile crop bound
            // toward 1000; the live viewer's bounded sample keeps its range near 0...1.
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

        let actual = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: source,
            points: points
        )

        XCTAssertGreaterThan(actual.count, 3_000)
        XCTAssertLessThan(actual.count, 5_000)
        XCTAssertTrue(actual.allSatisfy { $0.position.x < 1 })
    }

    func testCancellableMaterializerIgnoresExternalViewerSidecarAlias() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("splat-cancellable-edit-alias-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("splat-cancellable-edit-external-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0, count: 32).write(to: source)
        let hostileEdits = SplatEditSettings(exposureEV: 2, contrast: 1.5)
        let externalSidecar = externalRoot.appendingPathComponent("viewer.json")
        try JSONEncoder().encode(hostileEdits).write(to: externalSidecar, options: .atomic)
        try fileManager.createSymbolicLink(
            at: source.deletingPathExtension().appendingPathExtension("viewer.json"),
            withDestinationURL: externalSidecar
        )

        let point = SplatPoint(
            position: .zero,
            color: .sRGBUInt8(SIMD3<UInt8>(40, 80, 120)),
            opacity: .linearFloat(1),
            scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        )
        let result = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: source,
            points: [point]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].color.asSRGBFloat.x, point.color.asSRGBFloat.x, accuracy: 0.0001)
        XCTAssertEqual(result[0].color.asSRGBFloat.y, point.color.asSRGBFloat.y, accuracy: 0.0001)
        XCTAssertEqual(result[0].color.asSRGBFloat.z, point.color.asSRGBFloat.z, accuracy: 0.0001)
    }

    func testCancellableMaterializerIgnoresOversizedViewerSidecar() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("splat-cancellable-edit-oversized-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0, count: 32).write(to: source)
        try Data(repeating: 0x41, count: 64 * 1024 + 1).write(
            to: source.deletingPathExtension().appendingPathExtension("viewer.json"),
            options: .atomic
        )

        let point = SplatPoint(
            position: .zero,
            color: .sRGBUInt8(SIMD3<UInt8>(50, 90, 130)),
            opacity: .linearFloat(1),
            scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        )
        let result = try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
            sourceURL: source,
            points: [point]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].color.asSRGBFloat.x, point.color.asSRGBFloat.x, accuracy: 0.0001)
    }

    func testCancellableMaterializerHonorsCancelledTask() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-cancelled-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0, count: 32).write(to: source)
        let edits = SplatEditSettings(
            exposureEV: 1,
            contrast: 1,
            cropXMin: 0,
            cropXMax: 1,
            cropYMin: 0,
            cropYMax: 1,
            cropZMin: 0,
            cropZMax: 1
        )
        try JSONEncoder().encode(edits).write(
            to: source.deletingPathExtension().appendingPathExtension("viewer.json"),
            options: .atomic
        )

        let point = SplatPoint(
            position: SIMD3<Float>(0, 0, 0),
            color: .sRGBUInt8(SIMD3<UInt8>(80, 80, 80)),
            opacity: .linearFloat(1),
            scale: .linearFloat(SIMD3<Float>(repeating: 0.02)),
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        )
        let points = Array(repeating: point, count: 100_000)

        let task = Task {
            try await SplatPersistedEditMaterializer.materializeInMemoryCancellable(
                sourceURL: source,
                points: points
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to abort persisted edit materialization")
        } catch is CancellationError {
            // Expected.
        }
    }
}
