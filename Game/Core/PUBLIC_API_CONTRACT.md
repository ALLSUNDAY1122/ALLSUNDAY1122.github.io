# Session A Public API / Signal Contract

Status: integration-ready (Session A Next 5, 2026-09-01)

This file defines the supported integration surface for Session C. Session B/C must not mutate Session A internals such as velocity, ability counters, replay cursors, timers, or collision contacts.

## Player commands

```swift
public protocol PlayerControlling: AnyObject {
    func setMoveAxis(_ axis: Float) // clamped to -1...1
    func setJumpPressed(_ pressed: Bool)
    func requestJump()
    func requestDash()
    func requestWallJump()
    func setAbility(_ ability: PlayerAbility, enabled: Bool)
    func kill(reason: DeathReason)
    func respawn(at spawn: SpawnPoint?)
}
```

`requestWallJump()` is optional for input/UI integration; ordinary jump input while a wall jump is valid resolves to a wall jump automatically.

### Ability identifiers

```swift
public enum PlayerAbility: Hashable, Sendable {
    case jump
    case variableJump
    case airJump
    case dash
    case wallJump
}
```

Advanced abilities (`airJump`, `dash`, `wallJump`) are OFF by default. Session B/C unlock them only through `setAbility(_:enabled:)`. Disabling an ability immediately clears transient resources owned by that ability.

### Action priority and dash-jump contract

For conflicting requests on a fixed simulation tick:

1. valid wall jump;
2. combined ground dash+jump when dash and jump arrive on the same eligible tick;
3. ordinary ground/coyote/air jump;
4. dash.

A ground-origin dash carries a jump-eligibility window through the configured dash duration even after leaving a ledge. This prevents 60/120 Hz input grouping from deleting the intended dash-jump technique.

## Checkpoints

```swift
public protocol CheckpointAccepting: AnyObject {
    func reachCheckpoint(_ checkpoint: CheckpointDescriptor)
    func clearCheckpoint(scope: CheckpointScope)
}
```

A checkpoint signal emits only when the active checkpoint identifier changes. Death/automatic respawn uses the active checkpoint, otherwise the initial spawn. Session A does not award progression or currency.

## Lap timing

```swift
public protocol LapTiming: AnyObject {
    @discardableResult
    func beginLap(courseID: String, atTick tick: UInt64) -> Bool

    @discardableResult
    func finishLap(courseID: String, atTick tick: UInt64) -> LapEvent?

    func cancelLap(courseID: String)
    func cancelAllLaps()
}
```

Use `FixedTickLapTimer`, and pass ticks from the same `FixedStepClock` that advances gameplay. `finishLap` emits `lapCompleted` exactly once for an active lap and measures elapsed time from fixed ticks rather than wall-clock time.

## Integration signals

```swift
public enum CoreGameplaySignal: Sendable {
    case playerDied(DeathEvent)
    case checkpointReached(CheckpointEvent)
    case lapCompleted(LapEvent)
    case recordingCompleted(RecordingEvent)
}
```

Session C may map these events into its own event bus/UI layer. Session A imports no economy, progression, UI, iOS lifecycle, analytics, build, or App Store code.

## Fixed-step integration

Gameplay is authoritative at 120 Hz by default. Display refresh rate must not be used directly as the physics timestep.

```swift
var clock = FixedStepClock()

clock.advance(frameDelta: displayDelta) { fixedDelta, tick in
    // 1. apply normalized input requests to player
    player.step(dt: fixedDelta)

    // 2. record resolved authoritative player state
    replay.captureTick(tick: tick, state: player, input: replayInput)

    // 3. advance clones on the same fixed tick
    let cloneSnapshots = replay.stepClones()

    // 4. update camera from the resolved player state
    camera.step(
        dt: fixedDelta,
        target: player.position,
        velocity: player.velocity,
        facing: player.facing
    )
}
```

`FixedStepFrame.interpolationAlpha` is render-only and must not feed back into gameplay. Long stalls are clamped; `droppedTime` is diagnostic and must not be replayed as a giant variable timestep.

## Camera

`CameraFollower` is UI/engine independent.

- Call `step(dt:target:velocity:facing:)` on the fixed tick.
- Call `snap(to:facing:)` after an explicit scene/course teleport or immediate respawn camera cut.
- Large target discontinuities also self-snap using `teleportSnapDistance`.
- Camera state never changes physics, progression, checkpoints, or replay data.

## Replay / Clone

```swift
public protocol ReplayControlling: AnyObject {
    func startRecording(context: ReplayContext)
    func stopRecording() -> ReplayRecording?
    func clearRecording(for courseID: String?)
    func spawnClone(recording: ReplayRecording, options: CloneSpawnOptions) -> CloneID
    func removeClone(_ id: CloneID)
    func removeAllClones()
}
```

Additional fixed-tick methods on `ReplaySystem`:

- `captureTick(tick:state:input:)`
- `recordMarker(tick:kind:)`
- `stepClones()`
- `cloneSnapshot(_:)`
- `bestRecording(for:)`

Replay V1 requires one authoritative sample for every consecutive fixed tick. A missing tick invalidates the recording instead of silently time-compressing Clone playback. Clone playback applies recorded authoritative state every tick, so numerical drift does not accumulate across loops.

See `Game/Replay/PUBLIC_REPLAY_CONTRACT.md` for validation and persistence rules.

## Threading / ownership

All mutation occurs on one gameplay simulation executor/game loop. Value-type snapshots may be copied for rendering. Reference types in Session A are marked for controlled game-loop ownership; callers must not mutate them concurrently.

## Session C boundary

Session C is responsible for input/platform adapters, rendering, stage trigger wiring, persistence, iOS lifecycle, build/signing, and TestFlight. Session A is responsible only for deterministic gameplay state and the public contracts above.
