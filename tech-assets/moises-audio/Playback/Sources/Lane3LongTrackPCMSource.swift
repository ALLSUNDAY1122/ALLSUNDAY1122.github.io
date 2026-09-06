import Foundation

public enum Lane3LongTrackEvidenceError: Error, Equatable, Sendable {
    case invalidFormat
    case sampleRateMismatch(expected: Double, actual: Double)
    case channelMismatch(expected: Int, actual: Int)
    case invalidChunkFrames(Int)
    case frameRangeOutOfBounds(start: Int64, count: Int)
    case shortRead(expectedSamples: Int, actualSamples: Int)
    case integerOverflow
    case invalidConfiguration
    case eventFrameOutOfBounds(Int64)
    case insufficientComparableFrames
    case sourceReadFailed(String)
    case invalidProductionGenerationReceipt
    case invalidRecoveryLineageReceipt
    case generationLineageMismatch
    case reasonLineageMismatch
    case sourceEvidenceScopeRejected(String)
    case componentClaimRejected
    case noEnvelopeWindows
    case nonFiniteEvidence(reference: Int64, observed: Int64)
    case invalidMetric
}

/// Random-access PCM boundary for long-track evidence. Implementations may be backed by an
/// in-memory buffer, a file decoder, or another bounded reader. Each call returns exactly the
/// requested interleaved Float32 frames; durable evidence stores only digests/metrics, never PCM.
public protocol Lane3PCMChunkReadable: Sendable {
    var channels: Int { get }
    var sampleRate: Double { get }
    var frameCount: Int64 { get }
    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float]
}

public struct Lane3ArrayPCMChunkSource: Lane3PCMChunkReadable, Sendable {
    public let descriptor: Lane3PCMBufferDescriptor

    public init(_ descriptor: Lane3PCMBufferDescriptor) {
        self.descriptor = descriptor
    }

    public var channels: Int { descriptor.channels }
    public var sampleRate: Double { descriptor.sampleRate }
    public var frameCount: Int64 { descriptor.frameCount }

    public func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        guard frameCount >= 0, startFrame >= 0 else {
            throw Lane3LongTrackEvidenceError.frameRangeOutOfBounds(start: startFrame, count: frameCount)
        }
        let end = startFrame.addingReportingOverflow(Int64(frameCount))
        guard !end.overflow, end.partialValue <= descriptor.frameCount else {
            throw Lane3LongTrackEvidenceError.frameRangeOutOfBounds(start: startFrame, count: frameCount)
        }
        let startSamples = startFrame.multipliedReportingOverflow(by: Int64(channels))
        let sampleCount = Int64(frameCount).multipliedReportingOverflow(by: Int64(channels))
        guard !startSamples.overflow, !sampleCount.overflow,
              startSamples.partialValue >= 0, sampleCount.partialValue >= 0,
              startSamples.partialValue <= Int64(Int.max),
              sampleCount.partialValue <= Int64(Int.max) else {
            throw Lane3LongTrackEvidenceError.integerOverflow
        }
        let start = Int(startSamples.partialValue)
        let count = Int(sampleCount.partialValue)
        let finish = start.addingReportingOverflow(count)
        guard !finish.overflow, finish.partialValue <= descriptor.interleavedSamples.count else {
            throw Lane3LongTrackEvidenceError.integerOverflow
        }
        return Array(descriptor.interleavedSamples[start..<finish.partialValue])
    }
}

/// Convenience source for HQ/file adapters without exposing file paths to durable evidence.
public struct Lane3ClosurePCMChunkSource: Lane3PCMChunkReadable, @unchecked Sendable {
    public let channels: Int
    public let sampleRate: Double
    public let frameCount: Int64
    private let reader: @Sendable (Int64, Int) throws -> [Float]

    public init(
        channels: Int,
        sampleRate: Double,
        frameCount: Int64,
        reader: @escaping @Sendable (Int64, Int) throws -> [Float]
    ) {
        self.channels = channels
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.reader = reader
    }

    public func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        try reader(startFrame, frameCount)
    }
}

public struct Lane3LongTrackEvidenceResourceProfile: Equatable, Codable, Sendable {
    public let chunkFrames: Int
    public let channels: Int
    public let maximumSingleReadFrames: Int
    public let maximumSingleReadInterleavedFloatCount: Int
    public let approximateMaximumSingleReadBytes: Int
    public let estimatedMajorAnalysisBufferBytesUpperBound: Int
    public let fullTrackPCMRetainedByPipeline: Bool
    public let actualProcessRSSMeasured: Bool
    public let parityPromotionAllowed: Bool
}

