import AVFoundation
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

    private func byteCount(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.size] as? NSNumber).intValue
    }
}
