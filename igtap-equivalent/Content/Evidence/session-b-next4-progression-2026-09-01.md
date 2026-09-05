# Session B Next4 Evidence — Progression

Date: 2026-09-01 JST
Branch: `igtap/wp2-progression-world`
Implementation commit: `5ecdfb64dfdadb7565dd5661d8169c495e9a230d`

## Scope completed

- Added authoritative progression catalog and runtime subsystem.
- Added discrete ability unlock chain: speed tune, dash, double jump, wall jump, phase shift.
- Added optional jump tuning and global clone-capacity progression.
- Added explicit Session A mapping: dash→dash, double_jump→airJump, wall_jump→wallJump; speed/jump tuning remain numeric effects; phase_shift remains world-only.
- Added aggregate progression purchase routing through ProgressionWorld.
- Added one authoritative composite stage availability result combining previous-clear state and mandatory ability state.
- Added progression state to aggregate save schema version 2 while retaining version-1 restore compatibility.
- Added global clone-capacity enforcement across all stage profiles.
- Added capacity-safe first-route auto clone allocation.
- Added Speed Tune backward-use shortcut to Relay Yard so every core unlock has both forward and revisit value.
- Added progression regression tests and balance simulation.

## Mandatory progression loop

1. Clear Relay Yard → purchase `speed_tune` → Liftworks becomes playable.
2. Clear Liftworks → purchase `dash` → Phase Foundry becomes playable.
3. Clear Phase Foundry → purchase `double_jump` → Blackout Array becomes playable.
4. Clear Blackout Array → purchase `wall_jump` → Core Spire becomes playable.
5. Clear Core Spire → purchase `phase_shift` → endgame revisit/mastery routes open.

Raw StageManager unlock is deliberately not enough to make a stage playable. `ProgressionWorld.stage_availability()` is authoritative and returns explicit reasons such as `requires_previous_clear` and `requires_ability`.

## Progression prices

Original project tuning:

- speed_tune level 1: 24 Flux
- dash: 68 Flux
- double_jump: 190 Flux
- wall_jump: 540 Flux
- phase_shift: 1500 Flux
- jump_tune: optional geometric track
- clone_capacity: optional geometric track, base capacity 1 and +1 per level up to level 8

## Conservative mandatory-wait simulation

The simulation intentionally assumes no economic-upgrade purchases. Each newly cleared stage contributes its first-clear reward and its target-time clone production.

Mandatory ability waits:

- speed_tune: 23.81 s
- dash: 22.10 s
- double_jump: 22.26 s
- wall_jump: 30.10 s
- phase_shift: 45.01 s

Maximum wait: 45.01 s.

This remains below the 90 s target and far below the 180 s failure threshold even without Flux Coils / Loop Compression / Route Dividend assistance.

## Forward / backward ability audit

- `speed_tune`: forward gate to Liftworks; backward Relay Yard tuned-belt shortcut.
- `dash`: forward gate to Phase Foundry; Relay Yard/Liftworks revisit shortcuts.
- `double_jump`: forward gate to Blackout Array; secrets in earlier stages.
- `wall_jump`: forward gate to Core Spire; Phase Foundry/Blackout Array shortcuts.
- `phase_shift`: post-Core world ability; Blackout secret plus Core Spire shortcut/secret.

No secret is required for mandatory stage progression.

## Clone-capacity audit

Global capacity is authoritative across all stages.

At base capacity 1, first-record auto allocation resolves as:

`[1, 0, 0, 0, 0]`

for five newly recorded stages if the player never reallocates or purchases capacity. New recordings therefore cannot silently exceed capacity.

`set_clone_count(stage_id, count)` also calculates allocation on every other stage and rejects a requested total above the current global capacity.

## Failures found and fixed

1. `speed_tune` originally had forward value but no explicit backward-route use. Added `relay_tuned_belt` shortcut in Relay Yard.
2. Direct `unlock_ability()` could create an unlocked ability while its displayed progression upgrade remained level 0. Direct unlock now synchronizes the corresponding minimum unlock level first.
3. Next3 automatically assigned one clone to every newly recorded stage. Under a global capacity model this bypassed the capacity limit. First-route auto assignment now checks `clone_allocation_snapshot().remaining` and assigns one only if capacity exists.
4. Raw StageManager unlock could expose a stage in UI before its mandatory ability purchase. Aggregate `stage_availability` now composes raw clear progression with WorldState entry requirements.
5. `speed_tune`/`jump_tune` were initially at risk of being represented as fake Session A enum abilities. Mapping is explicit: they are numeric movement-effect intents only.

## Validation

In-session deterministic progression simulation checked:

- stage-clear → mandatory ability → next-stage chain;
- backward/revisit use for every core ability;
- conservative mandatory wait sequence;
- global clone-capacity auto-allocation behavior.

All assertions passed. The maximum mandatory wait was 45.01 s.

Repository regression source now includes `test_progression_loop.py` with checks for progression gates, Session A mapping, clone-capacity enforcement, direct-unlock consistency, save schema and the first-route capacity regression.

## Validation limitations

- Godot is still not installed in the execution environment, so GDScript parser/runtime execution was not available.
- Direct repository clone again failed because the execution container could not resolve `github.com`, so repository checkout-based pytest execution could not be performed.
- GitHub connector reads/writes were authoritative, and equivalent progression/balance assertions were executed in-session.
- Session C still must verify the production root inside the Godot project and map movement effects to Session A's Swift configuration path.

## Integration attention

1. Session C should consume `ProgressionWorld.stage_availability()` for stage-select/playability decisions rather than raw StageManager availability.
2. `ability_unlocked` may map dash/double_jump/wall_jump to Session A `dash`/`airJump`/`wallJump`.
3. `movement_effects_changed` carries run-speed and jump multipliers and needs an explicit C→A numeric configuration adapter; Session B does not modify Session A PlayerConfig.
4. `phase_shift` is world-only and should not be passed to Session A PlayerAbility.
5. Clone allocations must be reconciled with actual Session A replay clone instances during Session C integration.
6. No Session A/C-owned file was modified in Next4.
