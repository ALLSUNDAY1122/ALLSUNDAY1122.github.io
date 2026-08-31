import Foundation

public final class ClonePlayback: @unchecked Sendable {
    public let id: CloneID
    public let recording: ReplayRecording
    public let options: CloneSpawnOptions

    public private(set) var frameIndex: Int
    public private(set) var loopIndex: UInt64 = 0
    public private(set) var isFinished = false

    private var phaseTicksRemaining: Int
    private let markersByFrame: [Int: [ReplayMarkerKind]]

    public init(id: CloneID, recording: ReplayRecording, options: CloneSpawnOptions) {
        self.id = id
        self.recording = recording
        self.options = options
        self.frameIndex = min(options.startFrame, max(0, recording.frames.count - 1))
        self.phaseTicksRemaining = options.phaseOffsetTicks
        var grouped: [Int: [ReplayMarkerKind]] = [:]
        for marker in recording.markers { grouped[marker.frameIndex, default: []].append(marker.kind) }
        self.markersByFrame = grouped
    }

    public func currentSnapshot() -> CloneSnapshot {
        let index = min(frameIndex, recording.frames.count - 1)
        let frame = recording.frames[index]
        return makeSnapshot(frame: frame, index: index, markers: [])
    }

    @discardableResult
    public func advanceOneTick() -> CloneSnapshot {
        if phaseTicksRemaining > 0 {
            phaseTicksRemaining -= 1
            let frame = recording.frames[frameIndex]
            return makeSnapshot(frame: frame, index: frameIndex, markers: [])
        }

        if isFinished { return currentSnapshot() }
        let index = frameIndex
        let frame = recording.frames[index]
        let snapshot = makeSnapshot(frame: frame, index: index, markers: markersByFrame[index] ?? [])

        if frameIndex + 1 < recording.frames.count {
            frameIndex += 1
        } else if options.loops {
            frameIndex = 0
            loopIndex &+= 1
        } else {
            isFinished = true
        }
        return snapshot
    }

    private func makeSnapshot(frame: ReplayFrame, index: Int, markers: [ReplayMarkerKind]) -> CloneSnapshot {
        CloneSnapshot(
            id: id,
            courseID: recording.context.courseID,
            frameIndex: index,
            loopIndex: loopIndex,
            position: frame.position,
            velocity: frame.velocity,
            input: frame.input,
            locomotionState: frame.locomotionState,
            resources: frame.resources,
            facing: frame.facing,
            isAlive: frame.isAlive,
            markers: markers,
            isFinished: isFinished
        )
    }
}
