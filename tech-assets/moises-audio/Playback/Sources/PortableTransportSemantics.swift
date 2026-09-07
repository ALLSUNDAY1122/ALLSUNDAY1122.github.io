import Foundation

public enum PlaybackTransportSemanticsError: Error, Equatable, Sendable {
    case invalidSampleRate(Double)
    case invalidSeconds(Double)
    case negativeFrame(Int64)
    case invalidFrameLoop(start: Int64, end: Int64)
    case emptyStemSet
    case invalidStemWindow(StemID)
    case timelineOverflow
}

public struct PlaybackProjectFrameClock: Equatable, Sendable {
    public let sampleRate: Double

    public init(sampleRate: Double = 48_000) throws {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw PlaybackTransportSemanticsError.invalidSampleRate(sampleRate)
        }
        self.sampleRate = sampleRate
    }

    public func frame(
        atSeconds seconds: Double,
        rounding: FloatingPointRoundingRule = .down
    ) throws -> Int64 {
        guard seconds.isFinite, seconds >= 0 else {
            throw PlaybackTransportSemanticsError.invalidSeconds(seconds)
        }
        let scaled = seconds * sampleRate
        guard scaled.isFinite,
              scaled >= 0,
              scaled <= Double(Int64.max) else {
            throw PlaybackTransportSemanticsError.timelineOverflow
        }
        let rounded = scaled.rounded(rounding)
        guard rounded.isFinite,
              rounded >= 0,
              rounded <= Double(Int64.max) else {
            throw PlaybackTransportSemanticsError.timelineOverflow
        }
        return Int64(rounded)
    }

    public func seconds(forFrame frame: Int64) throws -> Double {
        guard frame >= 0 else {
            throw PlaybackTransportSemanticsError.negativeFrame(frame)
        }
        let seconds = Double(frame) / sampleRate
        guard seconds.isFinite else {
            throw PlaybackTransportSemanticsError.timelineOverflow
        }
        return seconds
    }

    /// Normalizes an absolute project frame directly against the loop interval.
    /// The result is independent of how many loop iterations have already rendered,
    /// so repeated loops cannot accumulate floating-point position drift.
    public func normalizedFrame(
        _ rawFrame: Int64,
        loopStartFrame: Int64,
        loopEndFrame: Int64
    ) throws -> Int64 {
        guard rawFrame >= 0 else {
            throw PlaybackTransportSemanticsError.negativeFrame(rawFrame)
        }
        guard loopStartFrame >= 0,
              loopEndFrame > loopStartFrame else {
            throw PlaybackTransportSemanticsError.invalidFrameLoop(
                start: loopStartFrame,
                end: loopEndFrame
            )
        }
        guard rawFrame >= loopEndFrame else { return rawFrame }
        let loopLength = loopEndFrame - loopStartFrame
        let repeatedFrames = rawFrame - loopEndFrame
        return loopStartFrame + repeatedFrames % loopLength
    }
}

public struct PlaybackStemProjectWindow: Equatable, Sendable {
    public let stemID: StemID
    public let projectStartFrame: Int64
    public let projectEndFrame: Int64

    public var frameCount: Int64 { projectEndFrame - projectStartFrame }
}

public struct PlaybackStemTimelineSummary: Equatable, Sendable {
    public let windows: [PlaybackStemProjectWindow]
    public let activeStemIDs: [StemID]
    public let delayedStemIDs: [StemID]
    public let endedStemIDs: [StemID]
    public let earliestStartFrame: Int64
    public let latestEndFrame: Int64

    public var allStemsEnded: Bool {
        !windows.isEmpty && endedStemIDs.count == windows.count
    }
}

public enum PlaybackSourceToStemsTransitionState: String, Codable, Sendable {
    case preservedClock
    case waitingForDelayedStem
    case clampedToStemEnd
}

public struct PlaybackSourceToStemsTransitionPlan: Equatable, Sendable {
    public let state: PlaybackSourceToStemsTransitionState
    public let projectPositionSeconds: Double
    public let projectPositionFrame: Int64
    public let resumePlayback: Bool
    public let sourceTailGapSeconds: Double
    public let stemsExtendPastSourceSeconds: Double
    public let timeline: PlaybackStemTimelineSummary
}

public struct PlaybackInterruptionSnapshot: Equatable, Sendable {
    public let resumeIntentBeforeInterruption: Bool
    public let positionSeconds: Double

    public init(resumeIntentBeforeInterruption: Bool, positionSeconds: Double) throws {
        guard positionSeconds.isFinite, positionSeconds >= 0 else {
            throw PlaybackTransportSemanticsError.invalidSeconds(positionSeconds)
        }
        self.resumeIntentBeforeInterruption = resumeIntentBeforeInterruption
        self.positionSeconds = positionSeconds
    }

    public func shouldResume(systemAllowsResume: Bool) -> Bool {
        resumeIntentBeforeInterruption && systemAllowsResume
    }
}

