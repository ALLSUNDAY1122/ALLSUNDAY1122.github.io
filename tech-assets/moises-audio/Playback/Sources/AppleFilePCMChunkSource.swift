#if canImport(AVFAudio)
import AVFAudio
import Foundation

public enum Lane3AppleFilePCMChunkSourceError: Error, Equatable, Sendable {
    case openFailed
    case invalidProcessingFormat
    case emptySource
    case sourceClosed
    case sourceMetadataChanged
    case sourceIdentityUnavailable
    case sourceIdentityChanged
    case policyRejected(Lane3PCMChunkReadPolicyError)
    case bufferAllocationFailed
    case seekFailed
    case readFailed
    case shortRead(expectedFrames: Int, actualFrames: Int)
    case pcmAccessUnavailable
    case positionMismatch(expected: Int64, actual: Int64)
}

public struct Lane3AppleFilePCMChunkSourceMetadata: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let channels: Int
    public let sampleRate: Double
    public let frameCount: Int64
    public let maximumFramesPerRead: Int
    public let processingFormat: String
    public let sourcePathIncluded: Bool
    public let fullTrackPCMArrayRetainedByAdapter: Bool
    public let frameworkDecoderBufferingMeasured: Bool
    public let actualProcessRSSMeasured: Bool
    public let parityPromotionAllowed: Bool
}

/// Read-only AVAudioFile adapter for AW26 long-track evidence. The source opens the file in
/// deinterleaved Float32 processing format and serializes random-access seek/read operations.
/// Adapter-owned allocations are bounded to one AVAudioPCMBuffer plus the returned interleaved
/// array per read. AVFAudio internal buffering/RSS remains a physical-device measurement concern.
/// The local file URL is intentionally never included in public metadata or diagnostic receipts.
public final class Lane3AppleFilePCMChunkSource: Lane3PCMChunkReadable, @unchecked Sendable {
    public let channels: Int
    public let sampleRate: Double
    public let frameCount: Int64
    public let maximumFramesPerRead: Int

    private let file: AVAudioFile
    private let sourceURL: URL
    private let expectedSourceIdentity: Lane3FileSourceIdentitySnapshot
    private let policy: Lane3PCMChunkReadPolicy
    private let lock = NSLock()
    private let expectedSampleRateBitPattern: UInt64
    private let expectedChannelCount: AVAudioChannelCount
    private var audit = Lane3PCMChunkReadAudit()

    public init(
        fileURL: URL,
        maximumFramesPerRead: Int = 65_536
    ) throws {
        let policy: Lane3PCMChunkReadPolicy
        do {
            policy = try Lane3PCMChunkReadPolicy(maximumFramesPerRead: maximumFramesPerRead)
        } catch let error as Lane3PCMChunkReadPolicyError {
            throw Lane3AppleFilePCMChunkSourceError.policyRejected(error)
        }

        let identityBeforeOpen: Lane3FileSourceIdentitySnapshot
        do {
            identityBeforeOpen = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        } catch {
            throw Lane3AppleFilePCMChunkSourceError.sourceIdentityUnavailable
        }

        let opened: AVAudioFile
        do {
            opened = try AVAudioFile(
                forReading: fileURL,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw Lane3AppleFilePCMChunkSourceError.openFailed
        }

        let identityAfterOpen: Lane3FileSourceIdentitySnapshot
        do {
            identityAfterOpen = try Lane3FileSourceIdentityFence.capture(fileURL: fileURL)
        } catch {
            throw Lane3AppleFilePCMChunkSourceError.sourceIdentityUnavailable
        }
        guard identityAfterOpen == identityBeforeOpen else {
            throw Lane3AppleFilePCMChunkSourceError.sourceIdentityChanged
        }

        let format = opened.processingFormat
        guard format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved,
              format.channelCount > 0,
              format.sampleRate.isFinite,
              format.sampleRate > 0 else {
            throw Lane3AppleFilePCMChunkSourceError.invalidProcessingFormat
        }
        guard opened.length > 0 else {
            throw Lane3AppleFilePCMChunkSourceError.emptySource
        }

        self.file = opened
        self.sourceURL = fileURL
        self.expectedSourceIdentity = identityAfterOpen
        self.policy = policy
        self.channels = Int(format.channelCount)
        self.sampleRate = format.sampleRate
        self.frameCount = Int64(opened.length)
        self.maximumFramesPerRead = maximumFramesPerRead
        self.expectedSampleRateBitPattern = format.sampleRate.bitPattern
        self.expectedChannelCount = format.channelCount
    }

    public var metadata: Lane3AppleFilePCMChunkSourceMetadata {
        Lane3AppleFilePCMChunkSourceMetadata(
            schemaVersion: 1,
            evidenceScope: "LANE3_APPLE_FILE_PCM_CHUNK_SOURCE_NON_PARITY",
            channels: channels,
            sampleRate: sampleRate,
            frameCount: frameCount,
            maximumFramesPerRead: maximumFramesPerRead,
            processingFormat: "FLOAT32_DEINTERLEAVED",
            sourcePathIncluded: false,
            fullTrackPCMArrayRetainedByAdapter: false,
            frameworkDecoderBufferingMeasured: false,
            actualProcessRSSMeasured: false,
            parityPromotionAllowed: false
        )
    }

    public func diagnosticsSnapshot() -> Lane3PCMChunkReadAuditSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return audit.snapshot()
    }

