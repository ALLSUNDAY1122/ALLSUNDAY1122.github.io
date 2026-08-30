# Session A Core Gameplay Architecture

## Implementation direction

Target language: Swift, framework-light core logic suitable for direct inclusion in an iOS/SpriteKit/Metal shell. Session A will avoid UIKit/SwiftUI and avoid build/project files so Session C can integrate the source into the final iOS target.

The simulation will be deterministic and fixed-step. Rendering/camera presentation may run at display refresh rate, but locomotion, ability state, timers and replay capture advance on fixed ticks.

## Modules

- `Game/Core/`: game clock, math/value types, event/signals, lap/checkpoint state.
- `Game/Player/`: player controller/state machine and externally visible snapshot.
- `Game/Physics/`: collision queries, swept movement, contact classification, corner correction.
- `Game/Abilities/`: jump, air jump, dash, wall jump policies/resources.
- `Game/Replay/`: recording format, recorder, versioning, correction samples.
- `Game/Ghost/`: clone instances, loop playback and multi-clone coordination.
- `Game/Camera/`: deterministic follow target state/room handoff abstraction; no UIKit rendering.
- `Tests/Core/`: behavioural and determinism tests only.

## Simulation order per fixed tick

1. Latch input transitions and buffered action requests.
2. Update timers (coyote, jump buffer, dash, wall lock, invulnerability/respawn as applicable).
3. Resolve action priority: death/respawn > active dash continuation > buffered wall jump > buffered ground/air jump > movement.
4. Build desired velocity from abilities and locomotion state.
5. Perform swept collision movement and contact resolution.
6. Recompute grounded/wall/ceiling contacts.
7. Reset/consume ability resources from the resolved contacts.
8. Emit state-transition signals.
9. Capture replay sample after authoritative resolution.
10. Publish immutable player snapshot for camera/render consumers.

## Determinism policy

- Fixed simulation tick target: 1/120 s.
- UI/display frame delta is accumulated and never fed directly into core movement formulas.
- Maximum catch-up steps per render frame is capped to prevent spiral-of-death; excessive accumulated time is surfaced as a diagnostic rather than changing game speed unpredictably.
- Collision queries must be deterministic for identical geometry/query order.
- Replay captures simulation ticks, not wall-clock timestamps.

## Action priority policy

The reference game contains useful emergent techniques where dash and jump overlap. We preserve these intentionally while removing accidental dropped inputs:
- jump request during dash is buffered and may also form a dash-jump if received within the configured combo window;
- wall contact during dash keeps enough horizontal momentum for dash-wall-jump conversion;
- wall-jump impulse temporarily owns horizontal velocity, then hands back to player air control;
- neutral dash uses facing direction, never stale unrelated state;
- head collision cancels upward velocity but does not incorrectly consume/restore air-jump resource.

## No cross-session coupling

Session A does not know about currency, upgrades pricing, stage geometry ownership, menus, touch controls, app lifecycle, code signing, build systems, or App Store Connect. Those systems consume Session A only through `PUBLIC_API_CONTRACT.md`.
