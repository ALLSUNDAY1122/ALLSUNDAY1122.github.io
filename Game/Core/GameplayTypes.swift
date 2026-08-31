import Foundation

public enum PlayerAbility: Hashable, Sendable {
    case jump
    case variableJump
    case airJump
    case dash
    case wallJump
}

public enum PlayerLocomotionState: Equatable, Sendable {
    case grounded
    case airborne
    case dashing
    case wallJumping
    case dead
}

public enum DeathReason: Equatable, Sendable { case hazard; case fall; case scripted(String) }

public struct SpawnPoint: Equatable, Sendable {
    public var position: Vector2
    public var facing: Int
    public init(position: Vector2, facing: Int = 1) { self.position = position; self.facing = facing >= 0 ? 1 : -1 }
}

public struct CheckpointDescriptor: Equatable, Sendable {
    public var id: String
    public var spawn: SpawnPoint
    public init(id: String, spawn: SpawnPoint) { self.id = id; self.spawn = spawn }
}

public enum CheckpointScope: Sendable { case active; case all }

public struct DeathEvent: Equatable, Sendable {
    public var reason: DeathReason
    public var position: Vector2
    public init(reason: DeathReason, position: Vector2) { self.reason = reason; self.position = position }
}

public struct CheckpointEvent: Equatable, Sendable {
    public var checkpoint: CheckpointDescriptor
    public init(checkpoint: CheckpointDescriptor) { self.checkpoint = checkpoint }
}

public struct LapEvent: Equatable, Sendable { public var courseID: String; public var elapsed: Double }
public struct RecordingEvent: Equatable, Sendable { public var frameCount: Int }

public enum CoreGameplaySignal: Equatable, Sendable {
    case playerDied(DeathEvent)
    case checkpointReached(CheckpointEvent)
    case lapCompleted(LapEvent)
    case recordingCompleted(RecordingEvent)
}

public protocol CoreGameplaySignalSink: AnyObject { func emit(_ signal: CoreGameplaySignal) }

public protocol PlayerControlling: AnyObject {
    func setMoveAxis(_ axis: Float)
    func setJumpPressed(_ pressed: Bool)
    func requestJump()
    func requestDash()
    func requestWallJump()
    func setAbility(_ ability: PlayerAbility, enabled: Bool)
    func kill(reason: DeathReason)
    func respawn(at spawn: SpawnPoint?)
}

public protocol CheckpointAccepting: AnyObject {
    func reachCheckpoint(_ checkpoint: CheckpointDescriptor)
    func clearCheckpoint(scope: CheckpointScope)
}
