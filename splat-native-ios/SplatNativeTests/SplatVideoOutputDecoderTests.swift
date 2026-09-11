import AVFoundation
import CoreVideo
import XCTest

final class SplatVideoOutputDecoderTests: XCTestCase {
    func testValidatorAcceptsARealDecodableFrame() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("decodable-video-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        try await writeVideo(to: url, width: 16, height: 16, frameCount: 1, framesPerSecond: 30)

        try await SplatVideoOutputValidator.validate(
            url,
            expectedDimensions: (16, 16),
            minimumDuration: 0.01
        )
    }

    func testValidatorAcceptsDecodableTailOfMultiFrameVideo() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("decodable-video-tail-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        try await writeVideo(to: url, width: 16, height: 16, frameCount: 45, framesPerSecond: 30)

        try await SplatVideoOutputValidator.validate(
            url,
            expectedDimensions: (16, 16),
            minimumDuration: 1.0
        )
    }

    private func writeVideo(
        to url: URL,
        width: Int,
        height: Int,
        frameCount: Int,
        framesPerSecond: Int
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoExpectedSourceFrameRateKey: framesPerSecond,
                    AVVideoMaxKeyFrameIntervalKey: framesPerSecond
                ]
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        XCTAssertTrue(writer.canAdd(input))
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        for frameIndex in 0..<frameCount {
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                nil,
                &pixelBuffer
            )
            XCTAssertEqual(status, kCVReturnSuccess)
            let buffer = try XCTUnwrap(pixelBuffer)

            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, Int32(0x20 + (frameIndex % 0x40)), CVPixelBufferGetDataSize(buffer))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            while !input.isReadyForMoreMediaData {
                await Task.yield()
            }
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(framesPerSecond))
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: presentationTime))
        }

        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "writer did not complete")
    }
}
