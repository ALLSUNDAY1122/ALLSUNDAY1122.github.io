# Session A Public API / Signal Contract

This contract is the only integration surface Session C should depend on. Concrete internal types may change while this contract remains source-compatible or receives an explicit version bump.

## Player command surface

```swift
public protocol PlayerControlling {
    func setMoveAxis(_ axis: Float)                 // -1...1
    func setJumpPressed(_ pressed: Bool)
    func requestJump()
    func requestDash()
    func requestWallJump()
    func setAbility(_ ability: PlayerAbility, enabled: Bool)
    func kill(reason: DeathReason)
    func respawn(at spawn: SpawnPoint?)
}
```

`requestWallJump()` is optional for UI; normal jump input while wall-contact is valid must also resolve to a wall jump.

## Ability identifiers

```swift
public enum PlayerAbility: Hashable, Sendable {
    case jump
    case variableJump
    case airJump
    case dash
    case wallJump
}
```

Ability enable/disable is immediate and deterministic. Disabling an ability must clear any transient resource owned only by that ability.

## Replay command surface

```swift
public protocol ReplayControlling {
    func startRecording(context: ReplayContext)
    func stopRecording() -> ReplayRecording?
    func clearRecording(for courseID: String?)
    func spawnClone(recording: ReplayRecording, options: CloneSpawnOptions) -> CloneID
    func removeClone(_ id: CloneID)
    func removeAllClones()
}
```

Clone playback loops by default. Looping behaviour must be configurable through `CloneSpawnOptions`.

## Integration signals

Session A emits typed events through a single sink/stream abstraction. Required semantic events:

```swift
public enum CoreGameplaySignal: Sendable {
    case playerDied(DeathEvent)
    case checkpointReached(CheckpointEvent)
    case lapCompleted(LapEvent)
    case recordingCompleted(RecordingEvent)
}
```

Session C may map these to NotificationCenter, Combine/AsyncStream, an ECS event bus, or engine-specific delegates. Session A must not import UI, economy, progression, iOS platform, build, analytics, or App Store code.

## Checkpoint contract

External stage code may submit a checkpoint identifier and spawn transform. Session A owns only the currently active checkpoint state and deterministic respawn selection.

```swift
public protocol CheckpointAccepting {
    func reachCheckpoint(_ checkpoint: CheckpointDescriptor)
    func clearCheckpoint(scope: CheckpointScope)
}
```

`checkpoint_reached` is emitted exactly once per activation transition, not every physics frame while overlapping.

## Lap/course contract

External stage code defines course start/finish triggers. Session A records timing and emits `lap_completed`; it does not award currency or unlock progression.

```swift
public protocol LapTiming {
    func beginLap(courseID: String)
    func finishLap(courseID: String)
    func cancelLap(courseID: String)
}
```

## Replay determinism contract

A recording contains:
- monotonically increasing fixed-step tick;
- position and velocity samples;
- compact input flags/axis;
- locomotion state;
- ability resource state;
- facing direction;
- checkpoint/lap markers where applicable.

Playback uses fixed-step interpolation plus periodic authoritative state correction. The replay format is versioned. Unknown future versions must fail safely rather than silently misplay.

## Threading / ownership

All mutation occurs on the gameplay simulation executor/main game loop. Read-only snapshots may be consumed asynchronously if copied as value types.

## Integration rule

Session B/C must never reach into Session A internal state to change velocity, counters, replay cursor, or checkpoint bookkeeping. Use commands and signals above. If a missing integration need appears, extend this contract explicitly.
