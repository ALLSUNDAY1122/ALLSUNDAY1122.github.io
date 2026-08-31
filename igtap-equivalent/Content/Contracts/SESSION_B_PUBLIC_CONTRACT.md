# Session B Public Contract

Project root: `igtap-equivalent/`  
Owner: Session B / Progression + World  
Target: Godot 4.x / GDScript  
Primary integration root: `Game/Progression/ProgressionWorld.gd`

Session B never mutates Session A Player/Physics/Abilities/Replay/Ghost internals. Player-affecting world events and movement-effect changes cross the Session C adapter boundary.

## Aggregate production root

`ProgressionWorld` is the Session C binding target.

Session C-compatible signals:

- `stage_context_changed(context: Dictionary)`
- `currency_changed(total: float)` — compatibility projection only.
- `upgrade_purchased(upgrade_id: StringName, level: int)`
- `ability_unlocked(ability_id: StringName)`
- `clone_income_applied(stage_id: StringName, amount: float)` — compatibility projection only.

Precision/progression additions:

- `stage_availability_changed(stage_id, availability)`
- `economy_changed(total, delta, source)`
- `economy_rate_changed(rate)`
- `upgrade_purchase_committed(upgrade_id, level, paid_cost)`
- `movement_effects_changed(effects)`
- `clone_capacity_changed(capacity)`

State surface:

- `register_lap(stage_id, elapsed_seconds, replay_payload = {})`
- `register_death(stage_id, reason)`
- `current_stage_context()`
- `serialize_state()` / `restore_state(state)`
- `stage_select_entries()`
- `stage_availability(stage_id)` / `is_stage_available(stage_id)`
- `select_stage(stage_id)` / `begin_stage(stage_id = &"")`

## Stage lifecycle — Next1

`StageManager` owns attempts, checkpoints, best times, raw sequential stage unlocks and retry state. Manual restart creates a new attempt; death retry preserves the attempt/time; duplicate/non-positive completions are rejected.

From Next4 onward UI/integration must use `ProgressionWorld.stage_availability`, not raw `StageManager.is_stage_available`, because a stage can be cleared-unlocked but still require a purchased ability.

## World / gimmicks — Next2

`WorldState` owns phase, visibility, discoveries and declared ability gates. `GimmickRuntime` re-emits player-affecting spring/hazard requests; Session B never writes player velocity or invokes Session A death methods.

World topology is `Content/World/world_topology_v1.json`. Secrets are optional. New movement/world abilities create revisit value in earlier content.

## Economy — Next3

Authoritative resource snapshots are `{mantissa: float, exponent: int}` representing `mantissa × 1000^exponent`. UI suffixes are presentation only.

Public operations:

- `add_resource`
- `spend_resource`
- `current_resource`
- `resource_per_second`
- `calculate_clone_reward`
- `economy_snapshot`

Active rewards and clone rewards are bounded by speed/quality factors. Passive economy ticks at 0.25 s. Slower recorded routes cannot degrade an existing best clone route.

Economic upgrade tracks remain:

- `flux_coils` → passive income multiplier
- `loop_compression` → clone reward multiplier
- `route_dividend` → active lap reward multiplier

## Progression / abilities — implemented Next4

Authoritative subsystem: `Game/Progression/ProgressionSystem.gd` with data in `Content/Progression/progression_v1.json`.

Public operations through `ProgressionWorld`:

- `unlock_ability(ability_id) -> bool`
- `is_ability_unlocked(ability_id) -> bool`
- `get_unlocked_abilities() -> Array[StringName]`
- `movement_effects() -> Dictionary`
- `session_a_ability_mapping() -> Dictionary`
- `clone_capacity() -> int`
- `set_clone_count(stage_id, clone_count) -> bool`
- `clone_allocation_snapshot() -> Dictionary`
- `progression_snapshot() -> Dictionary`

Unified `purchase/current_level/current_cost/resulting_effect/upgrade_availability` route both economic tracks and progression tracks without exposing which subsystem owns the item.

Mandatory original progression:

1. Clear `relay_yard` → buy `speed_tune` → opens `liftworks` and a Relay Yard tuned-route shortcut.
2. Clear `liftworks` → buy `dash` → opens `phase_foundry` and old-stage dash routes.
3. Clear `phase_foundry` → buy `double_jump` → opens `blackout_array` and earlier secrets/routes.
4. Clear `blackout_array` → buy `wall_jump` → opens `core_spire` and earlier wall shortcuts.
5. Clear `core_spire` → buy `phase_shift` → endgame revisit shortcuts/secrets.

Optional progression:

- `jump_tune` multiplies jump intent; Session C/A applies the value to the actual player implementation.
- `clone_capacity` increases one global clone-allocation budget. The sum of per-stage clone counts cannot exceed this capacity.
- higher `speed_tune` levels increase run-speed intent after its level-1 gate unlock.

### Session A mapping

Session B IDs do not pretend to be Session A enum cases:

- `dash` → Session A `dash`
- `double_jump` → Session A `airJump`
- `wall_jump` → Session A `wallJump`
- `speed_tune` → numeric `run_speed_multiplier`, not a discrete Session A ability
- `phase_shift` → world-only ability; no Session A PlayerAbility mapping
- `jump_tune` → numeric `jump_multiplier`, not a discrete Session A ability

Session C must adapt the three discrete movement IDs and apply numeric movement effects through the eventual player-configuration bridge. Session B does not edit Session A config directly.

### Stage availability

`ProgressionWorld.stage_availability(stage_id)` is authoritative and combines:

1. raw StageManager unlock (previous mandatory clear), and
2. `WorldState.entry_required_ability` against ProgressionSystem unlock state.

Locked reasons are explicit: `unknown_stage`, `requires_previous_clear`, `requires_ability`.

## Upgrade rules

All purchases are atomic. Progression ability prerequisites and stage-clear milestones are checked before spending. `unlock_ability` is idempotent and, when directly invoked, synchronizes the corresponding minimum progression level so ability state and upgrade state cannot disagree.

## Save contract

Aggregate save schema is version 2 and contains:

- stage
- world
- economy
- economic upgrades
- progression levels / unlocked abilities

Version-1 aggregate saves remain readable; missing progression data starts at default locked progression rather than invalidating the save.

## Stable original IDs

Stages: `relay_yard`, `liftworks`, `phase_foundry`, `blackout_array`, `core_spire`.

Abilities: `speed_tune`, `dash`, `double_jump`, `wall_jump`, `phase_shift`.

Optional progression IDs include `jump_tune` and `clone_capacity`.

All IDs, presentation, economy constants and world layouts are project-original. No reference-game stage geometry, text, art, audio or exact unpublished numeric formula is represented as canonical.
