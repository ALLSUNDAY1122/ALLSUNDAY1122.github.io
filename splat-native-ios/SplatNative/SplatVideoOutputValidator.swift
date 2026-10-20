import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// Rejects partial/non-video files even when AVAssetWriter happened to leave non-zero bytes.
/// Share/export must expose only an MP4 that AVFoundation can reopen as a real video asset.
enum SplatVideoOutputValidator {
    enum ValidationError: Error, Equatable {
        case missingOrEmpty
        case missingVideoTrack
        case unexpectedVideoTrackCount
        case unexpectedAudioTrackCount
        case unexpectedVideoCodec
        case invalidVideoDimensions
        case unexpectedVideoDimensions
        case unexpectedColorProperties
        case invalidDuration
        case unexpectedlyShortDuration
        case undecodableVideoFrame
    }

    struct ProbeWindow: Equatable {
        var start: TimeInterval
        var duration: TimeInterval
    }

    static func leadingProbeWindow(duration: TimeInterval) -> ProbeWindow? {
        guard duration.isFinite, duration > 0 else { return nil }
        return ProbeWindow(start: 0, duration: min(0.5, duration))
    }

    static func boundedProbeWindows(duration: TimeInterval) -> [ProbeWindow] {
        guard duration.isFinite, duration > 1.5 else { return [] }
        let window = min(0.5, duration)
        let centers: [TimeInterval] = duration >= 4 ? [0.25, 0.50, 0.75] : [0.50]
        return centers.map { fraction in
            ProbeWindow(start: max(0, min(duration - window, duration * fraction - window * 0.5)), duration: window)
        }
    }

    static func encodedPixelDimension(_ value: CGFloat) -> Int? {
        guard value.isFinite else { return nil }
        let rounded = abs(value).rounded()
        guard rounded > 0, rounded < CGFloat(Int.max) else { return nil }
        return Int(rounded)
    }

    static func acceptsVideoTrackCount(_ count: Int) -> Bool { count == 1 }
    static func acceptsAudioTrackCount(_ count: Int) -> Bool { count == 0 }
    static func acceptsVideoCodec(_ codec: FourCharCode) -> Bool { codec == kCMVideoCodecType_H264 }

    static func validate(
        _ url: URL,
        expectedDimensions: (width: Int, height: Int)? = nil,
        minimumDuration: TimeInterval? = nil,
        fileManager: FileManager = .default
    ) async throws {
        try Task.checkCancellation()
        guard url.isFileURL,
              fileManager.fileExists(atPath: url.path),
              let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              resourceValues.isRegularFile == true,
              resourceValues.isSymbolicLink != true,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value > 0 else { throw ValidationError.missingOrEmpty }

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        try Task.checkCancellation()
        guard !tracks.isEmpty else { throw ValidationError.missingVideoTrack }
        guard acceptsVideoTrackCount(tracks.count), let videoTrack = tracks.first else {
            throw ValidationError.unexpectedVideoTrackCount
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        try Task.checkCancellation()
        guard acceptsAudioTrackCount(audioTracks.count) else { throw ValidationError.unexpectedAudioTrackCount }

        let naturalSize = try await videoTrack.load(.naturalSize)
        try Task.checkCancellation()
        guard let encodedWidth = encodedPixelDimension(naturalSize.width),
              let encodedHeight = encodedPixelDimension(naturalSize.height) else { throw ValidationError.invalidVideoDimensions }
        if let expectedDimensions {
            guard encodedWidth == expectedDimensions.width, encodedHeight == expectedDimensions.height else {
                throw ValidationError.unexpectedVideoDimensions
            }
        }

        let formatDescriptions: [CMFormatDescription] = try await videoTrack.load(.formatDescriptions)
        try Task.checkCancellation()
        guard !formatDescriptions.isEmpty else { throw ValidationError.unexpectedVideoCodec }
        guard formatDescriptions.allSatisfy({ acceptsVideoCodec(CMFormatDescriptionGetMediaSubType($0)) }) else {
            throw ValidationError.unexpectedVideoCodec
        }
        guard formatDescriptions.allSatisfy({ formatDescription in
            let formatExtensions = formatDescription.extensions
            return formatExtensions[.colorPrimaries] == .colorPrimaries(.itu_R_709_2) &&
                formatExtensions[.transferFunction] == .transferFunction(.itu_R_709_2) &&
                formatExtensions[.yCbCrMatrix] == .yCbCrMatrix(.itu_R_709_2)
        }) else { throw ValidationError.unexpectedColorProperties }

        let duration = try await asset.load(.duration)
        try Task.checkCancellation()
        guard duration.isNumeric, duration.seconds.isFinite, duration.seconds > 0 else { throw ValidationError.invalidDuration }
        if let minimumDuration {
            guard minimumDuration.isFinite, minimumDuration >= 0, duration.seconds >= minimumDuration else {
                throw ValidationError.unexpectedlyShortDuration
            }
        }

        try Task.checkCancellation()
        guard let leadingWindow = leadingProbeWindow(duration: duration.seconds) else { throw ValidationError.invalidDuration }
        try validateDecodedFrames(asset: asset, track: videoTrack, encodedWidth: encodedWidth, encodedHeight: encodedHeight,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: max(0.001, leadingWindow.duration), preferredTimescale: 600)), drainRange: true)
        try Task.checkCancellation()

        for window in boundedProbeWindows(duration: duration.seconds) {
            try validateDecodedFrames(asset: asset, track: videoTrack, encodedWidth: encodedWidth, encodedHeight: encodedHeight,
                timeRange: CMTimeRange(start: CMTime(seconds: window.start, preferredTimescale: 600), duration: CMTime(seconds: max(0.001, window.duration), preferredTimescale: 600)), drainRange: true)
            try Task.checkCancellation()
        }

        let tailWindowSeconds = min(0.5, duration.seconds)
        let tailStartSeconds = max(0, duration.seconds - tailWindowSeconds)
        try validateDecodedFrames(asset: asset, track: videoTrack, encodedWidth: encodedWidth, encodedHeight: encodedHeight,
            timeRange: CMTimeRange(start: CMTime(seconds: tailStartSeconds, preferredTimescale: 600), duration: CMTime(seconds: max(0.001, duration.seconds - tailStartSeconds), preferredTimescale: 600)), drainRange: true)
        try Task.checkCancellation()
    }

    private static func validateDecodedFrames(asset: AVAsset, track: AVAssetTrack, encodedWidth: Int, encodedHeight: Int,
        timeRange: CMTimeRange?, drainRange: Bool) throws {
        let reader = try AVAssetReader(asset: asset)
        if let timeRange { reader.timeRange = timeRange }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ValidationError.undecodableVideoFrame }
        reader.add(output)
        guard reader.startReading() else { throw ValidationError.undecodableVideoFrame }
        defer { reader.cancelReading() }

        var decodedFrameCount = 0
        while let frame = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let imageBuffer = CMSampleBufferGetImageBuffer(frame) else { throw ValidationError.undecodableVideoFrame }
            let decodedWidth = CVPixelBufferGetWidth(imageBuffer)
            let decodedHeight = CVPixelBufferGetHeight(imageBuffer)
            guard decodedWidth > 0, decodedHeight > 0, decodedWidth == encodedWidth, decodedHeight == encodedHeight else {
                throw ValidationError.undecodableVideoFrame
            }
            decodedFrameCount += 1
            if !drainRange { break }
        }
        guard decodedFrameCount > 0 else { throw ValidationError.undecodableVideoFrame }
        if drainRange, reader.status != .completed { throw ValidationError.undecodableVideoFrame }
    }
}