public struct Lane3LongTrackUnifiedEvidenceResult: Equatable, Codable, Sendable {
    public let reportV2: Lane3UnifiedEvidenceReportV2
    public let resourceProfile: Lane3LongTrackEvidenceResourceProfile
    public let parityPromotionAllowed: Bool
}

public enum Lane3LongTrackEvidenceResourcePlanner {
    public static func profile(
        channels: Int,
        chunkFrames: Int = 16_384,
        timeConfiguration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        spectralConfiguration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration(),
        envelopeConfiguration: Lane3CepstralEnvelopeConfiguration = Lane3CepstralEnvelopeConfiguration()
    ) throws -> Lane3LongTrackEvidenceResourceProfile {
        guard channels > 0 else { throw Lane3LongTrackEvidenceError.invalidFormat }
        guard chunkFrames > 0 else { throw Lane3LongTrackEvidenceError.invalidChunkFrames(chunkFrames) }
        let maximumSingleReadFrames = max(
            chunkFrames,
            timeConfiguration.alignmentWindowFrames + timeConfiguration.maximumAlignmentLagFrames * 2 + 2,
            timeConfiguration.localWindowFrames + timeConfiguration.localDriftSearchFrames * 2 + 2,
            timeConfiguration.onsetSearchRadiusFrames * 2 + 2,
            spectralConfiguration.windowSize,
            envelopeConfiguration.windowSize
        )
        let floats64 = Int64(maximumSingleReadFrames).multipliedReportingOverflow(by: Int64(channels))
        guard !floats64.overflow, floats64.partialValue <= Int64(Int.max) else { throw Lane3LongTrackEvidenceError.integerOverflow }
        let floats = Int(floats64.partialValue)
        let bytes = floats.multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
        guard !bytes.overflow else { throw Lane3LongTrackEvidenceError.integerOverflow }
        let pairInterleaved = bytes.partialValue.multipliedReportingOverflow(by: 2)
        let monoPair64 = Int64(maximumSingleReadFrames).multipliedReportingOverflow(by: 16)
        let spectralBins = spectralConfiguration.windowSize / 2 + 1
        let spectralValues64 = Int64(spectralConfiguration.maximumWindows).multipliedReportingOverflow(by: Int64(spectralBins))
        guard !pairInterleaved.overflow, !monoPair64.overflow, !spectralValues64.overflow else { throw Lane3LongTrackEvidenceError.integerOverflow }
        let spectraPair64 = spectralValues64.partialValue.multipliedReportingOverflow(by: 16)
        let spectralAggregate64 = Int64(spectralBins).multipliedReportingOverflow(by: 16)
        let envelopeBins = max(0, envelopeConfiguration.windowSize / 2 + 1)
        let envelopeAggregate64 = Int64(envelopeBins).multipliedReportingOverflow(by: 16)
        guard !spectraPair64.overflow, !spectralAggregate64.overflow, !envelopeAggregate64.overflow else { throw Lane3LongTrackEvidenceError.integerOverflow }
        let major64 = Int64(pairInterleaved.partialValue)
            .addingReportingOverflow(monoPair64.partialValue)
        guard !major64.overflow else { throw Lane3LongTrackEvidenceError.integerOverflow }
        let major2 = major64.partialValue.addingReportingOverflow(spectraPair64.partialValue)
        let major3 = major2.partialValue.addingReportingOverflow(spectralAggregate64.partialValue)
        let major4 = major3.partialValue.addingReportingOverflow(envelopeAggregate64.partialValue)
        guard !major2.overflow, !major3.overflow, !major4.overflow, major4.partialValue <= Int64(Int.max) else { throw Lane3LongTrackEvidenceError.integerOverflow }
        return Lane3LongTrackEvidenceResourceProfile(
            chunkFrames: chunkFrames,
            channels: channels,
            maximumSingleReadFrames: maximumSingleReadFrames,
            maximumSingleReadInterleavedFloatCount: floats,
            approximateMaximumSingleReadBytes: bytes.partialValue,
            estimatedMajorAnalysisBufferBytesUpperBound: Int(major4.partialValue),
            fullTrackPCMRetainedByPipeline: false,
            actualProcessRSSMeasured: false,
            parityPromotionAllowed: false
        )
    }
}

struct Lane3LongTrackPCMMetadata: Equatable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64
}

