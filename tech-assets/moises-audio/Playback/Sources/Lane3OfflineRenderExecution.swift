import Foundation

public enum Lane3OfflineExecutionError: Error, Equatable, Sendable {
    case planDoesNotMatchRequest
    case duplicateStemMetadata(String)
    case missingStemMetadata(String)
    case unexpectedStemMetadata(String)
    case invalidStemMetadata(String)
    case sourceSampleRateMismatch(stemID: String, expected: Double, actual: Double)
    case sourceFrameCountDeltaExceeded(stemID: String, expected: Int64, actual: Int64, maximumDelta: Int64)
    case sourceWindowOutOfBounds(stemID: String)
    case renderWindowOutOfBounds(stemID: String)
    case clickPCMRequired
    case invalidClickPCMFormat
    case invalidFrameCountTolerance(Int64)
    case invalidPCMChunk
    case pcmAccumulatorOverflow
}

public struct Lane3OfflinePCMFormatDescriptor: Equatable, Codable, Sendable {
    public let sampleRate: Double
    public let channels: Int

    public init(sampleRate: Double, channels: Int) {
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

public struct Lane3OfflineStemFileMetadata: Equatable, Codable, Sendable {
    public let stemID: String
    public let sampleRate: Double
    public let frameCount: Int64
    public let channels: Int

    public init(stemID: String, sampleRate: Double, frameCount: Int64, channels: Int) {
        self.stemID = stemID
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.channels = channels
    }
}

public struct Lane3PCMExecutionDigest: Equatable, Codable, Sendable {
    public let frameCount: Int64
    public let firstNonSilentFrame: Int64?
    public let lastNonSilentFrame: Int64?
    public let clippedSampleCount: Int64
    public let sampleFingerprintFNV1A64: String

    public init(
        frameCount: Int64,
        firstNonSilentFrame: Int64?,
        lastNonSilentFrame: Int64?,
        clippedSampleCount: Int64,
        sampleFingerprintFNV1A64: String
    ) {
        self.frameCount = frameCount
        self.firstNonSilentFrame = firstNonSilentFrame
        self.lastNonSilentFrame = lastNonSilentFrame
        self.clippedSampleCount = clippedSampleCount
        self.sampleFingerprintFNV1A64 = sampleFingerprintFNV1A64
    }
}

public struct Lane3OfflineExecutionManifest: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let fixtureID: String
    public let controlSignatureFNV1A64: String
    public let outputSampleRate: Double
    public let outputFrameCount: Int64
    public let expectedStemIDs: [String]
    public let renderWindowCount: Int
    public let clickEventCount: Int
    public let requiresClickPCM: Bool
    public let parityPromotionAllowed: Bool

    public init(
        fixtureID: String,
        controlSignatureFNV1A64: String,
        outputSampleRate: Double,
        outputFrameCount: Int64,
        expectedStemIDs: [String],
        renderWindowCount: Int,
        clickEventCount: Int,
        requiresClickPCM: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_APPLE_OFFLINE_PCM_EXECUTION_NON_PARITY"
        self.fixtureID = fixtureID
        self.controlSignatureFNV1A64 = controlSignatureFNV1A64
        self.outputSampleRate = outputSampleRate
        self.outputFrameCount = outputFrameCount
        self.expectedStemIDs = expectedStemIDs
        self.renderWindowCount = renderWindowCount
        self.clickEventCount = clickEventCount
        self.requiresClickPCM = requiresClickPCM
        self.parityPromotionAllowed = false
    }
}

/// Portable preflight used by the Apple manual-rendering adapter. It validates the exact file
/// metadata against the deterministic request/plan before AVAudioEngine graph mutation begins.
public enum Lane3OfflineExecutionValidator {
    public static func makeManifest(
        request: Lane3ReferenceRenderRequest,
        plan: Lane3ReferenceRenderPlan,
        stemMetadata: [Lane3OfflineStemFileMetadata],
        clickPCMFormat: Lane3OfflinePCMFormatDescriptor?,
        maximumFrameCountDelta: Int64 = 2_048
    ) throws -> Lane3OfflineExecutionManifest {
        guard maximumFrameCountDelta >= 0 else {
            throw Lane3OfflineExecutionError.invalidFrameCountTolerance(maximumFrameCountDelta)
        }
        guard try Lane3OfflineReferencePlanner.makePlan(request) == plan else {
            throw Lane3OfflineExecutionError.planDoesNotMatchRequest
        }

        var metadataByID: [String: Lane3OfflineStemFileMetadata] = [:]
        metadataByID.reserveCapacity(stemMetadata.count)
        for metadata in stemMetadata {
            guard !metadata.stemID.isEmpty,
                  metadata.sampleRate.isFinite,
                  metadata.sampleRate > 0,
                  metadata.frameCount > 0,
                  metadata.channels > 0 else {
                throw Lane3OfflineExecutionError.invalidStemMetadata(metadata.stemID)
            }
            guard metadataByID.updateValue(metadata, forKey: metadata.stemID) == nil else {
                throw Lane3OfflineExecutionError.duplicateStemMetadata(metadata.stemID)
            }
        }

        let descriptorIDs = Set(request.stems.map(\.id))
        for metadataID in metadataByID.keys where !descriptorIDs.contains(metadataID) {
            throw Lane3OfflineExecutionError.unexpectedStemMetadata(metadataID)
        }

        for descriptor in request.stems {
            guard let metadata = metadataByID[descriptor.id] else {
                throw Lane3OfflineExecutionError.missingStemMetadata(descriptor.id)
            }
            guard abs(metadata.sampleRate - descriptor.sampleRate) <= 0.5 else {
                throw Lane3OfflineExecutionError.sourceSampleRateMismatch(
                    stemID: descriptor.id,
                    expected: descriptor.sampleRate,
                    actual: metadata.sampleRate
                )
            }
            let delta = absoluteDifference(metadata.frameCount, descriptor.frameCount)
            guard delta <= UInt64(maximumFrameCountDelta) else {
                throw Lane3OfflineExecutionError.sourceFrameCountDeltaExceeded(
                    stemID: descriptor.id,
                    expected: descriptor.frameCount,
                    actual: metadata.frameCount,
                    maximumDelta: maximumFrameCountDelta
                )
            }
        }

        for window in plan.stemWindows {
            guard let metadata = metadataByID[window.stemID] else {
                throw Lane3OfflineExecutionError.missingStemMetadata(window.stemID)
            }
            guard window.sourceStartFrame >= 0,
                  window.sourceFrameCount > 0,
                  addingFits(window.sourceStartFrame, window.sourceFrameCount, upperBound: metadata.frameCount) else {
                throw Lane3OfflineExecutionError.sourceWindowOutOfBounds(stemID: window.stemID)
            }
            guard window.renderStartFrame >= 0,
                  window.renderFrameCount > 0,
                  addingFits(window.renderStartFrame, window.renderFrameCount, upperBound: plan.outputFrameCount) else {
                throw Lane3OfflineExecutionError.renderWindowOutOfBounds(stemID: window.stemID)
            }
        }

        let clickEventCount = plan.events.reduce(into: 0) { count, event in
            if event.kind == .countInClick || event.kind == .metronomeClick {
                count += 1
            }
        }
        if clickEventCount > 0 {
            guard let clickPCMFormat else {
                throw Lane3OfflineExecutionError.clickPCMRequired
            }
            guard clickPCMFormat.sampleRate.isFinite,
                  abs(clickPCMFormat.sampleRate - plan.outputSampleRate) <= 0.5,
                  clickPCMFormat.channels > 0 else {
                throw Lane3OfflineExecutionError.invalidClickPCMFormat
            }
        }

        return Lane3OfflineExecutionManifest(
            fixtureID: plan.fixtureID,
            controlSignatureFNV1A64: plan.controlSignatureFNV1A64,
            outputSampleRate: plan.outputSampleRate,
            outputFrameCount: plan.outputFrameCount,
            expectedStemIDs: request.stems.map(\.id).sorted(),
            renderWindowCount: plan.stemWindows.count,
            clickEventCount: clickEventCount,
            requiresClickPCM: clickEventCount > 0
        )
    }

