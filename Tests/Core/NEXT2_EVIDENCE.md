# Session A / Next 2 Evidence — Advanced Actions

Date: 2026-08-31 JST
Branch: `igtap/wp1-core-gameplay`
Scope: `Game/Core/**`, `Game/Player/**`, `Game/Abilities/**`, `Game/Physics/**`, `Tests/Core/**` only.

## Implemented

- One-charge air/double jump with deterministic ground reset.
- Horizontal dash with buffered input, ground/air eligibility, one airborne dash resource, facing/axis direction selection, exit momentum retention, and gradual overspeed decay.
- Wall jump from natural jump input or explicit `requestWallJump()`, including wall grace and short post-launch control lock.
- Air control and inertia rules that preserve high-speed momentum instead of snapping immediately to run speed.
- Deterministic action priority: valid wall jump > normal/air jump > dash.
- Dash-jump cancellation: a valid jump during a ground-origin dash cancels dash state while preserving horizontal momentum.
- Immediate per-ability enable/disable behavior with transient resource cleanup.
- Public read-only locomotion/resource state for later replay capture: `locomotionState`, `airJumpsRemaining`, `airDashAvailable`.

## Defaults / progression boundary

Advanced abilities remain OFF by default (`airJump`, `dash`, `wallJump`). Session B/C must unlock them only through `setAbility(_:enabled:)`; Session A does not import progression state.

## Verification

Compiler/runtime: Swift 6.2.1 on Linux.

Command:

```sh
swiftc -warnings-as-errors \
  Game/Core/Math2D.swift \
  Game/Core/GameplayTypes.swift \
  Game/Physics/CollisionWorld.swift \
  Game/Player/PlayerConfig.swift \
  Game/Player/PlayerController.swift \
  Tests/Core/Next2TestMain.swift \
  -o /tmp/igtap-next2-tests
/tmp/igtap-next2-tests
```

Result:

`PASS: 18 Next2 Core Gameplay test groups`

Coverage includes baseline movement/jump regression, ceiling collision, coyote time, jump buffering, checkpoint/death signals, air jump charge/reset, ground dash, air dash one-shot resource, dash jump window, natural/explicit wall jumps, explicit wall-jump isolation, wall-jump control lock/recovery, same-tick action priority, ability disable cleanup, overspeed inertia, variable-jump toggle, death/respawn advanced-state cleanup, and advanced-ability default-off behavior.

## Failure found and fixed during macro loop

Initial test exposed a real sequencing bug: a ground-origin dash could overwrite vertical jump velocity late in the dash window. `performGroundJump()` now terminates the active dash before gravity/movement resolution, preserving the horizontal dash momentum while allowing the jump to take effect.

## Public API change

No required protocol method was removed or renamed. Added `PlayerLocomotionState` and read-only state on `PlayerController` for deterministic inspection/replay capture. Existing `PlayerControlling` contract remains source-compatible.

## Known limitations deferred to Next 3

- Exact 60/120 Hz equivalence and fixed-step accumulator integration.
- Persistent resting-contact probing (floor/wall contact while velocity is exactly zero).
- High-speed corner/diagonal collision stress and corner correction.
- Final dash constants / feel tuning against reference measurements.
- Camera response tuning.

No known Next-2-blocking defect remains.
