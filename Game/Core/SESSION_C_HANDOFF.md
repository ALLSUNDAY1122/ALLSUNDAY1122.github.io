# Session C Handoff — Core Gameplay

Status: **integration-ready**
Branch: `igtap/wp1-core-gameplay`
Date: 2026-09-01

## What Session C should consume

Production source files:

- `Game/Core/Math2D.swift`
- `Game/Core/GameplayTypes.swift`
- `Game/Core/FixedStepClock.swift`
- `Game/Core/LapTimer.swift`
- `Game/Player/PlayerConfig.swift`
- `Game/Player/PlayerController.swift`
- `Game/Physics/CollisionWorld.swift`
- `Game/Camera/CameraFollower.swift`
- `Game/Replay/ReplaySystem.swift`
- `Game/Ghost/ClonePlayback.swift`

Contracts:

- `Game/Core/PUBLIC_API_CONTRACT.md`
- `Game/Replay/PUBLIC_REPLAY_CONTRACT.md`

No Session B/C-owned source was modified by Session A.

## Required runtime wiring

Use one authoritative `FixedStepClock` (120 Hz default). Per simulation tick:

```text
Platform/Input -> normalized Player requests
PlayerController.step(fixedDelta)
Stage trigger -> Checkpoint / FixedTickLapTimer / Replay marker
ReplaySystem.captureTick(tick, Player, ReplayInputSample)
ReplaySystem.stepClones()
CameraFollower.step(fixedDelta, Player position/velocity/facing)
Renderer consumes Player/Clone/Camera value state
```

Do not drive Player physics with display-link `dt` directly.

## Signal wiring

Session C must consume:

- `playerDied`
- `checkpointReached`
- `lapCompleted`
- `recordingCompleted`

For Replay semantic fidelity, forward checkpoint/death/lap semantics to `ReplaySystem.recordMarker(tick:kind:)` with the current fixed tick.

## Ability wiring

Session B/C progression unlocks only through:

```swift
player.setAbility(.airJump, enabled: ...)
player.setAbility(.dash, enabled: ...)
player.setAbility(.wallJump, enabled: ...)
```

Base `jump` and `variableJump` begin enabled. Do not mutate ability counters directly.

## Replay persistence

Session A retains best recordings only in memory. If persistence is required, Session C owns serialization/storage. Persist the replay format version and validate loaded data using `ReplayRecording`; do not deserialize unchecked state directly into Clone playback.

Replay V1 is intentionally uncompressed and stores every 120 Hz fixed tick. This favors deterministic equivalence over storage efficiency. Profile real device storage/memory before introducing compression; any compressed representation should be a new replay format version.

## Camera after explicit teleport/respawn

The camera auto-snaps for large discontinuities. For an intentional hard cut, Session C should also call:

```swift
camera.snap(to: player.position, facing: player.facing)
```

after the teleport/scene handoff.

## Important integration boundary: current Session C runtime

At final Session A audit, `igtap/integration` / Session C contains a Godot/GDScript shell under `igtap-equivalent/**`, while Session A Core is implemented in pure Swift under `Game/**`.

There is no current file-path collision, but these are not automatically callable across runtimes. Session C must deliberately choose and implement one bridge strategy:

1. native Swift/iOS gameplay module exposed to the Godot shell through an iOS/native extension/plugin; or
2. a contract-faithful port of Session A behaviour/tests into the runtime Session C ultimately ships.

Session A does not modify Session C's adapter or build files. Treat this runtime bridge as a release-integration task, not as a Core Gameplay defect.

## Acceptance gates for Session C

Before TestFlight, integration should demonstrate on the actual chosen runtime:

- Player movement/jump/dash/wall-jump with ability gating;
- 60 Hz and 120 Hz display delivery through the same 120 Hz simulation clock;
- checkpoint death/respawn and camera snap;
- lap-completed signal;
- Replay recording and Clone looping;
- multiple Clones without cursor cross-talk;
- persistence round-trip if Replay persistence is enabled;
- iPhone real-device input latency and frame pacing.

Session A's Linux/Swift tests prove deterministic Core behaviour; they do not substitute for Session C's iPhone/native bridge and TestFlight validation.