    private static func addingFits(_ lhs: Int64, _ rhs: Int64, upperBound: Int64) -> Bool {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return !overflow && sum >= 0 && sum <= upperBound
    }

    private static func absoluteDifference(_ lhs: Int64, _ rhs: Int64) -> UInt64 {
        if (lhs >= 0) == (rhs >= 0) {
            let a = lhs.magnitude
            let b = rhs.magnitude
            return a >= b ? a - b : b - a
        }
        let (sum, overflow) = lhs.magnitude.addingReportingOverflow(rhs.magnitude)
        return overflow ? UInt64.max : sum
    }
}

/// Streaming PCM statistics avoid retaining an entire long offline render in memory. Apple manual
/// rendering feeds each chunk here and may independently stream the same buffer to an AVAudioFile.
public struct Lane3StreamingPCMAccumulator: Equatable, Sendable {
    public let channels: Int
    public let sampleRate: Double
    private var frameCount: Int64
    private var finiteSampleCount: Int64
    private var nonFiniteSampleCount: Int64
    private var peakAbsolute: Double
    private var sumSquares: Double
    private var sum: Double
    private var firstNonSilentFrame: Int64?
    private var lastNonSilentFrame: Int64?
    private var clippedSampleCount: Int64
    private var sampleFingerprint: UInt64
    private let nonSilenceThreshold: Double

