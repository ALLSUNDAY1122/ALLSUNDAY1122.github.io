import AVFoundation
import CoreMedia
import CoreVideo
import Metal
import SplatIO
import simd
import XCTest

final class SplatVideoColorPipelineTests: XCTestCase {
    func testVideoRenderTargetUsesSRGBEncodingLikeLiveViewer() {
        XCTAssertEqual(SplatVideoExporter.renderPixelFormat, .bgra8Unorm_srgb)
    }

    func testVideoFieldOfViewMatchesLiveViewer() {
        XCTAssertEqual(
            SplatVideoExporter.renderFovY,
            55 * Float.pi / 180,
            accuracy: 0.000_001
        )
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

    func testEncodedTrackCarriesBT709ColorMetadataAndPreservesMidGray() async throws {
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

        let center = try decodeFirstFrameCenterBGRA(asset: asset, track: track)
        XCTAssertLessThanOrEqual(abs(Int(center.r) - Int(center.g)), 12)
        XCTAssertLessThanOrEqual(abs(Int(center.g) - Int(center.b)), 12)
        // sRGB 0.5 should remain a visible mid-tone after encode/decode. A linear UNORM target
        // incorrectly tagged as BT.709 falls near the mid-50s for this fixture, which this gate rejects.
        XCTAssertGreaterThanOrEqual(center.r, 90)
        XCTAssertLessThanOrEqual(center.r, 175)
    }

    private func decodeFirstFrameCenterBGRA(
        asset: AVAsset,
        track: AVAssetTrack
    ) throws -> (b: UInt8, g: UInt8, r: UInt8, a: UInt8) {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw CocoaError(.coderReadCorrupt) }
        reader.add(output)
        guard reader.startReading(),
              let sample = output.copyNextSampleBuffer(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
            throw CocoaError(.coderReadCorrupt)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            reader.cancelReading()
        }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CocoaError(.coderReadCorrupt)
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0, rowBytes >= width * 4 else {
            throw CocoaError(.coderReadCorrupt)
        }
        let x = width / 2
        let y = height / 2
        let offset = y * rowBytes + x * 4
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}
