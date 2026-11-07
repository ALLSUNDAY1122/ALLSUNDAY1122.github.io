import AVFoundation
import CoreMedia
import CoreVideo
import Metal
import SplatIO
import simd
import XCTest

extension SplatVideoExporterTests {
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

    func testVideoViewMatrixKeepsViewerCameraSpaceDisplayCorrection() {
        let eye = SIMD3<Float>(1.25, 0.75, 3.5)
        let center = SIMD3<Float>(0.25, -0.5, 0.75)
        let expected = SplatCameraGeometry.rotationZ(.pi) * SplatCameraGeometry.lookAt(
            eye: eye,
            center: center,
            up: SIMD3<Float>(0, 1, 0)
        )
        let actual = SplatVideoExporter.renderViewMatrix(eye: eye, center: center)
        for column in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(actual[column][row], expected[column][row], accuracy: 0.000_001)
            }
        }
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

    func testEncodedTrackCarriesBT709ColorMetadataAndPreservesMidGrayAndBackground() async throws {
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
        configuration.backgroundStyle = .light
        configuration.speed = .fast
        configuration.framesPerSecond = 1

        let output = try await SplatVideoExporter.export(
            sourceURL: source,
            configuration: configuration,
            destinationDirectory: root
        )
        let asset = AVURLAsset(url: output)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        let format = try XCTUnwrap(formats.first)
        let extensionDictionary = try XCTUnwrap(CMFormatDescriptionGetExtensions(format))
        let extensions = extensionDictionary as NSDictionary

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

        let center = try decodeFirstFrameBGRA(asset: asset, track: track, normalizedX: 0.5, normalizedY: 0.5)
        XCTAssertLessThanOrEqual(abs(Int(center.r) - Int(center.g)), 12)
        XCTAssertLessThanOrEqual(abs(Int(center.g) - Int(center.b)), 12)
        // sRGB 0.5 should remain a visible mid-tone after encode/decode. A linear UNORM target
        // incorrectly tagged as BT.709 falls near the mid-50s for this fixture, which this gate rejects.
        XCTAssertGreaterThanOrEqual(center.r, 90)
        XCTAssertLessThanOrEqual(center.r, 175)

        let corner = try decodeFirstFrameBGRA(asset: asset, track: track, normalizedX: 0.02, normalizedY: 0.02)
        XCTAssertLessThanOrEqual(abs(Int(corner.r) - Int(corner.g)), 12)
        XCTAssertLessThanOrEqual(abs(Int(corner.g) - Int(corner.b)), 12)
        XCTAssertGreaterThanOrEqual(corner.r, 180)
        XCTAssertGreaterThanOrEqual(corner.g, 180)
        XCTAssertGreaterThanOrEqual(corner.b, 180)
    }

    func testEncodedVideoPreservesStrongChromaticOrdering() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable on this simulator runner")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-chroma-contract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let writer = try DotSplatSceneWriter(toFileAtPath: source.path)
        try await writer.write([
            SplatPoint(
                position: SIMD3<Float>(0, 0, 0),
                color: .sRGBUInt8(SIMD3<UInt8>(220, 50, 20)),
                opacity: .linearFloat(1),
                scale: .linearFloat(SIMD3<Float>(0.32, 0.32, 0.32)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        ])
        try await writer.close()

        var configuration = SplatVideoConfiguration()
        configuration.aspectRatio = .square1x1
        configuration.cameraMotion = .fixed
        configuration.backgroundStyle = .dark
        configuration.speed = .fast
        configuration.framesPerSecond = 1

        let output = try await SplatVideoExporter.export(
            sourceURL: source,
            configuration: configuration,
            destinationDirectory: root
        )
        let asset = AVURLAsset(url: output)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let center = try decodeFirstFrameBGRA(asset: asset, track: track, normalizedX: 0.5, normalizedY: 0.5)

        // This is deliberately an ordering/contrast gate rather than an exact codec byte match.
        // H.264 may move channel values slightly, but a transfer/matrix regression must not turn a
        // strongly red Gaussian into a neutral/desaturated result while metadata still looks valid.
        XCTAssertGreaterThanOrEqual(center.r, 120)
        XCTAssertGreaterThan(Int(center.r) - Int(center.g), 45)
        XCTAssertGreaterThan(Int(center.r) - Int(center.b), 70)
        XCTAssertGreaterThanOrEqual(Int(center.g) - Int(center.b), 5)
    }

    private func decodeFirstFrameBGRA(
        asset: AVAsset,
        track: AVAssetTrack,
        normalizedX: Double,
        normalizedY: Double
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
        let safeX = min(1, max(0, normalizedX))
        let safeY = min(1, max(0, normalizedY))
        let x = min(width - 1, Int((Double(width - 1) * safeX).rounded()))
        let y = min(height - 1, Int((Double(height - 1) * safeY).rounded()))
        let offset = y * rowBytes + x * 4
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}