public enum PlaybackTransportSemantics {
    public static func stemTimelineSummary(
        stems: [StemArtifact],
        projectPositionFrame: Int64,
        clock: PlaybackProjectFrameClock
    ) throws -> PlaybackStemTimelineSummary {
        guard !stems.isEmpty else {
            throw PlaybackTransportSemanticsError.emptyStemSet
        }
        guard projectPositionFrame >= 0 else {
            throw PlaybackTransportSemanticsError.negativeFrame(projectPositionFrame)
        }

        var windows: [PlaybackStemProjectWindow] = []
        windows.reserveCapacity(stems.count)
        var active: [StemID] = []
        var delayed: [StemID] = []
        var ended: [StemID] = []
        var earliestStart = Int64.max
        var latestEnd: Int64 = 0

        for stem in stems {
            guard stem.startTimeSeconds.isFinite,
                  stem.startTimeSeconds >= 0,
                  stem.sampleRate.isFinite,
                  stem.sampleRate > 0,
                  stem.frameCount >= 0 else {
                throw PlaybackTransportSemanticsError.invalidStemWindow(stem.id)
            }
            let durationSeconds = Double(stem.frameCount) / stem.sampleRate
            let endSeconds = stem.startTimeSeconds + durationSeconds
            guard durationSeconds.isFinite, endSeconds.isFinite else {
                throw PlaybackTransportSemanticsError.timelineOverflow
            }
            let startFrame = try clock.frame(atSeconds: stem.startTimeSeconds, rounding: .down)
            let endFrame = try clock.frame(atSeconds: endSeconds, rounding: .up)
            guard endFrame >= startFrame else {
                throw PlaybackTransportSemanticsError.invalidStemWindow(stem.id)
            }

            windows.append(
                PlaybackStemProjectWindow(
                    stemID: stem.id,
                    projectStartFrame: startFrame,
                    projectEndFrame: endFrame
                )
            )
            earliestStart = min(earliestStart, startFrame)
            latestEnd = max(latestEnd, endFrame)

            if projectPositionFrame < startFrame {
                delayed.append(stem.id)
            } else if projectPositionFrame >= endFrame {
                ended.append(stem.id)
            } else {
                active.append(stem.id)
            }
        }

        let order: (StemID, StemID) -> Bool = {
            $0.rawValue.uuidString < $1.rawValue.uuidString
        }
        windows.sort {
            if $0.projectStartFrame == $1.projectStartFrame {
                return order($0.stemID, $1.stemID)
            }
            return $0.projectStartFrame < $1.projectStartFrame
        }
        active.sort(by: order)
        delayed.sort(by: order)
        ended.sort(by: order)

        return PlaybackStemTimelineSummary(
            windows: windows,
            activeStemIDs: active,
            delayedStemIDs: delayed,
            endedStemIDs: ended,
            earliestStartFrame: earliestStart,
            latestEndFrame: latestEnd
        )
    }

    /// Plans source -> stems as an atomic transport transition.
    /// Position and play intent are preserved while replacement media still covers
    /// or is scheduled after the current project time. If every replacement stem has
    /// already ended, the transport clamps to the actual stem end and stops instead of
    /// reporting silent playback beyond available media.
    public static func sourceToStemsTransition(
        stems: [StemArtifact],
        currentPositionSeconds: Double,
        sourceDurationSeconds: Double?,
        wasPlaying: Bool,
        projectClockSampleRate: Double = 48_000
    ) throws -> PlaybackSourceToStemsTransitionPlan {
        let clock = try PlaybackProjectFrameClock(sampleRate: projectClockSampleRate)
        let currentFrame = try clock.frame(atSeconds: currentPositionSeconds, rounding: .down)
        let initialSummary = try stemTimelineSummary(
            stems: stems,
            projectPositionFrame: currentFrame,
            clock: clock
        )

        let targetFrame: Int64
        let resumePlayback: Bool
        let transitionState: PlaybackSourceToStemsTransitionState
        if currentFrame >= initialSummary.latestEndFrame {
            targetFrame = initialSummary.latestEndFrame
            resumePlayback = false
            transitionState = .clampedToStemEnd
        } else if initialSummary.activeStemIDs.isEmpty,
                  !initialSummary.delayedStemIDs.isEmpty {
            targetFrame = currentFrame
            resumePlayback = wasPlaying
            transitionState = .waitingForDelayedStem
        } else {
            targetFrame = currentFrame
            resumePlayback = wasPlaying
            transitionState = .preservedClock
        }

        let targetSummary = targetFrame == currentFrame
            ? initialSummary
            : try stemTimelineSummary(
                stems: stems,
                projectPositionFrame: targetFrame,
                clock: clock
            )
        let targetSeconds = try clock.seconds(forFrame: targetFrame)
        let stemEndSeconds = try clock.seconds(forFrame: targetSummary.latestEndFrame)

        var sourceTailGapSeconds = 0.0
        var stemsExtendPastSourceSeconds = 0.0
        if let sourceDurationSeconds {
            guard sourceDurationSeconds.isFinite, sourceDurationSeconds >= 0 else {
                throw PlaybackTransportSemanticsError.invalidSeconds(sourceDurationSeconds)
            }
            sourceTailGapSeconds = max(0, sourceDurationSeconds - stemEndSeconds)
            stemsExtendPastSourceSeconds = max(0, stemEndSeconds - sourceDurationSeconds)
        }

        return PlaybackSourceToStemsTransitionPlan(
            state: transitionState,
            projectPositionSeconds: targetSeconds,
            projectPositionFrame: targetFrame,
            resumePlayback: resumePlayback,
            sourceTailGapSeconds: sourceTailGapSeconds,
            stemsExtendPastSourceSeconds: stemsExtendPastSourceSeconds,
            timeline: targetSummary
        )
    }
}
