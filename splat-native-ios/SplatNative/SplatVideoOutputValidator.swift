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

        if let expectedDimensions {
            let encodedWidth = Int(abs(naturalSize.width).rounded())
            let encodedHeight = Int(abs(naturalSize.height).rounded())
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
        // Decode exactly one frame before the file becomes shareable. This is bounded work and
        // catches corrupt/truncated media without walking the full export a second time.
        try Task.checkCancellation()
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: videoTrack,
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

        let firstFrame = output.copyNextSampleBuffer()
        try Task.checkCancellation()
        guard firstFrame != nil else {
            throw ValidationError.undecodableVideoFrame
        }
    }
}
