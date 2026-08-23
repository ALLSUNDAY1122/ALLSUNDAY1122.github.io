import AVFoundation
import CoreVideo
import Foundation
import Metal
import MetalSplatter
import SplatIO
import simd

enum SplatVideoExporter {
    enum ExportError: LocalizedError {
        case metalUnavailable
        case commandQueueUnavailable
        case emptyScene
        case cannotCreateWriter
        case cannotAddVideoInput
        case cannotStartWriter
        case pixelBufferPoolUnavailable
        case pixelBufferAllocationFailed
        case textureCacheFailed
        case textureCreationFailed
        case commandBufferFailed
        case renderSkipped
        case appendFailed
        case writerFailed(String)
        case outputMissing

        var errorDescription: String? {
            switch self {
            case .metalUnavailable: return "この端末では動画用のMetal描画を開始できません。"
            case .commandQueueUnavailable: return "動画用のGPUコマンドを作成できません。"
            case .emptyScene: return "動画にするGaussianがありません。"
            case .cannotCreateWriter: return "動画ファイルを作成できません。"
            case .cannotAddVideoInput: return "動画エンコーダを初期化できません。"
            case .cannotStartWriter: return "動画の書き込みを開始できません。"
            case .pixelBufferPoolUnavailable: return "動画フレーム用バッファを作成できません。"
            case .pixelBufferAllocationFailed: return "動画フレームのメモリを確保できません。"
            case .textureCacheFailed: return "動画フレームをMetalへ接続できません。"
            case .textureCreationFailed: return "動画フレームのMetal textureを作成できません。"
            case .commandBufferFailed: return "動画フレームのGPU処理に失敗しました。"
            case .renderSkipped: return "3D描画の準備が完了せず動画化できませんでした。"
            case .appendFailed: return "動画フレームを保存できませんでした。"
            case .writerFailed(let message): return "動画の保存に失敗しました。\n\(message)"
            case .outputMissing: return "動画ファイルを完成できませんでした。"
            }
        }
    }

    static func export(
        sourceURL: URL,
        configuration: SplatVideoConfiguration,
        destinationDirectory: URL? = nil
    ) async throws -> URL {
        try Task.checkCancellation()

        // Reject scenes that cannot fit inside the bounded video working set before
        // readAll(), Metal buffers, pixel buffers, or VideoToolbox state are allocated.
        try SplatVideoMemoryPolicy.preflight(
            sourceURL: sourceURL,
            configuration: configuration
        )
        try Task.checkCancellation()

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ExportError.metalUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw ExportError.commandQueueUnavailable
        }

        let reader = try AutodetectSceneReader(sourceURL)
        let points = try await reader.readAll()
        guard !points.isEmpty else { throw ExportError.emptyScene }
        try Task.checkCancellation()

        let framing = SplatCameraGeometry.robustFraming(for: points)
        let chunk = try SplatChunk(device: device, from: points)
        let renderer = try SplatRenderer(
            device: device,
            colorFormat: .bgra8Unorm,
            depthFormat: .invalid,
            sampleCount: 1,
            maxViewCount: 1,
            maxSimultaneousRenders: 1,
            highQualityDepth: false,
            clearColor: MTLClearColor(red: 0.025, green: 0.03, blue: 0.04, alpha: 1)
        )
        await renderer.addChunk(chunk)

        let directory = destinationDirectory ?? sourceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let finalURL = directory.appendingPathComponent("scan-video-\(UUID().uuidString).mp4")
        let partialURL = directory.appendingPathComponent(".\(finalURL.lastPathComponent).partial.mp4")
        try? FileManager.default.removeItem(at: partialURL)