enum Lane3LongTrackPCMAccess {
    static func validatePair(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        chunkFrames: Int
    ) throws -> Lane3LongTrackPCMMetadata {
        guard chunkFrames > 0 else { throw Lane3LongTrackEvidenceError.invalidChunkFrames(chunkFrames) }
        for source in [reference, observed] {
            guard source.channels > 0,
                  source.sampleRate.isFinite, source.sampleRate > 0,
                  source.frameCount > 0 else {
                throw Lane3LongTrackEvidenceError.invalidFormat
            }
        }
        guard reference.channels == observed.channels else {
            throw Lane3LongTrackEvidenceError.channelMismatch(expected: reference.channels, actual: observed.channels)
        }
        guard abs(reference.sampleRate - observed.sampleRate) <= 0.5 else {
            throw Lane3LongTrackEvidenceError.sampleRateMismatch(expected: reference.sampleRate, actual: observed.sampleRate)
        }
        return Lane3LongTrackPCMMetadata(
            channels: reference.channels,
            sampleRate: reference.sampleRate,
            frameCount: reference.frameCount
        )
    }

    static func readInterleaved(
        _ source: any Lane3PCMChunkReadable,
        start: Int64,
        count: Int
    ) throws -> [Float] {
        guard count >= 0, start >= 0 else {
            throw Lane3LongTrackEvidenceError.frameRangeOutOfBounds(start: start, count: count)
        }
        let end = start.addingReportingOverflow(Int64(count))
        guard !end.overflow, end.partialValue <= source.frameCount else {
            throw Lane3LongTrackEvidenceError.frameRangeOutOfBounds(start: start, count: count)
        }
        let expected64 = Int64(count).multipliedReportingOverflow(by: Int64(source.channels))
        guard !expected64.overflow, expected64.partialValue <= Int64(Int.max) else {
            throw Lane3LongTrackEvidenceError.integerOverflow
        }
        let expected = Int(expected64.partialValue)
        do {
            let result = try source.readInterleavedFrames(startFrame: start, frameCount: count)
            guard result.count == expected else {
                throw Lane3LongTrackEvidenceError.shortRead(expectedSamples: expected, actualSamples: result.count)
            }
            return result
        } catch let error as Lane3LongTrackEvidenceError {
            throw error
        } catch {
            throw Lane3LongTrackEvidenceError.sourceReadFailed(String(describing: error))
        }
    }

    static func readMono(
        _ source: any Lane3PCMChunkReadable,
        start: Int64,
        count: Int
    ) throws -> (samples: [Double], nonFinite: Int64) {
        let interleaved = try readInterleaved(source, start: start, count: count)
        var mono = [Double](repeating: 0, count: count)
        var nonFinite: Int64 = 0
        let channels = source.channels
        for frame in 0..<count {
            var sum = 0.0
            var finiteCount = 0
            let base = frame * channels
            for channel in 0..<channels {
                let value = Double(interleaved[base + channel])
                if value.isFinite {
                    sum += value
                    finiteCount += 1
                } else {
                    nonFinite += 1
                }
            }
            mono[frame] = finiteCount > 0 ? sum / Double(finiteCount) : 0
        }
        return (mono, nonFinite)
    }

    static func scanSampleHealth(
        _ source: any Lane3PCMChunkReadable,
        chunkFrames: Int
    ) throws -> (clipped: Int64, nonFinite: Int64) {
        var clipped: Int64 = 0
        var nonFinite: Int64 = 0
        var frame: Int64 = 0
        while frame < source.frameCount {
            let count = min(chunkFrames, Int(source.frameCount - frame))
            let samples = try readInterleaved(source, start: frame, count: count)
            for sample in samples {
                let value = Double(sample)
                if !value.isFinite { nonFinite += 1 }
                else if abs(value) > 1 { clipped += 1 }
            }
            frame += Int64(count)
        }
        return (clipped, nonFinite)
    }

    static func countNonFinite(
        _ source: any Lane3PCMChunkReadable,
        chunkFrames: Int
    ) throws -> Int64 {
        var nonFinite: Int64 = 0
        var frame: Int64 = 0
        while frame < source.frameCount {
            let count = min(chunkFrames, Int(source.frameCount - frame))
            let samples = try readInterleaved(source, start: frame, count: count)
            for sample in samples where !Double(sample).isFinite { nonFinite += 1 }
            frame += Int64(count)
        }
        return nonFinite
    }
}
