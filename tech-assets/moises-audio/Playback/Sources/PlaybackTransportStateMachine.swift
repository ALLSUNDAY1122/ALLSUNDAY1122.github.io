import Foundation

public enum PlaybackTransportMediaKind: String, Codable, Sendable {
    case source
    case stems
}

public enum PlaybackTransportIntent: String, Codable, Sendable {
    case paused
    case playing
}

public struct PlaybackTransportMachineState: Equatable, Sendable {
    public var media: PlaybackTransportMediaKind
    public var intent: PlaybackTransportIntent
    public var positionFrame: Int64
    public var loopStartFrame: Int64?
    public var loopEndFrame: Int64?
    public var interrupted: Bool
    public var resumeAfterInterruption: Bool

    public init(
        media: PlaybackTransportMediaKind = .source,
        intent: PlaybackTransportIntent = .paused,
        positionFrame: Int64 = 0,
        loopStartFrame: Int64? = nil,
        loopEndFrame: Int64? = nil,
        interrupted: Bool = false,
        resumeAfterInterruption: Bool = false
    ) {
        self.media = media
        self.intent = intent
        self.positionFrame = positionFrame
        self.loopStartFrame = loopStartFrame
        self.loopEndFrame = loopEndFrame
        self.interrupted = interrupted
        self.resumeAfterInterruption = resumeAfterInterruption
    }
}

public enum PlaybackTransportEvent: Equatable, Sendable {
    case play
    case pause
    case seek(frame: Int64)
    case setLoop(startFrame: Int64, endFrame: Int64)
    case clearLoop
    case replaceSourceWithStems(PlaybackSourceToStemsTransitionPlan)
    case interruptionBegan
    case interruptionEnded(systemAllowsResume: Bool)
    case reachedEnd(endFrame: Int64)
}

public enum PlaybackTransportStateMachine {
    public static func reduce(
        _ state: PlaybackTransportMachineState,
        event: PlaybackTransportEvent,
        clock: PlaybackProjectFrameClock
    ) throws -> PlaybackTransportMachineState {
        var next = state
        switch event {
        case .play:
            if next.interrupted {
                next.resumeAfterInterruption = true
                next.intent = .paused
            } else {
                next.intent = .playing
                next.resumeAfterInterruption = false
            }

        case .pause:
            next.intent = .paused
            next.resumeAfterInterruption = false

        case .seek(let frame):
            guard frame >= 0 else {
                throw PlaybackTransportSemanticsError.negativeFrame(frame)
            }
            next.positionFrame = try normalize(frame: frame, state: next, clock: clock)

        case .setLoop(let startFrame, let endFrame):
            guard startFrame >= 0, endFrame > startFrame else {
                throw PlaybackTransportSemanticsError.invalidFrameLoop(
                    start: startFrame,
                    end: endFrame
                )
            }
            next.loopStartFrame = startFrame
            next.loopEndFrame = endFrame
            next.positionFrame = try clock.normalizedFrame(
                next.positionFrame,
                loopStartFrame: startFrame,
                loopEndFrame: endFrame
            )

        case .clearLoop:
            next.loopStartFrame = nil
            next.loopEndFrame = nil

        case .replaceSourceWithStems(let plan):
            next.media = .stems
            next.positionFrame = plan.projectPositionFrame
            if next.interrupted {
                next.intent = .paused
                next.resumeAfterInterruption = plan.resumePlayback
            } else {
                next.intent = plan.resumePlayback ? .playing : .paused
                next.resumeAfterInterruption = false
            }

        case .interruptionBegan:
            if !next.interrupted {
                next.resumeAfterInterruption = next.intent == .playing
            }
            next.interrupted = true
            next.intent = .paused

        case .interruptionEnded(let systemAllowsResume):
            let shouldResume = next.interrupted
                && next.resumeAfterInterruption
                && systemAllowsResume
            next.interrupted = false
            next.resumeAfterInterruption = false
            next.intent = shouldResume ? .playing : .paused

        case .reachedEnd(let endFrame):
            guard endFrame >= 0 else {
                throw PlaybackTransportSemanticsError.negativeFrame(endFrame)
            }
            if let loopStart = next.loopStartFrame,
               let loopEnd = next.loopEndFrame {
                next.positionFrame = try clock.normalizedFrame(
                    max(endFrame, loopEnd),
                    loopStartFrame: loopStart,
                    loopEndFrame: loopEnd
                )
            } else {
                next.positionFrame = endFrame
                next.intent = .paused
                next.resumeAfterInterruption = false
            }
        }
        return next
    }

    private static func normalize(
        frame: Int64,
        state: PlaybackTransportMachineState,
        clock: PlaybackProjectFrameClock
    ) throws -> Int64 {
        guard let loopStart = state.loopStartFrame,
              let loopEnd = state.loopEndFrame else {
            return frame
        }
        return try clock.normalizedFrame(
            frame,
            loopStartFrame: loopStart,
            loopEndFrame: loopEnd
        )
    }
}
