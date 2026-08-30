# IGTAP-equivalent Core Gameplay Reference Spec

Updated: 2026-08-30
Scope: mechanics/feel only. Do not copy IGTAP names, art, music, text, characters, or stage layouts.

## Confirmed observations

Sources used:
- Official itch demo page: https://varii-peppertangogames.itch.io/igtap-but-patched
- Official Steam page/community: https://store.steampowered.com/app/4364730/IGTAP/
- Pirate Software Game Jam submission/comments: https://itch.io/jam/pirate17/rate/3753765
- June 7 demo notes surfaced on galaxy.click: platforming physics were reworked in that update.

### Core locomotion
- 2D precision platformer with left/right movement, variable-height jump, wall jump, mid-air jump and dash mobility.
- Jump height depends on how long jump is held; player feedback explicitly references holding jump for higher/longer jumps.
- The game is intended to feel tight/responsive and rewards exact route optimisation.
- Coyote/buffer tolerance is important. The original developer explicitly acknowledged missing/insufficient wall-jump and dash buffering in the jam build and later physics changes.
- Wall jump applies a short movement lock after launch. In the older build, moving away from the wall before jump could cancel the opportunity; the developer described this as needing wall coyote time.
- Dash-jump preserves horizontal dash speed while adding jump lift. Community runs use simultaneous/near-simultaneous dash+jump as a core speed technique.
- Dash-wall-jump can convert dash momentum into unusually strong vertical travel when jump is triggered as dash reaches a wall.
- In older builds, dashing while fully attached to a wall was inconsistent/blocked; current equivalence target should preserve the useful dash-wall-jump technique but remove accidental input loss.
- Player comments report that a neutral dash once used the last dash direction rather than facing direction; developer called this a bug. Target behaviour: neutral dash follows current facing, then last non-zero move direction as fallback.

### Abilities and resources relevant to Session A
- Mobility abilities are progression-gated and include wall jump, air/double jump, and dash.
- Air jump and dash are finite airborne resources and are reset by grounding; certain environmental bounce interactions in the reference also reset them, but environment ownership belongs outside Session A.
- Ability state must therefore be externally enable/disable-able and must expose reset hooks without depending on stage/economy code.

### Death / checkpoint / respawn
- Hazard contact/invalid falls cause death and rapid respawn.
- Reference play is forgiving because checkpoints are frequent and respawn is fast.
- Historical builds had checkpoint/respawn bugs where a later spawn point could leak into a restarted course. Target behaviour must bind respawn deterministically to the active checkpoint/course context.
- Death must not corrupt camera target, replay recording, or clone playback.

### Clone / replay behaviour
- Clones replay the player's best recorded course route rather than executing a pre-authored AI route.
- Improving the player's recorded route improves clone efficiency; old courses can be re-recorded after mobility upgrades.
- Multiple clones can replay the same best route concurrently and loop continuously.
- Visual identity between player and clones must be separable by Session C/UI, but Session A only exposes clone identity/state.
- The reference concept is effectively deterministic ghost playback. For mobile parity, Session A will record authoritative sampled state plus input/state metadata, then use correction checkpoints to prevent long-run drift.

## Targeted quality improvements versus observed reference bugs

The goal is experience equivalence, not bug equivalence. The following observed issues are deliberately not reproduced:
- ignored jump immediately before dash completion;
- no wall-jump coyote tolerance;
- inconsistent dash from/near a wall;
- stale dash direction when no direction is held;
- double-jump state becoming inconsistent after death/head collision;
- camera remaining in a previous room after death;
- checkpoint state leaking across course restarts;
- high-speed collision tunnelling.

## Inferred values to be tuned empirically

The exact numeric constants are not publicly documented. Initial implementation will use tunable values and tests rather than hard-coded assumptions:
- max ground speed;
- ground acceleration/deceleration;
- air acceleration/deceleration;
- gravity and terminal velocity;
- initial jump velocity;
- jump-cut multiplier / held-jump gravity multiplier;
- coyote duration;
- jump-buffer duration;
- wall-coyote duration;
- wall-jump horizontal/vertical impulse and movement-lock duration;
- dash speed/duration/cooldown;
- corner correction tolerance;
- fixed simulation step.

Initial quality target: deterministic 120 Hz simulation with rendering decoupled from simulation. 60 Hz and 120 Hz displays must produce materially equivalent trajectories.
