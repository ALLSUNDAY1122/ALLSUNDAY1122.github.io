# Session A / Next 4 Evidence — Replay & Clone

Date: 2026-08-31 JST
Branch: `igtap/wp1-core-gameplay`
Scope: `Game/Replay/**`, `Game/Ghost/**`, `Tests/Core/**` only. Existing Session A player state is consumed through a protocol bridge; Session B/C files are untouched.

## Implemented

- Versioned Replay data model with strict validation.
- Fixed-tick authoritative recording of position, velocity, normalized input metadata, locomotion state, ability resources, facing and alive/dead state.
- Start/stop/clear recording commands.
- Per-course best-run retention by shortest duration ticks.
- `recordingCompleted` signal emission.
- Checkpoint/death/lap semantic markers.
- Marker ordering independence: signals arriving immediately before or after same-tick capture align deterministically at finalization.
- `PlayerController: ReplayStateSource` bridge without exposing private player internals.
- Clone spawn/remove/remove-all.
- Exact sampled-state playback.
- Loop and non-loop playback.
- Start-frame and phase-offset support.
- Multiple independent Clone cursors.
- Per-loop marker reproduction.
- Recorded death frames reproduce without killing the Clone playback object.
- Long-run drift suppression by authoritative frame application on every fixed tick.
- Unsupported replay-format versions fail safely.

## Playback strategy

V1 stores every authoritative fixed-tick state. Clone playback therefore does not numerically integrate recorded input; it advances a cursor and applies the recorded state exactly. This is stronger than periodic correction for the current mobile target: error cannot accumulate between correction points because every tick is authoritative.

Input metadata remains in the recording so a later compressed/resimulated format can be added under a new format version without changing gameplay command semantics.

## Verification

Compiler/runtime: Swift 6.2.1 on Linux.

Primary local test result:

`PASS: 24 Next4 Replay/Clone test groups`

Coverage includes:

1. Authoritative state/input capture.
2. Monotonic tick rejection.
3. `recordingCompleted` signal.
4. Best recording replacement by faster run.
5. Scoped/global recording clear.
6. Exact Clone frame playback.
7. Exact loop reset.
8. Non-loop finish/last-frame hold.
9. Independent multi-Clone phase.
10. Marker replay once per loop.
11. Death-frame replay and next-loop recovery.
12. Checkpoint marker alignment.
13. 200,000-tick single-Clone zero-drift stress.
14. Clone removal.
15. New recording resets abandoned partial recording.
16. Empty recording safe stop.
17. Unsupported future format rejection.
18. Malformed/non-monotonic recording rejection.
19. Start-frame clamp.
20. Input-axis normalization.
21. Marker-before-capture same-tick ordering.
22. Finished non-loop Clone does not repeat terminal marker.
23. 32 simultaneous Clones for 20,000 ticks remain authoritative and phase-safe.
24. Future marker without corresponding captured frame is discarded rather than attached to stale state.

Bridge compile check:

`PASS: PlayerReplayState bridge compiles against PlayerController public state surface`

The branch `PlayerController` exposes all seven required read-only properties: position, velocity, facing, locomotionState, airJumpsRemaining, airDashAvailable, and isAlive.

## Failures found and fixed during macro loop

Initial marker implementation resolved a semantic marker immediately against the latest recorded frame. If a checkpoint/death signal arrived just before capture of its fixed tick, it could attach to the prior frame. Marker storage now preserves the semantic tick first and resolves frame indices only when the recording is finalized. A future marker that never receives a corresponding captured frame is discarded safely.

A second audit found that a non-loop Clone could repeatedly expose the final frame's marker after completion. `currentSnapshot()` is marker-free, so terminal markers emit exactly once through active `advanceOneTick()` playback.

## Public API changes

No existing required Replay command was removed or renamed.

New public types include `ReplayFormat`, `ReplayContext`, `ReplayInputSample`, `ReplayResourceState`, `ReplayStateSource`, `ReplayFrame`, `ReplayMarkerKind`, `ReplayMarker`, `ReplayRecording`, `ReplayValidationError`, `CloneID`, `CloneSpawnOptions`, `CloneSnapshot`, and `ReplaySystem`.

Additive fixed-tick methods are `captureTick(tick:state:input:)`, `recordMarker(tick:kind:)`, `stepClones()`, `cloneSnapshot(_:)`, and `bestRecording(for:)`.

## Integration notes for Session C

- Call Replay capture and Clone advance on the same 120 Hz fixed tick introduced in Next 3.
- Supply `ReplayInputSample` from Platform/Input using the same normalized commands sent to the player.
- Forward checkpoint/death/lap semantic events with the current fixed tick; before/after same-tick capture is supported.
- Render `CloneSnapshot`; do not mutate Clone cursor/state directly.
- Persistence is intentionally not owned here. If Session C persists Replay data, retain and validate the format version.
- Session C may visually distinguish Clones, but visual identity is not part of Replay state.

## Known limitations deferred to Next 5 / integration

- Full repository-wide compile/build remains Session C responsibility because Session A does not own the project/build manifest.
- Recording persistence/serialization is not implemented in Session A.
- V1 prioritizes determinism over storage compression by sampling every fixed tick. Compression can be a future version if profiling proves it necessary.
- Final all-feature combination audit is Next 5.

No known Next-4-blocking defect remains.
