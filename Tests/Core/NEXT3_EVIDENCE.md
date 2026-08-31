# Session A / Next 3 Evidence — Physics & Feel Quality

Date: 2026-08-31 JST
Branch: `igtap/wp1-core-gameplay`
Scope: Session A ownership only.

## Reference re-check

Re-checked on 2026-08-31:
- Official patched/demo page: https://varii-peppertangogames.itch.io/igtap-but-patched
- Original jam discussion: https://itch.io/jam/pirate17/rate/3753765

Current official-demo comments still include reports of inconsistent double-jump behavior in sequences involving held jump, dash, head collision, and death/retry. Historical developer/community discussion also identifies wall-jump tolerance, dash buffering, dash-wall timing, and camera separation after death as feel/robustness problems. These bugs are deliberately not reproduced; the target is equivalent-or-better mechanical feel.

## Implemented

- Added `FixedStepClock` with 120 Hz authoritative ticks, render interpolation alpha, stall clamping, and explicit dropped-time accounting.
- Verified identical player trajectories and state at 60 Hz and 120 Hz display delivery when both feed the fixed clock.
- Added one-minute fixed-clock drift test and irregular-display-delta test.
- Hardened AABB collision with bounded movement substeps plus axis crossing tests.
- Added defensive initial depenetration for spawn/teleport/rounding overlap.
- Added persistent floor/wall/ceiling contact probing while velocity on the contact axis is zero.
- Added high-speed horizontal/vertical tunneling tests and diagonal-corner penetration test.
- Ground dashes now keep stable floor contact instead of flickering airborne due to zero vertical velocity.
- Dash impact into its facing wall terminates the active dash immediately, allowing deterministic dash-to-wall-jump timing on the next tick.
- Added long-jump -> dash -> air-jump determinism regression to guard the currently reported reference-game failure pattern.
- Added engine-independent `CameraFollower` with dead zones, look-ahead, exponential fixed-step smoothing, velocity-sensitive follow, explicit snap, and automatic large-teleport snap.
- Camera trajectory is verified identical under 60/120 Hz display delivery when updated on the fixed simulation tick.
- Updated the public integration contract with fixed-step and camera usage rules for Session C.

## Verification

Compiler/runtime: Swift 6.2.1 on Linux.

Command:

```sh
swiftc -warnings-as-errors \
  Game/Core/Math2D.swift \
  Game/Core/GameplayTypes.swift \
  Game/Core/FixedStepClock.swift \
  Game/Physics/CollisionWorld.swift \
  Game/Player/PlayerConfig.swift \
  Game/Player/PlayerController.swift \
  Game/Camera/CameraFollower.swift \
  Tests/Core/Next3TestMain.swift \
  -o /tmp/igtap-next3-tests
/tmp/igtap-next3-tests
```

Result:

`PASS: 22 Next3 Core Gameplay quality test groups`

Coverage:
1. 60/120 Hz player equivalence through fixed clock.
2. Stall clamp/drop accounting.
3. One-minute fixed-clock drift.
4. Irregular display-frame delivery.
5. High-speed horizontal collision.
6. High-speed vertical collision.
7. Diagonal corner crossing/penetration.
8. Defensive depenetration.
9. Stable floor contact during zero-Y dash.
10. Stable wall contact with zero-X movement.
11. Dash-wall impact termination and follow-up wall jump.
12. Late dash-jump responsiveness.
13. Held jump -> dash -> air-jump determinism.
14. Coyote + jump-buffer regression.
15. Ability-disable cleanup regression.
16. Death/respawn advanced-resource recovery.
17. Camera dead-zone stability.
18. Camera teleport snap.
19. Camera 60/120 Hz equivalence.
20. Explicit respawn camera snap.
21. Ground move/jumpRegression.
22. Wall-jump grace regression.

## Failure found during macro loop

The first dash-wall quality test attempted the wall jump while simultaneously grounded at the wall. That correctly resolved as a ground jump by the existing priority contract, so the test setup—not production behaviour—was invalid. The test was corrected to exercise an airborne dash impact, the intended speed-tech path, and then passed.

No production defect remained from that investigation.

## Public API / contract changes

No required `PlayerControlling` method was removed or renamed.

Additive integration surface:
- `FixedStepClock`
- `FixedStepFrame`
- `CameraConfig`
- `CameraSnapshot`
- `CameraFollower`

Session C must route display timing through `FixedStepClock`; direct 60/120 Hz variable-delta physics calls are not the supported integration path.

## Known limitations deferred

- Exact numeric movement constants remain empirically tunable because the reference does not publish them.
- Collision substep protection is bounded to 256 micro-steps per gameplay tick. This is far beyond current configured player speeds but intentionally not an unbounded arbitrary-velocity physics engine.
- Stage-specific camera rooms/bounds are owned by Session B/C; Session A provides generic following/snap mechanics only.
- Replay/clone state capture and long-duration correction are Next 4.

No known Next-3-blocking defect remains.
