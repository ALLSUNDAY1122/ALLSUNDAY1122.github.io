import Foundation

public enum ReplayFormat {
    public static let currentVersion = 1
}

public struct ReplayContext: Equatable, Sendable {
    public let courseID: String
    public let startedAtTick: UInt64

    public init(courseID: String, startedAtTick: UInt64) {
        self.courseID = courseID
        self.startedAtTick = startedAtTick
    }
}

public struct ReplayInputSample: Equatable, Sendable {
    public var moveAxis: Float
    public var jumpHeld: Bool
    public var jumpPressedThisTick: Bool
    public var dashPressedThisTick: Bool
    public var wallJumpPressedThisTick: Bool

    public init(moveAxis: Float = 0, jumpHeld: Bool = false, jumpPressedThisTick: Bool = false, dashPressedThisTick: Bool = false, wallJumpPressedThisTick: Bool = false) {
        self.moveAxis = max(-1, min(1, moveAxis))
        self.jumpHeld = jumpHeld
        self.jumpPressedThisTick = jumpPressedThisTick
        self.dashPressedThisTick = dashPressedThisTick
        self.wallJumpPressedThisTick = wallJumpPressedThisTick
    }
}

public struct ReplayResourceState: Equatable, Sendable {
    public var airJumpsRemaining: Int
    public var airDashAvailable: Bool
    public init(airJumpsRemaining: Int, airDashAvailable: Bool) {
        self.airJumpsRemaining = airJumpsRemaining
        self.airDashAvailable = airDashAvailable
    }
}

public protocol ReplayStateSource: AnyObject {
    var position: Vector2 { get }
    var velocity: Vector2 { get }
    var facing: Int { get }
    var locomotionState: PlayerLocomotionState { get }
    var airJumpsRemaining: Int { get }
    var airDashAvailable: Bool { get }
    var isAlive: Bool { get }
}

public struct ReplayFrame: Equatable, Sendable {
    public let tick: UInt64
    public let position: Vector2
    public let velocity: Vector2
    public let input: ReplayInputSample
    public let locomotionState: PlayerLocomotionState
    public let resources: ReplayResourceState
    public let facing: Int
    public let isAlive: Bool

    public init(tick: UInt64, position: Vector2, velocity: Vector2, input: ReplayInputSample, locomotionState: PlayerLocomotionState, resources: ReplayResourceState, facing: Int, isAlive: Bool) {
        self.tick = tick
        self.position = position
        self.velocity = velocity
        self.input = input
        self.locomotionState = locomotionState
        self.resources = resources
        self.facing = facing >= 0 ? 1 : -1
        self.isAlive = isAlive
    }
}

public enum ReplayMarkerKind: Equatable, Sendable {
    case checkpointReached(String)
    case playerDied(DeathReason)
    case lapCompleted(String)
}

public struct ReplayMarker: Equatable, Sendable {
    public let tick: UInt64
    public let frameIndex: Int
    public let kind: ReplayMarkerKind
    public init(tick: UInt64, frameIndex: Int, kind: ReplayMarkerKind) {
        self.tick = tick
        self.frameIndex = frameIndex
        self.kind = kind
    }
}

public enum ReplayValidationError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case emptyRecording
    case nonMonotonicTicks
    case markerOutOfBounds
}

public struct ReplayRecording: Equatable, Sendable {
    public let version: Int
    public let context: ReplayContext
    public let frames: [ReplayFrame]
    public let markers: [ReplayMarker]
    public var frameCount: Int { frames.count }
    public var durationTicks: UInt64 {
        guard let first = frames.first, let last = frames.last else { return 0 }
        return last.tick - first.tick + 1
    }

    public init(version: Int = ReplayFormat.currentVersion, context: ReplayContext, frames: [ReplayFrame], markers: [ReplayMarker] = []) throws {
        guard version == ReplayFormat.currentVersion else { throw ReplayValidationError.unsupportedVersion(version) }
        guard !frames.isEmpty else { throw ReplayValidationError.emptyRecording }
        for index in 1..<frames.count where frames[index].tick <= frames[index - 1].tick {
            throw ReplayValidationError.nonMonotonicTicks
        }
        for marker in markers where marker.frameIndex < 0 || marker.frameIndex >= frames.count {
            throw ReplayValidationError.markerOutOfBounds
        }
        self.version = version
        self.context = context
        self.frames = frames
        self.markers = markers
    }
}

public struct CloneID: Hashable, Equatable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
}

public struct CloneSpawnOptions: Equatable, Sendable {
    public var loops: Bool
    public var startFrame: Int
    public var phaseOffsetTicks: Int
    public init(loops: Bool = true, startFrame: Int = 0, phaseOffsetTicks: Int = 0) {
        self.loops = loops
        self.startFrame = max(0, startFrame)
        self.phaseOffsetTicks = max(0, phaseOffsetTicks)
    }
}

public struct CloneSnapshot: Equatable, Sendable {
    public let id: CloneID
    public let courseID: String
    public let frameIndex: Int
    public let loopIndex: UInt64
    public let position: Vector2
    public let velocity: Vector2
    public let input: ReplayInputSample
    public let locomotionState: PlayerLocomotionState
    public let resources: ReplayResourceState
    public let facing: Int
    public let isAlive: Bool
    public let markers: [ReplayMarkerKind]
    public let isFinished: Bool
}

public protocol ReplayControlling: AnyObject {
    func startRecording(context: ReplayContext)
    func stopRecording() -> ReplayRecording?
    func clearRecording(for courseID: String?)
    func spawnClone(recording: ReplayRecording, options: CloneSpawnOptions) -> CloneID
    func removeClone(_ id: CloneID)
    func removeAllClones()
}