        do {
            let result = try await encode(
                renderer: renderer,
                commandQueue: commandQueue,
                device: device,
                framing: framing,
                configuration: configuration,
                outputURL: partialURL
            )
            guard result else { throw ExportError.outputMissing }
            try Task.checkCancellation()

            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
            try validateOutput(finalURL)
            return finalURL
        } catch {
            try? FileManager.default.removeItem(at: partialURL)
            try? FileManager.default.removeItem(at: finalURL)
            throw error
        }
    }

    private static func encode(
        renderer: SplatRenderer,
        commandQueue: MTLCommandQueue,
        device: MTLDevice,
        framing: SplatCameraGeometry.Framing,
        configuration: SplatVideoConfiguration,
        outputURL: URL
    ) async throws -> Bool {
        let dimensions = configuration.dimensions
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw ExportError.cannotCreateWriter
        }

        let bitsPerPixel = 0.12
        let bitrate = max(
            2_000_000,
            Int(Double(dimensions.width * dimensions.height * configuration.framesPerSecond) * bitsPerPixel)
        )
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: dimensions.width,
            AVVideoHeightKey: dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: configuration.framesPerSecond,
                AVVideoMaxKeyFrameIntervalKey: configuration.framesPerSecond * 2,
            ],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw ExportError.cannotAddVideoInput }
        writer.add(input)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: dimensions.width,
            kCVPixelBufferHeightKey as String: dimensions.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "startWriting failed")
        }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else {
            writer.cancelWriting()
            throw ExportError.pixelBufferPoolUnavailable
        }

        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let textureCache else {
            writer.cancelWriting()
            throw ExportError.textureCacheFailed
        }

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(configuration.framesPerSecond))
        let totalFrames = configuration.totalFrames
        let aspect = Float(dimensions.width) / Float(max(1, dimensions.height))
        let projection = SplatCameraGeometry.perspective(
            fovY: 55 * .pi / 180,
            aspect: max(0.1, aspect),
            near: 0.01,
            far: 100
        )

        for frameIndex in 0..<totalFrames {
            try Task.checkCancellation()
            try await waitUntilReady(input, writer: writer)

            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
                  let pixelBuffer else {
                writer.cancelWriting()
                throw ExportError.pixelBufferAllocationFailed
            }

            var cvTexture: CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(
                nil,
                textureCache,
                pixelBuffer,
                nil,
                .bgra8Unorm,
                dimensions.width,
                dimensions.height,
                0,
                &cvTexture
            )
            guard status == kCVReturnSuccess,
                  let cvTexture,
                  let colorTexture = CVMetalTextureGetTexture(cvTexture) else {
                writer.cancelWriting()
                throw ExportError.textureCreationFailed
            }

            let progress = totalFrames <= 1
                ? 0.0
                : Double(frameIndex) / Double(totalFrames - 1)
            let sample = configuration.cameraSample(progress: progress)
            let distance = framing.distance * sample.distanceMultiplier
            let eye = SplatCameraGeometry.eye(
                center: framing.center,
                distance: distance,
                yaw: sample.yaw,
                pitch: sample.pitch
            )
            let viewMatrix = SplatCameraGeometry.lookAt(
                eye: eye,
                center: framing.center,
                up: SIMD3<Float>(0, 1, 0)
            ) * SplatCameraGeometry.rotationZ(.pi)

            let viewport = SplatRenderer.ViewportDescriptor(
                viewport: MTLViewport(
                    originX: 0,
                    originY: 0,
                    width: Double(dimensions.width),
                    height: Double(dimensions.height),
                    znear: 0,
                    zfar: 1
                ),
                projectionMatrix: projection,
                viewMatrix: viewMatrix,
                screenSize: SIMD2(dimensions.width, dimensions.height)
            )

            var didRender = false
            for attempt in 0..<20 where !didRender {
                try Task.checkCancellation()
                guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                    writer.cancelWriting()
                    throw ExportError.commandBufferFailed
                }
                do {
                    didRender = try renderer.render(
                        viewports: [viewport],
                        colorTexture: colorTexture,
                        colorStoreAction: .store,
                        depthTexture: nil,
                        rasterizationRateMap: nil,
                        renderTargetArrayLength: 0,
                        accessTimeout: 0.25,
                        sortTimeout: attempt == 0 ? 0.5 : 0.1,
                        to: commandBuffer
                    )
                } catch {
                    writer.cancelWriting()
                    throw error
                }
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    commandBuffer.addCompletedHandler { _ in
                        continuation.resume()
                    }
                    commandBuffer.commit()
                }
                guard commandBuffer.status != .error else {
                    writer.cancelWriting()
                    throw ExportError.writerFailed(commandBuffer.error?.localizedDescription ?? "Metal command failed")
                }
                if !didRender {
                    try await Task.sleep(for: .milliseconds(10))
                }
            }

            guard didRender else {
                writer.cancelWriting()
                throw ExportError.renderSkipped
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                writer.cancelWriting()
                throw ExportError.writerFailed(writer.error?.localizedDescription ?? "append failed")
            }

            if frameIndex % 30 == 0 {
                CVMetalTextureCacheFlush(textureCache, 0)
            }
        }

        input.markAsFinished()
        try await finish(writer)
        CVMetalTextureCacheFlush(textureCache, 0)

        if writer.status == .failed {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "finishWriting failed")
        }
        return writer.status == .completed
    }

    private static func waitUntilReady(_ input: AVAssetWriterInput, writer: AVAssetWriter) async throws {
        while !input.isReadyForMoreMediaData {
            try Task.checkCancellation()
            if writer.status == .failed {
                throw ExportError.writerFailed(writer.error?.localizedDescription ?? "writer failed")
            }
            if writer.status == .cancelled {
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    private static func finish(_ writer: AVAssetWriter) async throws {
        try await withCheckedThrowingContinuation { continuation in
            writer.finishWriting {
                if writer.status == .completed {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: ExportError.writerFailed(
                        writer.error?.localizedDescription ?? "finishWriting failed"
                    ))
                }
            }
        }
    }

    private static func validateOutput(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0 else {
            throw ExportError.outputMissing
        }
    }
}
