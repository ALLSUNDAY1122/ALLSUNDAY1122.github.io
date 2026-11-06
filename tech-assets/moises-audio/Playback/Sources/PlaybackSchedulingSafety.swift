import Foundation

public struct PlaybackScheduledTrackWindow: Equatable, Sendable {
    public let stemID: StemID
    public let delayedStartSeconds: Double
    public let frameCount: Int64
    public let sampleRate: Double

    public init(
        stemID: StemID,
        delayedStartSeconds: Double,
        frameCount: Int64,
        sampleRate: Double
    ) {
        self.stemID = stemID
        self.delayedStartSeconds = delayedStartSeconds
        self.frameCount = frameCount
        self.sampleRate = sampleRate
    }

    public var endOffsetSeconds: Double {
        delayedStartSeconds + Double(frameCount) / sampleRate
    }
}

public enum PlaybackSchedulingSafety {
    /// Selects the track whose scheduled audio ends last on the shared project timeline.
    /// Comparing raw frame counts is incorrect when stems have different sample rates or delayed starts.
    public static func latestEndingStemID(
        windows: [PlaybackScheduledTrackWindow]
    ) throws -> StemID? {
        var latest: PlaybackScheduledTrackWindow?
        for window in windows {
            guard window.delayedStartSeconds.isFinite,
                  window.delayedStartSeconds >= 0,
                  window.sampleRate.isFinite,
                  window.sampleRate > 0,
                  window.frameCount >= 0 else {
                throw PlaybackControlError.timelineOverflow
            }
            let end = window.endOffsetSeconds
            guard end.isFinite else {
                throw PlaybackControlError.timelineOverflow
            }
            if let current = latest {
                if end > current.endOffsetSeconds {
                    latest = window
                } else if end == current.endOffsetSeconds,
                          window.stemID.rawValue.uuidString < current.stemID.rawValue.uuidString {
                    latest = window
                }
            } else {
                latest = window
            }
        }
        return latest?.stemID
    }

    /// Keeps an explicit seek inside an active loop once it passes the loop end.
    /// Positions before the loop start remain valid so playback can naturally enter the loop.
    public static func normalizedSeekPosition(
        requestedSeconds: Double,
        durationSeconds: Double?,
        loop: PlaybackLoopRange?
    ) throws -> Double {
        guard requestedSeconds.isFinite, requestedSeconds >= 0 else {
            throw PlaybackControlError.invalidSeek(requestedSeconds)
        }
        if let durationSeconds {
            guard durationSeconds.isFinite, durationSeconds >= 0 else {
                throw PlaybackControlError.nonFiniteValue
            }
            guard requestedSeconds <= durationSeconds else {
                throw PlaybackControlError.invalidSeek(requestedSeconds)
            }
        }
        guard let loop else { return requestedSeconds }
        guard loop.startSeconds.isFinite,
              loop.endSeconds.isFinite,
              loop.startSeconds >= 0,
              loop.endSeconds > loop.startSeconds else {
            throw PlaybackControlError.invalidLoop(
                start: loop.startSeconds,
                end: loop.endSeconds
            )
        }
        if let durationSeconds, loop.endSeconds > durationSeconds {
            throw PlaybackControlError.invalidLoop(
                start: loop.startSeconds,
                end: loop.endSeconds
            )
        }
        guard requestedSeconds >= loop.endSeconds else {
            return requestedSeconds
        }
        let repeated = requestedSeconds - loop.endSeconds
        return loop.startSeconds
            + repeated.truncatingRemainder(dividingBy: loop.durationSeconds)
    }
}
