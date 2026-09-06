#if canImport(AVFAudio)
import AVFAudio
import Foundation

@main
struct L3AW27AppleFilePCMChunkSourceSelfTest {
    static func main() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lane3-aw27-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 2
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 8_192
        ), let channelData = buffer.floatChannelData else {
            fatalError("unable to construct AW27 fixture")
        }
        buffer.frameLength = 8_192
        for frame in 0..<8_192 {
            channelData[0][frame] = Float(frame) / 8_192
            channelData[1][frame] = -Float(frame) / 8_192
        }

        let writer = try AVAudioFile(forWriting: url, settings: format.settings)
        try writer.write(from: buffer)
        writer.close()

        let source = try Lane3AppleFilePCMChunkSource(
            fileURL: url,
            maximumFramesPerRead: 4_096
        )
        precondition(source.channels == 2)
        precondition(abs(source.sampleRate - 48_000) < 0.5)
        precondition(source.frameCount == 8_192)
        precondition(source.metadata.processingFormat == "FLOAT32_DEINTERLEAVED")
        precondition(!source.metadata.sourcePathIncluded)
        precondition(!source.metadata.fullTrackPCMArrayRetainedByAdapter)
        precondition(!source.metadata.frameworkDecoderBufferingMeasured)
        precondition(!source.metadata.actualProcessRSSMeasured)
        precondition(!source.metadata.parityPromotionAllowed)

        do {
            _ = try Lane3AppleLongTrackEvidenceInputFactory.openPair(
                referenceFileURL: url,
                observedFileURL: url,
                maximumFramesPerRead: 4_096
            )
            fatalError("insufficient AW26 read budget must fail during preflight")
        } catch Lane3AppleLongTrackEvidenceInputError.readBudgetInsufficient(
            let required,
            let configured
        ) {
            precondition(required == 40_962)
            precondition(configured == 4_096)
        }

        let pair = try Lane3AppleLongTrackEvidenceInputFactory.openPair(
            referenceFileURL: url,
            observedFileURL: url,
            maximumFramesPerRead: 65_536
        )
        precondition(pair.resourceProfile.maximumSingleReadFrames == 40_962)
        precondition(!pair.resourceProfile.actualProcessRSSMeasured)
        precondition(!pair.resourceProfile.fullTrackPCMRetainedByPipeline)

        let first = try source.readInterleavedFrames(startFrame: 0, frameCount: 257)
        precondition(first.count == 514)
        precondition(abs(first[0]) < 1e-7)
        precondition(abs(first[2] - Float(1) / 8_192) < 1e-6)
        precondition(abs(first[3] + Float(1) / 8_192) < 1e-6)

        let middle = try source.readInterleavedFrames(startFrame: 4_096, frameCount: 1_024)
        precondition(middle.count == 2_048)
        precondition(abs(middle[0] - 0.5) < 1e-6)
        precondition(abs(middle[1] + 0.5) < 1e-6)

        let earlier = try source.readInterleavedFrames(startFrame: 2_048, frameCount: 512)
        precondition(earlier.count == 1_024)
        precondition(abs(earlier[0] - 0.25) < 1e-6)
        precondition(abs(earlier[1] + 0.25) < 1e-6)

        do {
            _ = try source.readInterleavedFrames(startFrame: 0, frameCount: 4_097)
            fatalError("oversized Apple read must fail")
        } catch Lane3AppleFilePCMChunkSourceError.policyRejected(
            .readExceedsLimit(let requested, let maximum)
        ) {
            precondition(requested == 4_097 && maximum == 4_096)
        }

        do {
            _ = try source.readInterleavedFrames(startFrame: 8_000, frameCount: 512)
            fatalError("Apple out-of-range read must fail")
        } catch Lane3AppleFilePCMChunkSourceError.policyRejected(
            .invalidReadRange(_, _)
        ) { }

        let zero = try source.readInterleavedFrames(startFrame: 8_192, frameCount: 0)
        precondition(zero.isEmpty)

        let diagnostics = source.diagnosticsSnapshot()
        precondition(diagnostics.successfulReadCalls == 3)
        precondition(diagnostics.zeroLengthReadCalls == 1)
        precondition(diagnostics.initialReads == 1)
        precondition(diagnostics.forwardGapSeeks == 1)
        precondition(diagnostics.backwardSeeks == 1)
        precondition(diagnostics.maximumRequestedFrames == 1_024)
        precondition(!diagnostics.sourcePathIncluded)
        precondition(!diagnostics.counterOverflowed)

        print(
            "L3-AW27 Apple file source PASS reads=\(diagnostics.successfulReadCalls) max=\(diagnostics.maximumRequestedFrames)"
        )
    }
}
#endif
