# Session A / Next 1 Evidence

Date: 2026-08-31 JST
Branch: `igtap/wp1-core-gameplay`

## Implemented
- horizontal movement with acceleration/deceleration and facing
- gravity and terminal fall speed
- grounded jump
- variable jump height via release cut
- floor/wall/ceiling contacts
- swept axis collision crossing checks to avoid ordinary fixed-step tunnelling
- coyote time
- jump buffering, including immediate buffered jump on landing tick
- death state, delayed respawn, checkpoint-aware respawn
- `playerDied` and `checkpointReached` signal emission

## Verification
Compiled and executed with Swift 6.2.1 on Linux using production sources plus `Tests/Core/PlayerCoreTestMain.swift`.
Result: `PASS: 6 Core Gameplay test groups`.

Covered groups:
1. horizontal acceleration/deceleration
2. jump and variable jump cut
3. wall and ceiling collision
4. coyote time
5. jump buffer
6. death/checkpoint respawn and signals

## Public API
No breaking change to `Game/Core/PUBLIC_API_CONTRACT.md`. Concrete public value types and `PlayerController` now implement the previously documented Player/Checkpoint surface. `requestDash()` and `requestWallJump()` remain intentional no-ops until Next 2.

## Known limitations for later scheduled passes
- air jump, dash, wall jump, ability resource semantics: Next 2
- 60/120 render-rate integration, corner policy and aggressive high-speed stress tuning: Next 3
- replay/clone: Next 4
- final combinatorial soak: Next 5

## Integration notes
Session C should feed static stage collision geometry through `CollisionWorld` and call `PlayerController.step(dt:)` from the gameplay fixed-step loop. Session A does not own stage layout or iOS input plumbing.