public final class ReplayRecorder: @unchecked Sendable {
    public private(set) var isRecording = false
    public private(set) var context: ReplayContext?
    public private(set) var frameCount = 0
    private var frames: [ReplayFrame] = []
    private var pendingMarkers: [(tick: UInt64, kind: ReplayMarkerKind)] = []

    public init() {}

    public func start(context: ReplayContext) {
        self.context = context
        frames.removeAll(keepingCapacity: true)
        pendingMarkers.removeAll(keepingCapacity: true)
        frameCount = 0
        isRecording = true
    }

    @discardableResult
    public func capture(tick: UInt64, state: any ReplayStateSource, input: ReplayInputSample) -> Bool {
        guard isRecording else { return false }
        if let last = frames.last, tick <= last.tick { return false }
        frames.append(ReplayFrame(tick: tick, position: state.position, velocity: state.velocity, input: input, locomotionState: state.locomotionState, resources: ReplayResourceState(airJumpsRemaining: state.airJumpsRemaining, airDashAvailable: state.airDashAvailable), facing: state.facing, isAlive: state.isAlive))
        frameCount = frames.count
        return true
    }

    @discardableResult
    public func mark(tick: UInt64, kind: ReplayMarkerKind) -> Bool {
        guard isRecording else { return false }
        pendingMarkers.append((tick: tick, kind: kind))
        return true
    }

    public func stop() -> ReplayRecording? {
        guard isRecording, let context else { return nil }
        isRecording = false
        self.context = nil
        guard !frames.isEmpty else { resetBuffers(); return nil }
        let resolvedMarkers = pendingMarkers.compactMap { pending -> ReplayMarker? in
            guard let lastTick = frames.last?.tick, pending.tick <= lastTick else { return nil }
            guard let frameIndex = frameIndex(atOrBefore: pending.tick) else { return nil }
            return ReplayMarker(tick: pending.tick, frameIndex: frameIndex, kind: pending.kind)
        }
        let result = try? ReplayRecording(context: context, frames: frames, markers: resolvedMarkers)
        resetBuffers()
        return result
    }

    public func cancel() {
        isRecording = false
        context = nil
        resetBuffers()
    }

    private func frameIndex(atOrBefore tick: UInt64) -> Int? {
        var low = 0
        var high = frames.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if frames[mid].tick <= tick { answer = mid; low = mid + 1 }
            else { high = mid - 1 }
        }
        return answer
    }

    private func resetBuffers() {
        frames.removeAll(keepingCapacity: true)
        pendingMarkers.removeAll(keepingCapacity: true)
        frameCount = 0
    }
}

public final class ReplaySystem: ReplayControlling, @unchecked Sendable {
    public weak var signalSink: CoreGameplaySignalSink?
    private let recorder = ReplayRecorder()
    private var bestByCourse: [String: ReplayRecording] = [:]
    private var clones: [CloneID: ClonePlayback] = [:]
    private var cloneOrder: [CloneID] = []
    private var nextCloneRawValue: UInt64 = 1

    public init(signalSink: CoreGameplaySignalSink? = nil) { self.signalSink = signalSink }
    public var isRecording: Bool { recorder.isRecording }
    public var activeCloneCount: Int { clones.count }

    public func startRecording(context: ReplayContext) { recorder.start(context: context) }

    @discardableResult
    public func captureTick(tick: UInt64, state: any ReplayStateSource, input: ReplayInputSample = ReplayInputSample()) -> Bool {
        recorder.capture(tick: tick, state: state, input: input)
    }

    @discardableResult
    public func recordMarker(tick: UInt64, kind: ReplayMarkerKind) -> Bool { recorder.mark(tick: tick, kind: kind) }

    public func stopRecording() -> ReplayRecording? {
        guard let recording = recorder.stop() else { return nil }
        if let existing = bestByCourse[recording.context.courseID] {
            if recording.durationTicks <= existing.durationTicks { bestByCourse[recording.context.courseID] = recording }
        } else { bestByCourse[recording.context.courseID] = recording }
        signalSink?.emit(.recordingCompleted(RecordingEvent(frameCount: recording.frameCount)))
        return recording
    }

    public func clearRecording(for courseID: String?) {
        if let courseID { bestByCourse.removeValue(forKey: courseID) }
        else { bestByCourse.removeAll(keepingCapacity: true) }
    }

    public func bestRecording(for courseID: String) -> ReplayRecording? { bestByCourse[courseID] }

    public func spawnClone(recording: ReplayRecording, options: CloneSpawnOptions = CloneSpawnOptions()) -> CloneID {
        let id = CloneID(rawValue: nextCloneRawValue)
        nextCloneRawValue &+= 1
        clones[id] = ClonePlayback(id: id, recording: recording, options: options)
        cloneOrder.append(id)
        return id
    }

    public func removeClone(_ id: CloneID) {
        clones.removeValue(forKey: id)
        cloneOrder.removeAll { $0 == id }
    }

    public func removeAllClones() {
        clones.removeAll(keepingCapacity: true)
        cloneOrder.removeAll(keepingCapacity: true)
    }

    public func cloneSnapshot(_ id: CloneID) -> CloneSnapshot? { clones[id]?.currentSnapshot() }

    @discardableResult
    public func stepClones() -> [CloneSnapshot] { cloneOrder.compactMap { clones[$0]?.advanceOneTick() } }
}

extension PlayerController: ReplayStateSource {}
