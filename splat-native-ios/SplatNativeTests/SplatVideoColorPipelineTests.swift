import AVFoundation
import CoreMedia
import Metal
import SplatIO
import simd
import XCTest

final class SplatVideoColorPipelineTests: XCTestCase {
    func testVideoRenderTargetUsesSRGBEncodingLikeLiveViewer() {
        XCTAssertEqual(SplatVideoExporter.renderPixelFormat, .bgra8Unorm_srgb)
    }

    func testEncodedVideoDeclaresBT709ColorProperties() {
        XCTAssertEqual(
            SplatVideoExporter.videoColorProperties[AVVideoColorPrimariesKey],
            AVVideoColorPrimaries_ITU_R_709_2
        )
        XCTAssertEqual(
            SplatVideoExporter.videoColorProperties[AVVideoTransferFunctionKey],
            AVVideoTransferFunction_ITU_R_709_2
        )
        XCTAssertEqual(
            SplatVideoExporter.videoColorProperties[AVVideoYCbCrMatrixKey],
            AVVideoYCbCrMatrix_ITU_R_709_2
        )
    }

    func testEncodedTrackCarriesBT709ColorMetadata() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable on this simulator runner")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-color-contract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let writer = try DotSplatSceneWriter(toFileAtPath: source.path)
        try await writer.write([
            SplatPoint(
                position: SIMD3<Float>(0, 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(128, 128, 128)),
                opacity: .linearFloat(1),
                scale: .linearFloat(SIMD3<Float>(0.25, 0.25, 0.25)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        ])
        try await writer.close()

        var configuration = SplatVideoConfiguration()
        configuration.aspectRatio = .square1x1
        configuration.cameraMotion = .fixed
        configuration.speed = .fast
        configuration.framesPerSecond = 1

        let output = try await SplatVideoExporter.export(
            sourceURL: source,
            configuration: configuration,
            destinationDirectory: root
        )
        let asset = AVURLAsset(url: output)
        let track = try XCTUnwrap(try await asset.loadTracks(withMediaType: .video).first)
        let format = try XCTUnwrap(try await track.load(.formatDescriptions).first)
        let extensions = CMFormatDescriptionGetExtensions(format) as NSDictionary

        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_ColorPrimaries] as? String,
            kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String
        )
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_TransferFunction] as? String,
            kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String
        )
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_YCbCrMatrix] as? String,
            kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String
        )
    }
}
