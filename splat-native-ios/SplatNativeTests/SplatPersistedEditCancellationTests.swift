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
        XCTAssertEqual(actual.first?.color.asSRGBFloat.x, expected.first?.color.asSRGBFloat.x, accuracy: 0.0001)
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
