import AVFoundation
import Foundation

/// Rejects partial/non-video files even when AVAssetWriter happened to leave non-zero bytes.
/// Share/export must expose only an MP4 that AVFoundation can reopen as a real video asset.
enum SplatVideoOutputValidator {
    enum ValidationError: Error, Equatable {
        case missingOrEmpty
        case missingVideoTrack
        case invalidDuration
    }

    static func validate(
        _ url: URL,
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
        guard !tracks.isEmpty else {
            throw ValidationError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        try Task.checkCancellation()
        guard duration.isNumeric,
              duration.seconds.isFinite,
              duration.seconds > 0 else {
            throw ValidationError.invalidDuration
        }
    }
}
