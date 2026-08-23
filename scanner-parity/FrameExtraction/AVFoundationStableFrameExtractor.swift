#if canImport(AVFoundation) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum StableFrameExtractionError: LocalizedError {
    case noVideoTrack
    case cannotAddReaderOutput
    case readerStartFailed(String)
    case readerFailed(String)
    case unsupportedPixelFormat(OSType)
    case missingPixelBuffer
    case imageDestinationCreationFailed(URL)
    case imageWriteFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "動画トラックを取得できませんでした。"
        case .cannotAddReaderOutput: return "動画フレームのReader Outputを追加できませんでした。"
        case .readerStartFailed(let detail): return "動画の読み込みを開始できませんでした: \(detail)"
        case .readerFailed(let detail): return "動画フレームの解析に失敗しました: \(detail)"
        case .unsupportedPixelFormat(let format): return "未対応のPixel Formatです: \(format)"
        case .missingPixelBuffer: return "動画サンプルからPixel Bufferを取得できませんでした。"
        case .imageDestinationCreationFailed(let url): return "JPEG出力先を作成できませんでした: \(url.lastPathComponent)"
        case .imageWriteFailed(let url): return "JPEGを書き出せませんでした: \(url.lastPathComponent)"
        }
    }
}

public struct AVFoundationStableFrameExtractor: Sendable {
    public let configuration: FrameExtractionConfiguration

    public init(configuration: FrameExtractionConfiguration = .init()) {
        self.configuration = configuration
    }

    public func extract(videoURL: URL, outputDirectory: URL, bookID: String) async throws -> [PageCandidate] {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw StableFrameExtractionError.noVideoTrack }

        let selections = try analyze(asset: asset, track: track)
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let candidates = try export(selections: selections, from: asset, to: outputDirectory, bookID: bookID)
        try writeCandidateManifest(candidates, to: outputDirectory)
        return candidates
    }

    private func analyze(asset: AVAsset, track: AVAssetTrack) throws -> [StableFrameSelection] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw StableFrameExtractionError.cannotAddReaderOutput }
        reader.add(output)
        guard reader.startReading() else {
            throw StableFrameExtractionError.readerStartFailed(reader.error?.localizedDescription ?? "unknown")
        }

        let analysisIntervalMS = Int64((1000.0 / max(1, configuration.analysisFramesPerSecond)).rounded())
        var lastAnalyzedMS: Int64?
        var previousThumbnail: LumaThumbnail?
        var selector = IncrementalStableFrameSelector(configuration: configuration)

        while let sample = output.copyNextSampleBuffer() {
            if Task.isCancelled {
                reader.cancelReading()
                break
            }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sample)
            let seconds = CMTimeGetSeconds(timestamp)
            guard seconds.isFinite, seconds >= 0 else { continue }
            let timestampMS = Int64((seconds * 1000).rounded())
            if let lastAnalyzedMS, timestampMS - lastAnalyzedMS < analysisIntervalMS { continue }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                throw StableFrameExtractionError.missingPixelBuffer
            }
            let thumbnail = try LumaThumbnail.make(
                fromBGRA: pixelBuffer,
                targetWidth: configuration.thumbnailWidth,
                targetHeight: configuration.thumbnailHeight
            )
            let motion = previousThumbnail.map { thumbnail.meanAbsoluteDifference(to: $0) } ?? 0
            selector.consume(
                AnalyzedFrame(
                    timestampMS: timestampMS,
                    thumbnail: thumbnail,
                    motionScore: motion,
                    sharpnessScore: thumbnail.sharpnessScore()
                )
            )
            previousThumbnail = thumbnail
            lastAnalyzedMS = timestampMS
        }

        if reader.status == .failed {
            throw StableFrameExtractionError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }
        return selector.finish()
    }

    private func export(selections: [StableFrameSelection], from asset: AVAsset, to outputDirectory: URL, bookID: String) throws -> [PageCandidate] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)

        var candidates: [PageCandidate] = []
        candidates.reserveCapacity(selections.count)
        for (index, selection) in selections.enumerated() {
            try Task.checkCancellation()
            let filename = String(format: "candidate-%04d.jpg", index + 1)
            let imageURL = outputDirectory.appendingPathComponent(filename)
            let requestedTime = CMTime(seconds: Double(selection.sourceTimeMS) / 1000, preferredTimescale: 600)
            var actualTime = CMTime.invalid
            let image = try generator.copyCGImage(at: requestedTime, actualTime: &actualTime)
            try Self.writeJPEG(image, to: imageURL)

            let actualSeconds = CMTimeGetSeconds(actualTime)
            let actualMS = actualSeconds.isFinite ? Int64((actualSeconds * 1000).rounded()) : selection.sourceTimeMS
            var flags = selection.flags
            if abs(actualMS - selection.sourceTimeMS) > 34 { flags.append("export-time-adjusted") }

            candidates.append(PageCandidate(
                candidateID: String(format: "%@-candidate-%04d", bookID, index + 1),
                bookID: bookID,
                sourceTimeMS: actualMS,
                sourceRangeMS: selection.sourceRangeMS,
                imageRef: imageURL.path,
                stabilityScore: selection.stabilityScore,
                sharpnessScore: selection.sharpnessScore,
                motionScore: selection.motionScore,
                duplicateGroupID: selection.duplicateGroupID,
                flags: flags
            ))
        }
        return candidates
    }

    private func writeCandidateManifest(_ candidates: [PageCandidate], to outputDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(candidates).write(
            to: outputDirectory.appendingPathComponent("page_candidates.json"),
            options: .atomic
        )
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw StableFrameExtractionError.imageDestinationCreationFailed(url)
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw StableFrameExtractionError.imageWriteFailed(url) }
    }
}

private extension LumaThumbnail {
    static func make(fromBGRA pixelBuffer: CVPixelBuffer, targetWidth: Int, targetHeight: Int) throws -> LumaThumbnail {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_32BGRA else { throw StableFrameExtractionError.unsupportedPixelFormat(format) }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { throw StableFrameExtractionError.missingPixelBuffer }

        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = max(9, min(max(9, targetWidth), sourceWidth))
        let height = max(8, min(max(8, targetHeight), sourceHeight))
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)

        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height)
        for row in 0..<height {
            let sourceY = min(sourceHeight - 1, row * sourceHeight / height)
            for column in 0..<width {
                let sourceX = min(sourceWidth - 1, column * sourceWidth / width)
                let offset = sourceY * bytesPerRow + sourceX * 4
                let blue = Int(bytes[offset])
                let green = Int(bytes[offset + 1])
                let red = Int(bytes[offset + 2])
                pixels.append(UInt8(clamping: (77 * red + 150 * green + 29 * blue) >> 8))
            }
        }
        return LumaThumbnail(width: width, height: height, pixels: pixels)
    }
}
#endif
