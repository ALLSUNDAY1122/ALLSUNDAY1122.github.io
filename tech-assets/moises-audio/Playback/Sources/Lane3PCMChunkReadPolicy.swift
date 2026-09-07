import Foundation

public enum Lane3PCMChunkReadPolicyError: Error, Equatable, Sendable {
    case invalidMaximumFramesPerRead(Int)
    case invalidSourceMetadata
    case invalidReadRange(start: Int64, count: Int)
    case readExceedsLimit(requested: Int, maximum: Int)
    case integerOverflow
}

public struct Lane3PCMChunkReadPolicy: Equatable, Codable, Sendable {
    public let maximumFramesPerRead: Int

    public init(maximumFramesPerRead: Int = 65_536) throws {
        guard maximumFramesPerRead > 0,
              maximumFramesPerRead <= Int(UInt32.max) else {
            throw Lane3PCMChunkReadPolicyError.invalidMaximumFramesPerRead(maximumFramesPerRead)
        }
        self.maximumFramesPerRead = maximumFramesPerRead
    }

    public func expectedInterleavedSampleCount(
        startFrame: Int64,
        frameCount: Int,
        totalFrames: Int64,
        channels: Int
    ) throws -> Int {
        guard totalFrames >= 0, channels > 0 else {
            throw Lane3PCMChunkReadPolicyError.invalidSourceMetadata
        }
        guard startFrame >= 0, frameCount >= 0 else {
            throw Lane3PCMChunkReadPolicyError.invalidReadRange(start: startFrame, count: frameCount)
        }
        guard frameCount <= maximumFramesPerRead else {
            throw Lane3PCMChunkReadPolicyError.readExceedsLimit(
                requested: frameCount,
                maximum: maximumFramesPerRead
            )
        }
        let end = startFrame.addingReportingOverflow(Int64(frameCount))
        guard !end.overflow, end.partialValue <= totalFrames else {
            throw Lane3PCMChunkReadPolicyError.invalidReadRange(start: startFrame, count: frameCount)
        }
        let samples = Int64(frameCount).multipliedReportingOverflow(by: Int64(channels))
        guard !samples.overflow,
              samples.partialValue >= 0,
              samples.partialValue <= Int64(Int.max) else {
            throw Lane3PCMChunkReadPolicyError.integerOverflow
        }
        return Int(samples.partialValue)
    }
}

public struct Lane3PCMChunkReadAuditSnapshot: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let successfulReadCalls: UInt64
    public let zeroLengthReadCalls: UInt64
    public let totalFramesReturned: UInt64
    public let maximumRequestedFrames: Int
    public let initialReads: UInt64
    public let sequentialReads: UInt64
    public let backwardSeeks: UInt64
    public let forwardGapSeeks: UInt64
    public let counterOverflowed: Bool
    public let sourcePathIncluded: Bool
    public let parityPromotionAllowed: Bool
}

public struct Lane3PCMChunkReadAudit: Sendable {
    private var successfulReadCalls: UInt64 = 0
    private var zeroLengthReadCalls: UInt64 = 0
    private var totalFramesReturned: UInt64 = 0
    private var maximumRequestedFrames: Int = 0
    private var initialReads: UInt64 = 0
    private var sequentialReads: UInt64 = 0
    private var backwardSeeks: UInt64 = 0
    private var forwardGapSeeks: UInt64 = 0
    private var priorEndFrame: Int64?
    private var counterOverflowed = false

    public init() {}

    public mutating func recordSuccessfulRead(startFrame: Int64, frameCount: Int) {
        guard frameCount >= 0, startFrame >= 0 else { return }
        if frameCount == 0 {
            let next = Self.saturatingAdd(zeroLengthReadCalls, 1)
            zeroLengthReadCalls = next.value
            counterOverflowed = counterOverflowed || next.overflowed
            return
        }

        var next = Self.saturatingAdd(successfulReadCalls, 1)
        successfulReadCalls = next.value
        counterOverflowed = counterOverflowed || next.overflowed
        next = Self.saturatingAdd(totalFramesReturned, UInt64(frameCount))
        totalFramesReturned = next.value
        counterOverflowed = counterOverflowed || next.overflowed
        maximumRequestedFrames = max(maximumRequestedFrames, frameCount)

        if let priorEndFrame {
            if startFrame == priorEndFrame {
                next = Self.saturatingAdd(sequentialReads, 1)
                sequentialReads = next.value
            } else if startFrame < priorEndFrame {
                next = Self.saturatingAdd(backwardSeeks, 1)
                backwardSeeks = next.value
            } else {
                next = Self.saturatingAdd(forwardGapSeeks, 1)
                forwardGapSeeks = next.value
            }
            counterOverflowed = counterOverflowed || next.overflowed
        } else {
            next = Self.saturatingAdd(initialReads, 1)
            initialReads = next.value
            counterOverflowed = counterOverflowed || next.overflowed
        }

        let end = startFrame.addingReportingOverflow(Int64(frameCount))
        if end.overflow {
            counterOverflowed = true
            priorEndFrame = nil
        } else {
            priorEndFrame = end.partialValue
        }
    }

    public func snapshot() -> Lane3PCMChunkReadAuditSnapshot {
        Lane3PCMChunkReadAuditSnapshot(
            schemaVersion: 1,
            evidenceScope: "LANE3_BOUNDED_PCM_READ_AUDIT_NON_PARITY",
            successfulReadCalls: successfulReadCalls,
            zeroLengthReadCalls: zeroLengthReadCalls,
            totalFramesReturned: totalFramesReturned,
            maximumRequestedFrames: maximumRequestedFrames,
            initialReads: initialReads,
            sequentialReads: sequentialReads,
            backwardSeeks: backwardSeeks,
            forwardGapSeeks: forwardGapSeeks,
            counterOverflowed: counterOverflowed,
            sourcePathIncluded: false,
            parityPromotionAllowed: false
        )
    }

    private static func saturatingAdd(
        _ value: UInt64,
        _ amount: UInt64
    ) -> (value: UInt64, overflowed: Bool) {
        let result = value.addingReportingOverflow(amount)
        return result.overflow ? (UInt64.max, true) : (result.partialValue, false)
    }
}