    public func readInterleavedFrames(
        startFrame: Int64,
        frameCount requestedFrames: Int
    ) throws -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let expectedSamples: Int
        do {
            expectedSamples = try policy.expectedInterleavedSampleCount(
                startFrame: startFrame,
                frameCount: requestedFrames,
                totalFrames: self.frameCount,
                channels: channels
            )
        } catch let error as Lane3PCMChunkReadPolicyError {
            throw Lane3AppleFilePCMChunkSourceError.policyRejected(error)
        }

        if requestedFrames == 0 {
            audit.recordSuccessfulRead(startFrame: startFrame, frameCount: 0)
            return []
        }

        try validateStableSource()

        let appleFrameCount = AVAudioFrameCount(requestedFrames)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: appleFrameCount
        ) else {
            throw Lane3AppleFilePCMChunkSourceError.bufferAllocationFailed
        }

        file.framePosition = AVAudioFramePosition(startFrame)
        guard Int64(file.framePosition) == startFrame else {
            try validateStableSource()
            throw Lane3AppleFilePCMChunkSourceError.seekFailed
        }

        do {
            try file.read(into: buffer, frameCount: appleFrameCount)
        } catch {
            // Prefer a deterministic source-identity/metadata failure over a generic decoder failure
            // when the backing file changed while AVFAudio was reading it.
            try validateStableSource()
            throw Lane3AppleFilePCMChunkSourceError.readFailed
        }

        // AW49: the AVAudioFile instance itself is immutable in this adapter, but the filesystem
        // object at its URL can still be atomically replaced or modified in place. Revalidate after
        // every decoder read so one long evidence traversal cannot silently mix file generations.
        try validateStableSource()

        let actualFrames = Int(buffer.frameLength)
        guard actualFrames == requestedFrames else {
            throw Lane3AppleFilePCMChunkSourceError.shortRead(
                expectedFrames: requestedFrames,
                actualFrames: actualFrames
            )
        }

        let expectedEnd = startFrame + Int64(requestedFrames)
        guard Int64(file.framePosition) == expectedEnd else {
            throw Lane3AppleFilePCMChunkSourceError.positionMismatch(
                expected: expectedEnd,
                actual: Int64(file.framePosition)
            )
        }

        guard buffer.format.commonFormat == .pcmFormatFloat32,
              !buffer.format.isInterleaved,
              buffer.stride == 1,
              let channelData = buffer.floatChannelData else {
            throw Lane3AppleFilePCMChunkSourceError.pcmAccessUnavailable
        }

        var output = [Float](repeating: 0, count: expectedSamples)
        for frame in 0..<requestedFrames {
            let outputBase = frame * channels
            for channel in 0..<channels {
                output[outputBase + channel] = channelData[channel][frame]
            }
        }

        audit.recordSuccessfulRead(startFrame: startFrame, frameCount: requestedFrames)
        return output
    }

    private func validateStableSource() throws {
        guard file.isOpen else {
            throw Lane3AppleFilePCMChunkSourceError.sourceClosed
        }
        do {
            try Lane3FileSourceIdentityFence.requireUnchanged(
                fileURL: sourceURL,
                expected: expectedSourceIdentity
            )
        } catch let error as Lane3FileSourceIdentityFenceError {
            switch error {
            case .changed:
                throw Lane3AppleFilePCMChunkSourceError.sourceIdentityChanged
            case .unavailable, .notRegularFile:
                throw Lane3AppleFilePCMChunkSourceError.sourceIdentityUnavailable
            }
        } catch {
            throw Lane3AppleFilePCMChunkSourceError.sourceIdentityUnavailable
        }

        let format = file.processingFormat
        guard Int64(file.length) == frameCount,
              format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved,
              format.channelCount == expectedChannelCount,
              format.sampleRate.bitPattern == expectedSampleRateBitPattern else {
            throw Lane3AppleFilePCMChunkSourceError.sourceMetadataChanged
        }
    }
}
#endif
