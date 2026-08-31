# Session A Replay / Clone Public Contract

This is an additive detail contract under the root `Game/Core/PUBLIC_API_CONTRACT.md`. Session C should depend only on the public types/methods below, not recorder or clone internals.

## Fixed-tick ordering

Replay uses the same authoritative 120 Hz fixed tick as player physics.

Recommended order for each `FixedStepClock` tick:

1. Sample platform input and send commands to `PlayerController`.
2. Run `player.step(dt:)`.
3. Call `replay.captureTick(tick:state:input:)` with the same normalized input sample.
4. Forward checkpoint/death/lap semantic markers with `recordMarker(tick:kind:)`.
5. Call `replay.stepClones()` once.
6. Render player/clone snapshots using display interpolation only.

Marker calls are safe immediately before or after capture of the same tick. Marker-to-frame resolution is deferred until recording finalization, avoiding signal-order dependence.

## Commands

`ReplaySystem` conforms to `ReplayControlling`:

```swift
func startRecording(context: ReplayContext)
func stopRecording() -> ReplayRecording?
func clearRecording(for courseID: String?)
func spawnClone(recording: ReplayRecording, options: CloneSpawnOptions) -> CloneID
func removeClone(_ id: CloneID)
func removeAllClones()
```

Additive fixed-tick methods:

```swift
func captureTick(tick: UInt64, state: any ReplayStateSource, input: ReplayInputSample) -> Bool
func recordMarker(tick: UInt64, kind: ReplayMarkerKind) -> Bool
func stepClones() -> [CloneSnapshot]
func cloneSnapshot(_ id: CloneID) -> CloneSnapshot?
func bestRecording(for courseID: String) -> ReplayRecording?
```

`PlayerController` conforms to `ReplayStateSource`; Session C does not need to reach into player internals.

## What is recorded

Every captured fixed tick stores authoritative tick, position, velocity, normalized input metadata, locomotion state, air-jump resource, air-dash availability, facing, and alive/dead state. Semantic markers support checkpoint reached, player death, and lap completion.

## Clone playback

V1 Clone playback is authoritative sampled-state playback, not input re-simulation. Each Clone copies the recorded frame state exactly on each fixed tick. Input is preserved as metadata for diagnostics/future deterministic re-simulation but does not drive V1 Clone physics.

This intentionally prevents accumulated integration drift. Rendering may interpolate between Clone snapshots, but interpolation must never feed back into playback state.

Clone options support loop on/off, starting frame, and phase delay in fixed ticks. Multiple clones own independent cursors and loop counters.

## Death and checkpoint behavior

A recorded dead frame replays as dead but does not destroy or stop the Clone playback object. A looping Clone naturally returns to the first recorded state at the next loop.

Checkpoint/death/lap markers appear in `CloneSnapshot.markers` exactly when their recorded frame is played, once per loop. Live player death/checkpoint state does not mutate existing Clone cursors.

## Best recording semantics

`ReplaySystem` keeps the shortest completed recording per `courseID` using authoritative duration ticks. A slower later run does not overwrite the current best. Session B/C remains responsible for deciding when a course run starts/finishes and for persistence across app launches.

## Format safety

Current format version: `ReplayFormat.currentVersion == 1`.

`ReplayRecording` validates supported version, non-empty frames, strictly monotonic ticks, and marker frame bounds. Unsupported future versions fail with `ReplayValidationError.unsupportedVersion` rather than silently misplaying.

## Integration boundaries

Session A does not persist recordings to disk, award progression, choose UI appearance, or define course geometry. Session C may serialize validated recordings later, but must preserve format version and fixed-tick ordering.
