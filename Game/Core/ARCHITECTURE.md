# Session A Core Gameplay Architecture

Status: final Session A handoff, 2026-09-01.

## Implementation direction

The Core implementation is pure Swift with Foundation only and does not depend on UIKit, SwiftUI, SpriteKit, progression, economy, or App Store infrastructure. It is designed to be driven from an iOS/native adapter or another integration layer through explicit public contracts.

The authoritative simulation is fixed-step. Rendering may run at another refresh rate, but player movement, ability state, timers, lap timing, replay capture, Clone advancement, and camera target solving are intended to use the same fixed tick.

## Modules

- `Game/Core/`: math/value types, public signals, fixed clock, lap timing, contracts.
- `Game/Player/`: player controller/state machine and tunable movement constants.
- `Game/Physics/`: deterministic AABB collision, bounded high-speed substeps, contact probing, depenetration.
- `Game/Replay/`: versioned authoritative fixed-tick recording and validation.
- `Game/Ghost/`: Clone cursor, loop/non-loop playback, phase offsets.
- `Game/Camera/`: deterministic engine-independent camera target solver.
- `Tests/Core/`: behavioural, determinism, stress, and integration-ready audits.

`Game/Abilities/` is intentionally not required as a separate implementation directory; ability policy is currently compact enough to remain inside `PlayerController`/`PlayerConfig` while still being externally gated through `PlayerAbility`.

## Fixed-tick order

Recommended Session C order for each `FixedStepClock` tick:

1. latch normalized input and issue Player requests;
2. `player.step(dt:)`;
3. forward checkpoint/lap/death semantics for the current tick as needed;
4. `replay.captureTick(...)` after Player authoritative resolution;
5. `replay.stepClones()`;
6. `camera.step(...)` from resolved Player state;
7. publish value snapshots to rendering/UI.

Replay semantic markers are order-independent relative to same-tick capture and are resolved safely at recording finalization.

## Determinism policy

- Default fixed delta: `1 / 120 s`.
- Display delta is accumulated by `FixedStepClock`; it is never fed directly into movement formulas.
- Catch-up work is capped and excess time is exposed as `droppedTime`.
- Collision results are deterministic for identical geometry and solid iteration order.
- Lap timing and Replay use simulation ticks, not wall-clock timestamps.
- Replay V1 requires contiguous fixed ticks.
- Clone V1 applies authoritative sampled state on every tick, eliminating accumulated integration drift.

## Action priority / speed-tech policy

The equivalent-feel target preserves useful dash/jump overlap while removing dropped-input bugs:

1. valid wall jump wins over all other actions;
2. simultaneous eligible ground dash+jump becomes a combined dash-jump with dash horizontal speed plus jump lift;
3. ordinary ground/coyote/air jump follows;
4. dash follows when no higher-priority jump action resolves.

A ground-origin dash preserves ground-jump eligibility for the dash window after leaving a ledge. A jump during an active ground dash cancels the dash timer but retains current horizontal dash momentum. Wall impact terminates active dash immediately so the next valid wall-jump tick is deterministic.

## Collision policy

The player uses bounded substeps plus axis crossing checks. Resting floor/wall/ceiling contact is explicitly probed, so zero-axis velocity does not flicker contact state. Defensive depenetration handles small spawn/teleport overlaps. The solver is designed around configured player speeds and is not intended as an unbounded general-purpose rigid-body engine.

## Replay / Clone policy

Replay V1 stores every authoritative fixed-tick state plus normalized input metadata and semantic markers. Input metadata is retained for future compressed/resimulation formats, but V1 Clone playback does not numerically resimulate Player movement. Invalid versions, non-monotonic ticks, tick gaps, out-of-bounds markers, and marker tick/frame mismatches fail safely.

## Cross-session boundary

Session A does not own currency, upgrade pricing, stage content, UI, touch input, app lifecycle, persistence, native/Godot bridge implementation, code signing, CI, or App Store Connect. Those systems consume Session A through `PUBLIC_API_CONTRACT.md`, `PUBLIC_REPLAY_CONTRACT.md`, and `SESSION_C_HANDOFF.md`.