    public init(
        channels: Int,
        sampleRate: Double,
        nonSilenceThreshold: Double = 1e-7
    ) throws {
        guard channels > 0,
              sampleRate.isFinite, sampleRate > 0,
              nonSilenceThreshold.isFinite, nonSilenceThreshold >= 0 else {
            throw Lane3OfflineExecutionError.invalidPCMChunk
        }
        self.channels = channels
        self.sampleRate = sampleRate
        self.frameCount = 0
        self.finiteSampleCount = 0
        self.nonFiniteSampleCount = 0
        self.peakAbsolute = 0
        self.sumSquares = 0
        self.sum = 0
        self.firstNonSilentFrame = nil
        self.lastNonSilentFrame = nil
        self.clippedSampleCount = 0
        self.sampleFingerprint = 0xcbf29ce484222325
        self.nonSilenceThreshold = nonSilenceThreshold
    }

    public mutating func consume(interleavedSamples: [Float]) throws {
        guard interleavedSamples.count % channels == 0 else {
            throw Lane3OfflineExecutionError.invalidPCMChunk
        }
        let frames = Int64(interleavedSamples.count / channels)
        let (nextFrames, frameOverflow) = frameCount.addingReportingOverflow(frames)
        guard !frameOverflow else { throw Lane3OfflineExecutionError.pcmAccumulatorOverflow }

        for (sampleIndex, sample) in interleavedSamples.enumerated() {
            let value = Double(sample)
            let bits = sample.bitPattern
            for shift in stride(from: 0, through: 24, by: 8) {
                sampleFingerprint ^= UInt64((bits >> UInt32(shift)) & 0xff)
                sampleFingerprint &*= 0x100000001b3
            }
            if value.isFinite {
                let (nextFinite, finiteOverflow) = finiteSampleCount.addingReportingOverflow(1)
                guard !finiteOverflow else { throw Lane3OfflineExecutionError.pcmAccumulatorOverflow }
                let square = value * value
                let nextSquares = sumSquares + square
                let nextSum = sum + value
                guard square.isFinite, nextSquares.isFinite, nextSum.isFinite else {
                    throw Lane3OfflineExecutionError.pcmAccumulatorOverflow
                }
                finiteSampleCount = nextFinite
                let absolute = abs(value)
                peakAbsolute = max(peakAbsolute, absolute)
                sumSquares = nextSquares
                sum = nextSum
                if absolute > 1 {
                    let (nextClipped, clippedOverflow) = clippedSampleCount.addingReportingOverflow(1)
                    guard !clippedOverflow else { throw Lane3OfflineExecutionError.pcmAccumulatorOverflow }
                    clippedSampleCount = nextClipped
                }
                if absolute > nonSilenceThreshold {
                    let localFrame = Int64(sampleIndex / channels)
                    let (absoluteFrame, overflow) = frameCount.addingReportingOverflow(localFrame)
                    guard !overflow else { throw Lane3OfflineExecutionError.pcmAccumulatorOverflow }
                    if firstNonSilentFrame == nil { firstNonSilentFrame = absoluteFrame }
                    lastNonSilentFrame = absoluteFrame
                }
            } else {
                let (nextNonFinite, overflow) = nonFiniteSampleCount.addingReportingOverflow(1)
                guard !overflow else { throw Lane3OfflineExecutionError.pcmAccumulatorOverflow }
                nonFiniteSampleCount = nextNonFinite
            }
        }
        frameCount = nextFrames
    }

    public func digest() -> Lane3PCMExecutionDigest {
        Lane3PCMExecutionDigest(
            frameCount: frameCount,
            firstNonSilentFrame: firstNonSilentFrame,
            lastNonSilentFrame: lastNonSilentFrame,
            clippedSampleCount: clippedSampleCount,
            sampleFingerprintFNV1A64: String(format: "%016llx", sampleFingerprint)
        )
    }

    public func summary() -> Lane3AudioSummary {
        let rms = finiteSampleCount > 0 ? sqrt(sumSquares / Double(finiteSampleCount)) : 0
        let dc = finiteSampleCount > 0 ? sum / Double(finiteSampleCount) : 0
        return Lane3AudioSummary(
            sampleRate: sampleRate,
            channels: channels,
            frameCount: frameCount,
            peakAbsolute: peakAbsolute,
            rms: rms,
            dcOffset: dc,
            nonFiniteSampleCount: nonFiniteSampleCount
        )
    }
}
