import AVFoundation
import CoreVideo
import Foundation

/// Rejects partial/non-video files even when AVAssetWriter happened to leave non-zero bytes.
/// Share/export must expose only an MP4 that AVFoundation can reopen as a real video asset.
enum SplatVideoOutputValidator {
    enum ValidationError: Error, Equatable {
        case missingOrEmpty
        case missingVideoTrack
        case invalidVideoDimensions
        case unexpectedVideoDimensions
        case invalidDuration
        case unexpectedlyShortDuration
        case undecodableVideoFrame
    }

    static func validate(
        _ url: URL,
        expectedDimensions: (width: Int, height: Int)? = nil,
        minimumDuration: TimeInterval? = nil,
        fileManager: FileManager = .default
    ) async throws {
        try Task.checkCancellation()
        guard url.isFileURL,
              fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value > 0 else {
            throw ValidationError.missingOrEmpty
        }

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        // A user can cancel while AVFoundation is parsing a large MP4. Do not let a validation
        // result obtained after cancellation escape back to the export/share flow as success.
        try Task.checkCancellation()
        guard let videoTrack = tracks.first else {
            throw ValidationError.missingVideoTrack
        }

        // A parsable container can still carry a degenerate video track. Reject zero, NaN and
        // infinite geometry before the file becomes shareable so downstream viewers do not receive
        // an MP4 that has duration but no meaningful render surface.
        let naturalSize = try await videoTrack.load(.naturalSize)
        try Task.checkCancellation()
        guard naturalSize.width.isFinite,
              naturalSize.height.isFinite,
              naturalSize.width > 0,
              naturalSize.height > 0 else {
            throw ValidationError.invalidVideoDimensions
        }

        let encodedWidth = Int(abs(naturalSize.width).rounded())
        let encodedHeight = Int(abs(naturalSize.height).rounded())
        if let expectedDimensions {
            guard encodedWidth == expectedDimensions.width,
                  encodedHeight == expectedDimensions.height else {
                throw ValidationError.unexpectedVideoDimensions
            }
        }

        let duration = try await asset.load(.duration)
        try Task.checkCancellation()
        guard duration.isNumeric,
              duration.seconds.isFinite,
              duration.seconds > 0 else {
            throw ValidationError.invalidDuration
        }

        if let minimumDuration {
            guard minimumDuration.isFinite,
                  minimumDuration >= 0,
                  duration.seconds >= minimumDuration else {
                throw ValidationError.unexpectedlyShortDuration
            }
        }

        // Metadata alone is insufficient: a damaged MP4 can expose a video track and plausible
        // duration while containing no frame that the system decoder can actually materialize.
        // Probe both the beginning and the tail. A first-frame-only probe misses files that were
        // truncated after a valid prefix, while a full second decode would be unnecessarily costly.
        try Task.checkCancellation()
        try validateDecodedFrames(
            asset: asset,
            track: videoTrack,
            encodedWidth: encodedWidth,
            encodedHeight: encodedHeight,
            timeRange: nil,
            drainRange: false
        )
        try Task.checkCancellation()

        // Restrict the second reader to the final bounded window. Drain that entire window so a
        // corrupt final GOP/frame cannot hide behind one decodable sample near the window start.
        // At 30 fps this is normally <=15 decoded frames, keeping completion validation bounded.
        let tailWindowSeconds = min(0.5, duration.seconds)
        let tailStartSeconds = max(0, duration.seconds - tailWindowSeconds)
        let tailRange = CMTimeRange(
            start: CMTime(seconds: tailStartSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: max(0.001, duration.seconds - tailStartSeconds), preferredTimescale: 600)
        )
        try validateDecodedFrames(
            asset: asset,
            track: videoTrack,
            encodedWidth: encodedWidth,
            encodedHeight: encodedHeight,
            timeRange: tailRange,
            drainRange: true
        )
        try Task.checkCancellation()
    }

    private static func validateDecodedFrames(
        asset: AVAsset,
        track: AVAssetTrack,
        encodedWidth: Int,
        encodedHeight: Int,
        timeRange: CMTimeRange?,
        drainRange: Bool
    ) throws {
        let reader = try AVAssetReader(asset: asset)
        if let timeRange {
            reader.timeRange = timeRange
        }
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw ValidationError.undecodableVideoFrame
        }
        reader.add(output)
        guard reader.startReading() else {
            throw ValidationError.undecodableVideoFrame
        }
        defer { reader.cancelReading() }

        var decodedFrameCount = 0
        while let frame = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let imageBuffer = CMSampleBufferGetImageBuffer(frame) else {
                throw ValidationError.undecodableVideoFrame
            }

            // Verify decoded pixels agree with the encoded track geometry. This catches containers whose
            // metadata advertises one surface while the decoder yields a degenerate/inconsistent buffer.
            let decodedWidth = CVPixelBufferGetWidth(imageBuffer)
            let decodedHeight = CVPixelBufferGetHeight(imageBuffer)
            guard decodedWidth > 0,
                  decodedHeight > 0,
                  decodedWidth == encodedWidth,
                  decodedHeight == encodedHeight else {
                throw ValidationError.undecodableVideoFrame
            }
            decodedFrameCount += 1
            if !drainRange { break }
        }

        guard decodedFrameCount > 0 else {
            throw ValidationError.undecodableVideoFrame
        }
        if drainRange {
            // Reaching nil must mean the bounded range decoded normally, not that AVFoundation
            // stopped because the media tail was corrupt.
            guard reader.status == .completed else {
                throw ValidationError.undecodableVideoFrame
            }
        }
    }
}
