import AVFoundation
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
    }
}
