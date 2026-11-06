import Foundation

public enum PlaybackTempoBoundaryError: Error, Equatable, Sendable {
    case invalidTempoRatio(Double)
    case transactionAlreadyInFlight
    case noTransactionInFlight
    case staleTransaction(expectedSerial: UInt64, actualSerial: UInt64)
    case transactionSerialOverflow
    case scheduleGenerationOverflow
    case invalidClockInput
    case unsupportedBackend
}

public struct PlaybackTempoBoundaryReceipt: Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let serial: UInt64
    public let fromTempoRatio: Double
    public let toTempoRatio: Double
    public let capturedProjectPositionSeconds: Double
    public let loop: PlaybackLoopRange?
    public let resumeWasPlaying: Bool
    public let backendScheduleGeneration: UInt64
    public let parityPromotionAllowed: Bool

    public init(
        serial: UInt64,
        fromTempoRatio: Double,
        toTempoRatio: Double,
        capturedProjectPositionSeconds: Double,
        loop: PlaybackLoopRange?,
        resumeWasPlaying: Bool,
        backendScheduleGeneration: UInt64
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW31_TEMPO_BOUNDARY_NON_PARITY"
        self.serial = serial
        self.fromTempoRatio = fromTempoRatio
        self.toTempoRatio = toTempoRatio
        self.capturedProjectPositionSeconds = capturedProjectPositionSeconds
        self.loop = loop
        self.resumeWasPlaying = resumeWasPlaying
        self.backendScheduleGeneration = backendScheduleGeneration
        self.parityPromotionAllowed = false
    }
}

public struct PlaybackFencedTempoBoundaryReceipt: Equatable, Sendable {
    public let token: PlaybackTransportRescheduleToken
    public let boundary: PlaybackTempoBoundaryReceipt

    public init(
        token: PlaybackTransportRescheduleToken,
        boundary: PlaybackTempoBoundaryReceipt
    ) {
        self.token = token
        self.boundary = boundary
    }
}

/// Backend hook used only by the selected Lane-3 transport authority. The outer Playback fence owns
/// the externally visible generation token; the backend boundary receipt is an internal two-phase
/// stop/re-anchor/resume transaction and must never create a second public transport generation.
public protocol PlaybackTempoBoundaryRescheduling: Sendable {
    func prepareTempoBoundary(
        projectID: ProjectID,
        toTempoRatio: Double
    ) async throws -> PlaybackTempoBoundaryReceipt

    func commitTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws

    func cancelTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws
}

public enum PlaybackTempoClockMath {
    public static func projectPosition(
        anchorProjectSeconds: Double,
        elapsedHostSeconds: Double,
        tempoRatio: Double,
        durationSeconds: Double?,
        loop: PlaybackLoopRange?
    ) throws -> Double {
        guard anchorProjectSeconds.isFinite,
              anchorProjectSeconds >= 0,
              elapsedHostSeconds.isFinite,
              elapsedHostSeconds >= 0,
              tempoRatio.isFinite,
              tempoRatio > 0 else {
            throw PlaybackTempoBoundaryError.invalidClockInput
        }
        let advance = elapsedHostSeconds * tempoRatio
        guard advance.isFinite else { throw PlaybackTempoBoundaryError.invalidClockInput }
        let raw = anchorProjectSeconds + advance
        guard raw.isFinite else { throw PlaybackTempoBoundaryError.invalidClockInput }
        if let loop {
            guard loop.startSeconds.isFinite,
                  loop.endSeconds.isFinite,
                  loop.startSeconds >= 0,
                  loop.endSeconds > loop.startSeconds else {
                throw PlaybackTempoBoundaryError.invalidClockInput
            }
            if raw < loop.endSeconds { return raw }
            let repeated = raw - loop.endSeconds
            let wrapped = loop.startSeconds
                + repeated.truncatingRemainder(dividingBy: loop.durationSeconds)
            guard wrapped.isFinite else { throw PlaybackTempoBoundaryError.invalidClockInput }
            return wrapped
        }
        if let durationSeconds {
            guard durationSeconds.isFinite, durationSeconds >= 0 else {
                throw PlaybackTempoBoundaryError.invalidClockInput
            }
            return min(raw, durationSeconds)
        }
        return raw
    }

    /// Converts source/project duration into host/output duration while tempo is constant.
    public static func hostDuration(
        forProjectDuration projectSeconds: Double,
        tempoRatio: Double
    ) throws -> Double {
        guard projectSeconds.isFinite,
              projectSeconds >= 0,
              tempoRatio.isFinite,
              tempoRatio > 0 else {
            throw PlaybackTempoBoundaryError.invalidClockInput
        }
        let result = projectSeconds / tempoRatio
        guard result.isFinite else { throw PlaybackTempoBoundaryError.invalidClockInput }
        return result
    }
}
