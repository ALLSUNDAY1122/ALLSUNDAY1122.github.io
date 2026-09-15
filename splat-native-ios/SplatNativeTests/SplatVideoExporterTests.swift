import AVFoundation
import Metal
import SplatIO
import simd
import XCTest

final class SplatVideoExporterTests: XCTestCase {
    func testRealSplatRendersToReadableMP4() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable on this simulator runner")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-video-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let writer = try DotSplatSceneWriter(toFileAtPath: source.path)
        try await writer.write(makePoints())
        try await writer.close()

        var configuration = SplatVideoConfiguration()
        configuration.aspectRatio = .square1x1
        configuration.cameraMotion = .fixed
        configuration.speed = .fast
        // Keep the regression fast while still exercising multiple encoded frames.
        configuration.framesPerSecond = 1

        let output = try await SplatVideoExporter.export(
            sourceURL: source,
            configuration: configuration,
            destinationDirectory: root
        )

        XCTAssertEqual(output.pathExtension.lowercased(), "mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertGreaterThan(try byteCount(output), 1_000)

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 2.5)

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(videoTracks.first)
        let naturalSize = try await track.load(.naturalSize)
        XCTAssertEqual(Int(abs(naturalSize.width)), 720)
        XCTAssertEqual(Int(abs(naturalSize.height)), 720)
    }

    func testMemoryPreflightProducesBoundedEstimateForNormalScene() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-video-memory-normal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try makeSparseDotSplat(source, pointCount: 500_000)

        var configuration = SplatVideoConfiguration()
        configuration.aspectRatio = .landscape16x9

        let estimate = try SplatVideoMemoryPolicy.preflight(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: 4 * 1024 * 1024 * 1024
        )

        XCTAssertEqual(estimate.pointCount, 500_000)
        XCTAssertLessThan(estimate.estimatedPeakBytes, estimate.budgetBytes)
        print(
            "S6_MEMORY_PREFLIGHT normal pointCount=\(estimate.pointCount) "
            + "estimatedPeakMB=\(estimate.estimatedPeakMegabytes) budgetMB=\(estimate.budgetMegabytes)"
        )
    }

    func testExporterRejectsOversizedSceneBeforeDecode() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-video-memory-large-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        // 3,000,000 * 32 bytes is a valid fixed-width .splat length but exceeds the
        // exporter's capped working-set budget. A sparse file keeps this regression cheap.
        try makeSparseDotSplat(source, pointCount: 3_000_000)

        var configuration = SplatVideoConfiguration()
        configuration.aspectRatio = .square1x1
        configuration.cameraMotion = .fixed
        configuration.speed = .fast
        configuration.framesPerSecond = 1

        do {
            _ = try await SplatVideoExporter.export(
                sourceURL: source,
                configuration: configuration,
                destinationDirectory: root
            )
            XCTFail("Expected memory preflight to reject the oversized scene")
        } catch let error as SplatVideoMemoryPolicy.PolicyError {
            guard case let .sceneTooLarge(pointCount, estimatedPeakMegabytes, budgetMegabytes) = error else {
                return XCTFail("Unexpected policy error: \(error)")
            }
            XCTAssertEqual(pointCount, 3_000_000)
            XCTAssertGreaterThan(estimatedPeakMegabytes, budgetMegabytes)
            XCTAssertTrue(error.localizedDescription.contains("安全に動画化できません"))
            print(
                "S6_MEMORY_PREFLIGHT rejected pointCount=\(pointCount) "
                + "estimatedPeakMB=\(estimatedPeakMegabytes) budgetMB=\(budgetMegabytes)"
            )
        } catch {
            XCTFail("Oversized source reached a later decode/render failure instead of preflight: \(error)")
        }
    }

    private func makePoints() -> [SplatPoint] {
        [
            SplatPoint(
                position: SIMD3<Float>(-0.18, -0.10, 0.0),
                color: .sRGBUInt8(SIMD3<UInt8>(235, 60, 50)),
                opacity: .linearFloat(0.95),
                scale: .linearFloat(SIMD3<Float>(0.10, 0.10, 0.10)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
            SplatPoint(
                position: SIMD3<Float>(0.18, -0.10, 0.0),
                color: .sRGBUInt8(SIMD3<UInt8>(55, 220, 95)),
                opacity: .linearFloat(0.95),
                scale: .linearFloat(SIMD3<Float>(0.10, 0.10, 0.10)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
            SplatPoint(
                position: SIMD3<Float>(0.0, 0.20, 0.0),
                color: .sRGBUInt8(SIMD3<UInt8>(55, 105, 240)),
                opacity: .linearFloat(0.95),
                scale: .linearFloat(SIMD3<Float>(0.10, 0.10, 0.10)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            ),
        ]
    }

    private func makeSparseDotSplat(_ url: URL, pointCount: Int) throws {
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(pointCount * 32))
        try handle.close()
    }

    private func byteCount(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.size] as? NSNumber).intValue
    }
}
